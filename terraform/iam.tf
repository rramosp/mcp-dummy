data "google_project" "project" {
  project_id = var.project_id
  depends_on = [google_project_service.services]
}

# Agent Engine & Egress Proxy service account
resource "google_service_account" "app_sa" {
  account_id   = substr("${var.resource_prefix}-sa", 0, 28)
  display_name = "${var.agent_name} Static Egress Service Account"
  project      = var.project_id
  depends_on   = [google_project_service.services]
}

# Grant application SA the required runtime permissions
resource "google_project_iam_member" "app_sa_roles" {
  for_each   = toset(var.app_sa_roles)
  project    = var.project_id
  role       = each.value
  member     = "serviceAccount:${google_service_account.app_sa.email}"
  depends_on = [google_project_service.services]
}

# Grant Vertex AI Service Agent runtime + PSC interface networking & DNS peering permissions
locals {
  vertex_sa_roles = distinct(concat(var.app_sa_roles, [
    "roles/compute.networkAdmin",
    "roles/dns.peer",
  ]))
}

resource "google_project_iam_member" "vertex_ai_sa_permissions" {
  for_each   = toset(local.vertex_sa_roles)
  project    = var.project_id
  role       = each.value
  member     = google_project_service_identity.vertex_sa.member
  depends_on = [google_project_service.services]
}

# Grant Cloud Build builder role to default Compute Engine service account
resource "google_project_iam_member" "default_compute_sa_builder" {
  project    = var.project_id
  role       = "roles/cloudbuild.builds.builder"
  member     = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  depends_on = [google_project_service.services]
}
