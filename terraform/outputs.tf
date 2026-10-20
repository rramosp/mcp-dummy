locals {
  reasoning_engine_short_id = regex("[^/]+$", google_vertex_ai_reasoning_engine.app.id)
  reasoning_engine_resource = "projects/${var.project_id}/locations/${var.region}/reasoningEngines/${local.reasoning_engine_short_id}"
}

output "static_egress_ip" {
  description = "Static external IP address from which all requests to the remote MCP server originate."
  value       = google_compute_address.static_egress_ip.address
}

output "static_egress_ip_name" {
  description = "Name of the reserved static external IP address resource."
  value       = google_compute_address.static_egress_ip.name
}

output "agent_engine_id" {
  description = "Short ID of the deployed Vertex AI Agent Engine."
  value       = local.reasoning_engine_short_id
}

output "agent_engine_resource_name" {
  description = "Full resource name of the deployed Vertex AI Agent Engine."
  value       = local.reasoning_engine_resource
}

output "agent_base_endpoint" {
  description = "Base REST endpoint URL of the deployed Vertex AI Agent Engine."
  value       = "https://${var.region}-aiplatform.googleapis.com/v1/${local.reasoning_engine_resource}"
}

output "agent_stream_query_endpoint" {
  description = "Streaming query (:streamQuery) endpoint of the deployed Vertex AI Agent Engine."
  value       = "https://${var.region}-aiplatform.googleapis.com/v1/${local.reasoning_engine_resource}:streamQuery"
}

output "agent_query_endpoint" {
  description = "Synchronous query (:query) endpoint of the deployed Vertex AI Agent Engine."
  value       = "https://${var.region}-aiplatform.googleapis.com/v1/${local.reasoning_engine_resource}:query"
}

output "agent_a2a_card_url" {
  description = "A2A Agent Card URL exposed via Agent Engine HTTP passthrough."
  value       = "https://${var.region}-aiplatform.googleapis.com/reasoningEngines/v1/${local.reasoning_engine_resource}/api/a2a/app/.well-known/agent-card.json"
}

output "agent_console_url" {
  description = "Google Cloud Console URL for the deployed Vertex AI Agent Engine."
  value       = "https://console.cloud.google.com/vertex-ai/agents/agent-engines/locations/${var.region}/agent-engines/${local.reasoning_engine_short_id}?project=${var.project_id}"
}

output "mcp_server_url" {
  description = "Configured remote MCP server URL."
  value       = var.mcp_server_url
}

output "mcp_transport" {
  description = "Configured remote MCP server transport."
  value       = var.mcp_transport
}

output "mcp_proxy_url" {
  description = "Internal VPC proxy URL used by Agent Engine to reach the remote MCP server via Cloud NAT."
  value       = local.mcp_proxy_url
}

output "vpc_network_name" {
  description = "Consumer VPC network name."
  value       = google_compute_network.vpc.name
}

output "psc_subnet_name" {
  description = "Private Service Connect Network Attachment subnet name."
  value       = google_compute_subnetwork.psc_subnet.name
}

output "psc_subnet_cidr" {
  description = "Private Service Connect Network Attachment subnet CIDR."
  value       = google_compute_subnetwork.psc_subnet.ip_cidr_range
}

output "psc_network_attachment_id" {
  description = "Private Service Connect Network Attachment resource ID."
  value       = google_compute_network_attachment.psc_attachment.id
}

output "proxy_subnet_name" {
  description = "Egress proxy VM subnet name."
  value       = google_compute_subnetwork.proxy_subnet.name
}

output "proxy_subnet_cidr" {
  description = "Egress proxy VM subnet CIDR."
  value       = google_compute_subnetwork.proxy_subnet.ip_cidr_range
}

output "egress_proxy_vm_name" {
  description = "Name of the VPC egress proxy VM."
  value       = google_compute_instance.egress_proxy.name
}

output "egress_proxy_internal_ip" {
  description = "Static RFC 1918 internal IP of the VPC egress proxy VM."
  value       = google_compute_address.proxy_internal_ip.address
}

output "cloud_router_name" {
  description = "Cloud Router name."
  value       = google_compute_router.router.name
}

output "cloud_nat_name" {
  description = "Cloud NAT gateway name."
  value       = google_compute_router_nat.nat.name
}

output "private_dns_zone_name" {
  description = "Private Cloud DNS managed zone name."
  value       = google_dns_managed_zone.private_dns.name
}

output "proxy_dns_name" {
  description = "Private DNS FQDN for the egress proxy VM."
  value       = google_dns_record_set.proxy_a_record.name
}

output "service_account_email" {
  description = "Agent Engine & Egress Proxy service account email."
  value       = google_service_account.app_sa.email
}

output "logs_bucket_name" {
  description = "Cloud Storage bucket for agent logs and artifacts."
  value       = google_storage_bucket.logs_data_bucket.name
}
