resource "google_service_account" "td-vms-account" {
  account_id = "td-vms-account"
  project    = var.project
}

resource "google_project_iam_member" "td-iam-storage" {
  project = var.project
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.td-vms-account.email}"
}

resource "google_project_iam_member" "td-iam-editor" {
  project = var.project
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.td-vms-account.email}"
}

resource "google_project_iam_member" "td-iam-td-client" {
  project = var.project
  role    = "roles/trafficdirector.client"
  member  = "serviceAccount:${google_service_account.td-vms-account.email}"
}
