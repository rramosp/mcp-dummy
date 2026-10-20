# 1. Consumer VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.resource_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  depends_on              = [google_project_service.services]
}

# 2. Subnet for the Private Service Connect (PSC) Network Attachment
#    Agent Engine attaches its tenant-project interface into this RFC 1918 subnet.
resource "google_compute_subnetwork" "psc_subnet" {
  name                     = "${var.resource_prefix}-psc-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.psc_subnet_cidr
  private_ip_google_access = true
}

# 3. Subnet for the VPC Egress Proxy VM
resource "google_compute_subnetwork" "proxy_subnet" {
  name                     = "${var.resource_prefix}-proxy-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.proxy_subnet_cidr
  private_ip_google_access = true
}

# 4. Private Service Connect Network Attachment
resource "google_compute_network_attachment" "psc_attachment" {
  name                  = "${var.resource_prefix}-psc-attachment"
  project               = var.project_id
  region                = var.region
  description           = "Network Attachment bridging Vertex AI Agent Engine into the static-egress VPC"
  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.psc_subnet.self_link]

  # Vertex AI Agent Engine's tenant project detaches its PSC interface endpoint
  # asynchronously (typically 15-60s after reasoningEngines.delete completes).
  # Wait until connectionEndpoints is empty before deleting the NetworkAttachment.
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      REGION_SHORT=$(basename "${self.region}")
      for i in $(seq 1 36); do
        ENDPOINTS=$(gcloud compute network-attachments describe "${self.name}" \
          --region="$REGION_SHORT" \
          --project="${self.project}" \
          --format="value(connectionEndpoints)" 2>/dev/null || true)
        if [ -z "$ENDPOINTS" ]; then
          exit 0
        fi
        echo "Waiting for Vertex AI tenant project to detach PSC endpoint from ${self.name} (attempt $i/36)..."
        sleep 5
      done
    EOT
  }
}

# 5. Reserved Static External IP Address for all outbound traffic to the MCP Server
resource "google_compute_address" "static_egress_ip" {
  name         = "${var.resource_prefix}-static-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  description  = "Static external IP used by Cloud NAT for Agent Engine calls to the remote MCP server"
  depends_on   = [google_project_service.services]
}

# 6. Cloud Router + Cloud NAT pinned to the single Static External IP
resource "google_compute_router" "router" {
  name    = "${var.resource_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.resource_prefix}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.static_egress_ip.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ALL"
  }
}

