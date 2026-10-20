variable "project_id" {
  type        = string
  description = "Google Cloud Project ID for resource deployment."
}

variable "region" {
  type        = string
  description = "Google Cloud region for Agent Engine and regional networking."
  default     = "us-east1"

  validation {
    condition = contains([
      "us-central1", "us-east1", "us-east4", "us-west1",
      "northamerica-northeast1", "northamerica-northeast2", "southamerica-east1",
      "europe-west1", "europe-west2", "europe-west3", "europe-west4",
      "europe-west6", "europe-west8", "europe-southwest1",
      "asia-east1", "asia-east2", "asia-northeast1", "asia-northeast3",
      "asia-south1", "asia-southeast1", "asia-southeast2",
      "australia-southeast2", "me-west1",
    ], var.region)
    error_message = "var.region must be one of the 23 regions supported by Vertex AI Agent Engine (e.g., us-central1, us-east1, us-east4, us-west1, europe-west1..4/6/8, asia-east1..2, etc.)."
  }
}

variable "zone" {
  type        = string
  description = "Google Cloud zone for the static-egress proxy VM (must belong to var.region; note us-east1 and europe-west1 have -b/-c/-d but no -a)."
  default     = "us-east1-b"

  validation {
    condition     = startswith(var.zone, "${var.region}-") && !contains(["us-east1-a", "europe-west1-a"], var.zone)
    error_message = "var.zone must be a valid zone inside var.region (e.g. '<region>-b'). Note that us-east1-a and europe-west1-a do not exist."
  }
}

variable "agent_name" {
  type        = string
  description = "Display name of the Vertex AI Agent Engine deployment."
  default     = "hello-mcp-agent"
}

variable "agent_description" {
  type        = string
  description = "Description of the Vertex AI Agent Engine deployment."
  default     = "Hello World MCP Agent on Vertex AI Agent Engine with static egress IP"
}

variable "agent_model" {
  type        = string
  description = "Gemini model used by the ADK agent."
  default     = "gemini-2.5-flash"
}

variable "source_archive_path" {
  type        = string
  description = "Path to the packaged .tar.gz source archive of the ADK agent."
}

variable "min_instances" {
  type        = number
  description = "Minimum number of Agent Engine container instances."
  default     = 1
}

variable "max_instances" {
  type        = number
  description = "Maximum number of Agent Engine container instances."
  default     = 10
}

variable "cpu" {
  type        = string
  description = "CPU limit per Agent Engine container instance."
  default     = "4"
}

variable "memory" {
  type        = string
  description = "Memory limit per Agent Engine container instance."
  default     = "8Gi"
}

variable "container_concurrency" {
  type        = number
  description = "Concurrent requests per Agent Engine container instance."
  default     = 9
}

variable "mcp_server_url" {
  type        = string
  description = "Endpoint URL of the remote Hello World MCP server."
}

variable "mcp_transport" {
  type        = string
  description = "MCP transport protocol (streamable-http or sse)."
  default     = "streamable-http"
}

variable "resource_prefix" {
  type        = string
  description = "Naming prefix for VPC, subnets, PSC attachment, NAT, and static IP resources."
  default     = "hello-mcp-static"
}

variable "psc_subnet_cidr" {
  type        = string
  description = "RFC 1918 CIDR range for the Private Service Connect Network Attachment subnet."
  default     = "192.168.10.0/28"
}

variable "proxy_subnet_cidr" {
  type        = string
  description = "RFC 1918 CIDR range for the VPC egress proxy subnet."
  default     = "10.10.10.0/28"
}

variable "proxy_internal_ip" {
  type        = string
  description = "Static RFC 1918 internal IP address for the egress proxy VM."
  default     = "10.10.10.2"
}

variable "proxy_port" {
  type        = number
  description = "TCP port on which the egress proxy listens inside the VPC."
  default     = 8888
}

variable "proxy_machine_type" {
  type        = string
  description = "Machine type for the egress proxy VM."
  default     = "e2-micro"
}

variable "dns_peering_domain" {
  type        = string
  description = "Private Cloud DNS zone suffix (must end with a dot) peered with Agent Engine."
  default     = "mcp.internal."
}

variable "app_sa_roles" {
  type        = list(string)
  description = "IAM roles granted to the Agent Engine runtime service account."
  default = [
    "roles/aiplatform.user",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent",
    "roles/storage.admin",
    "roles/serviceusage.serviceUsageConsumer",
  ]
}
