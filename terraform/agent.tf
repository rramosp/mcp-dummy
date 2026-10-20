locals {
  mcp_proxy_url = "http://${google_compute_address.proxy_internal_ip.address}:${var.proxy_port}"
}

resource "google_storage_bucket" "logs_data_bucket" {
  name                        = "${var.project_id}-${var.resource_prefix}-logs"
  location                    = var.region
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.services]
}

resource "google_vertex_ai_reasoning_engine" "app" {
  display_name    = var.agent_name
  description     = var.agent_description
  region          = var.region
  project         = var.project_id
  deletion_policy = "FORCE"

  spec {
    agent_framework = "google-adk"
    service_account = google_service_account.app_sa.email

    deployment_spec {
      min_instances         = var.min_instances
      max_instances         = var.max_instances
      container_concurrency = var.container_concurrency

      resource_limits = {
        cpu    = var.cpu
        memory = var.memory
      }

      # Attach Agent Engine to the consumer VPC via Private Service Connect Interface
      psc_interface_config {
        network_attachment = google_compute_network_attachment.psc_attachment.id

        dns_peering_configs {
          domain         = var.dns_peering_domain
          target_project = var.project_id
          target_network = google_compute_network.vpc.name
        }
      }

      env {
        name  = "MCP_SERVER_URL"
        value = var.mcp_server_url
      }

      env {
        name  = "MCP_TRANSPORT"
        value = var.mcp_transport
      }

      env {
        name  = "MCP_PROXY_URL"
        value = local.mcp_proxy_url
      }

      env {
        name  = "AGENT_MODEL"
        value = var.agent_model
      }

      env {
        name  = "GOOGLE_API_USE_CLIENT_CERTIFICATE"
        value = "false"
      }

      env {
        name  = "LOGS_BUCKET_NAME"
        value = google_storage_bucket.logs_data_bucket.name
      }

      env {
        name  = "GOOGLE_CLOUD_LOCATION"
        value = "global"
      }

      env {
        name  = "GOOGLE_GENAI_USE_VERTEXAI"
        value = "True"
      }

      env {
        name  = "OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT"
        value = "true"
      }

      env {
        name  = "GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY"
        value = "true"
      }
    }

    source_code_spec {
      inline_source {
        source_archive = filebase64(var.source_archive_path)
      }
      image_spec {}
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  depends_on = [
    google_project_service.services,
    google_project_iam_member.app_sa_roles,
    google_project_iam_member.vertex_ai_sa_permissions,
    google_project_iam_member.default_compute_sa_builder,
    google_compute_network_attachment.psc_attachment,
    google_compute_router_nat.nat,
    google_compute_firewall.allow_psc_to_proxy,
    google_compute_instance.egress_proxy,
    google_dns_record_set.proxy_a_record,
  ]
}