# 7. Firewall rules: allow Agent Engine PSC interface -> Egress Proxy VM, and IAP SSH
resource "google_compute_firewall" "allow_psc_to_proxy" {
  name          = "${var.resource_prefix}-allow-psc-to-proxy"
  project       = var.project_id
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [var.psc_subnet_cidr]
  target_tags   = ["mcp-egress-proxy"]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.proxy_port)]
  }

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name          = "${var.resource_prefix}-allow-iap-ssh"
  project       = var.project_id
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["mcp-egress-proxy"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# 8. Static Internal RFC 1918 IP + Egress Proxy VM
#    Because Vertex AI Agent Engine PSC Interfaces only route RFC 1918 traffic
#    into the consumer VPC, this lightweight VM receives MCP requests over the
#    PSC interface (RFC 1918) and forwards them out through Cloud NAT using the
#    reserved static external IP (without adding internal X-Forwarded-For headers).
resource "google_compute_address" "proxy_internal_ip" {
  name         = "${var.resource_prefix}-proxy-internal-ip"
  project      = var.project_id
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.proxy_subnet.id
  address      = var.proxy_internal_ip
}

resource "google_compute_instance" "egress_proxy" {
  name                      = "${var.resource_prefix}-egress-proxy"
  project                   = var.project_id
  zone                      = var.zone
  machine_type              = var.proxy_machine_type
  tags                      = ["mcp-egress-proxy"]
  can_ip_forward            = false
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  # No access_config (no external IP on VM) -> all outbound traffic MUST exit via Cloud NAT
  network_interface {
    subnetwork = google_compute_subnetwork.proxy_subnet.id
    network_ip = google_compute_address.proxy_internal_ip.address
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.app_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail

    cat <<'PYEOF' > /usr/local/bin/mcp-egress-proxy.py
    #!/usr/bin/env python3
    """Lightweight async HTTP/HTTPS forward & CONNECT proxy for MCP static egress.

    Strips internal X-Forwarded-For / X-Real-IP / Via headers so the remote MCP
    server always observes the Cloud NAT static external IP.
    """
    import asyncio
    import sys
    import urllib.parse

    STRIP_HEADERS = {
        "proxy-connection",
        "connection",
        "x-forwarded-for",
        "x-real-ip",
        "via",
    }

    async def pipe(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        try:
            while True:
                chunk = await reader.read(65536)
                if not chunk:
                    break
                writer.write(chunk)
                await writer.drain()
        except Exception:
            pass
        finally:
            try:
                writer.close()
            except Exception:
                pass

    async def handle_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        try:
            request_line = await reader.readline()
            if not request_line:
                writer.close()
                return
            parts = request_line.decode("latin-1").strip().split(" ")
            if len(parts) < 3:
                writer.close()
                return
            method, target, version = parts[0], parts[1], parts[2]
            headers = []
            while True:
                line = await reader.readline()
                if not line or line in (b"\r\n", b"\n"):
                    break
                key = line.decode("latin-1").split(":", 1)[0].strip().lower()
                if key not in STRIP_HEADERS:
                    headers.append(line)

            if method.upper() == "CONNECT":
                host, _, port_str = target.partition(":")
                port = int(port_str or 443)
                up_reader, up_writer = await asyncio.open_connection(host, port)
                writer.write(f"{version} 200 Connection Established\r\n\r\n".encode("latin-1"))
                await writer.drain()
            else:
                parsed = urllib.parse.urlsplit(target)
                host = parsed.hostname
                port = parsed.port or (443 if parsed.scheme == "https" else 80)
                path = urllib.parse.urlunsplit(("", "", parsed.path or "/", parsed.query, ""))
                up_reader, up_writer = await asyncio.open_connection(host, port)
                up_writer.write(f"{method} {path} {version}\r\n".encode("latin-1"))
                for h in headers:
                    up_writer.write(h)
                up_writer.write(b"Connection: close\r\n\r\n")
                await up_writer.drain()

            await asyncio.gather(pipe(reader, up_writer), pipe(up_reader, writer))
        except Exception:
            try:
                writer.close()
            except Exception:
                pass

    async def main() -> None:
        port = int(sys.argv[1]) if len(sys.argv) > 1 else 8888
        server = await asyncio.start_server(handle_client, "0.0.0.0", port)
        async with server:
            await server.serve_forever()

    if __name__ == "__main__":
        asyncio.run(main())
    PYEOF

    chmod +x /usr/local/bin/mcp-egress-proxy.py

    cat <<'SVCEOF' > /etc/systemd/system/mcp-egress-proxy.service
    [Unit]
    Description=MCP Static IP Egress Proxy
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    ExecStart=/usr/bin/python3 /usr/local/bin/mcp-egress-proxy.py ${var.proxy_port}
    Restart=always
    RestartSec=2
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target
    SVCEOF

    systemctl daemon-reload
    systemctl enable --now mcp-egress-proxy.service
  EOT

  depends_on = [
    google_compute_router_nat.nat,
    google_project_iam_member.app_sa_roles,
  ]
}

# 9. Private Cloud DNS Zone + A Record for DNS Peering with Agent Engine
resource "google_dns_managed_zone" "private_dns" {
  name          = "${var.resource_prefix}-private-zone"
  project       = var.project_id
  dns_name      = var.dns_peering_domain
  description   = "Private DNS zone peered with Vertex AI Agent Engine for static egress proxy resolution"
  visibility    = "private"
  force_destroy = true

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_dns_record_set" "proxy_a_record" {
  name         = "proxy.${var.dns_peering_domain}"
  project      = var.project_id
  managed_zone = google_dns_managed_zone.private_dns.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.proxy_internal_ip.address]
}
