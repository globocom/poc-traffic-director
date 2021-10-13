resource "google_compute_global_address" "td-public-ip" {
  name         = "td-public-ip"
  project      = var.project
  address_type = "EXTERNAL"
}

resource "google_compute_backend_service" "td-middle-proxy-lb-backend" {
  name          = "td-middle-proxy-lb-backend"
  project       = var.project
  health_checks = [google_compute_health_check.td-tcp-health-check-15001.id]
  port_name     = "td-port"

  backend {
    group           = google_compute_region_instance_group_manager.td-middle-proxy-instance-group.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "td-middle-proxy-lb-urlmap" {
  name            = "td-middle-proxy-lb-urlmap"
  project         = var.project
  default_service = google_compute_backend_service.td-middle-proxy-lb-backend.id
}

resource "google_compute_target_https_proxy" "td-middle-proxy-lb-proxy" {
  count            = var.ssl_certificate_id == "" ? 0 : 1
  name             = "td-middle-proxy-lb-proxy"
  project          = var.project
  url_map          = google_compute_url_map.td-middle-proxy-lb-urlmap.id
  ssl_certificates = [var.ssl_certificate_id]
}

resource "google_compute_global_forwarding_rule" "td-middle-proxy-lb-forwarding-rule" {
  count                 = var.ssl_certificate_id == "" ? 0 : 1
  name                  = "td-middle-proxy-lb-forwarding-rule"
  project               = var.project
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  ip_address            = google_compute_global_address.td-public-ip.id
  target                = google_compute_target_https_proxy.td-middle-proxy-lb-proxy[0].id
}


resource "google_compute_backend_service" "td-middle-proxy-lb-backend-insecure" {
  name          = "td-middle-proxy-lb-backend-insecure"
  project       = var.project
  health_checks = [google_compute_health_check.td-tcp-health-check-15001.id]
  port_name     = "td-port-insecure"

  backend {
    group           = google_compute_region_instance_group_manager.td-middle-proxy-instance-group.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "td-middle-proxy-lb-urlmap-insecure" {
  name            = "td-middle-proxy-lb-urlmap-insecure"
  project         = var.project
  default_service = google_compute_backend_service.td-middle-proxy-lb-backend-insecure.id
}

resource "google_compute_target_http_proxy" "td-middle-proxy-lb-proxy-insecure" {
  name    = "td-middle-proxy-lb-proxy-insecure"
  project = var.project
  url_map = google_compute_url_map.td-middle-proxy-lb-urlmap-insecure.id
}

resource "google_compute_global_forwarding_rule" "td-middle-proxy-lb-forwarding-rule-insecure" {
  name                  = "td-middle-proxy-lb-forwarding-rule-insecure"
  project               = var.project
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  ip_address            = google_compute_global_address.td-public-ip.id
  target                = google_compute_target_http_proxy.td-middle-proxy-lb-proxy-insecure.id
}
