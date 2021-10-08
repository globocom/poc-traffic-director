
data "dns_a_record_set" "backend1" {
  host = var.backend1_host
}

data "dns_a_record_set" "backend2" {
  host = var.backend2_host
}

locals {
  backend1_service = var.backend_tls ? google_compute_backend_service.backend1-backend-internal-tls.id : google_compute_backend_service.backend1-backend-internal.id
  backend2_service = var.backend_tls ? google_compute_backend_service.backend2-backend-internal-tls.id : google_compute_backend_service.backend2-backend-internal.id
}

resource "null_resource" "gcp_private_ip_negs" {
  provisioner "local-exec" {
    command = <<EOT
gcloud compute network-endpoint-groups create backend1-private-neg --network-endpoint-type=NON_GCP_PRIVATE_IP_PORT --zone=${var.zone} --network=${var.network} --project=${var.project}
gcloud compute network-endpoint-groups create backend2-private-neg --network-endpoint-type=NON_GCP_PRIVATE_IP_PORT --zone=${var.zone} --network=${var.network} --project=${var.project}
gcloud compute network-endpoint-groups update backend1-private-neg --zone=${var.zone} --add-endpoint="ip=${data.dns_a_record_set.backend1.addrs[0]},port=80"
gcloud compute network-endpoint-groups update backend2-private-neg --zone=${var.zone} --add-endpoint="ip=${data.dns_a_record_set.backend2.addrs[0]},port=80"
gcloud compute network-endpoint-groups create backend1-private-neg-tls --network-endpoint-type=NON_GCP_PRIVATE_IP_PORT --zone=${var.zone} --network=${var.network} --project=${var.project}
gcloud compute network-endpoint-groups create backend2-private-neg-tls --network-endpoint-type=NON_GCP_PRIVATE_IP_PORT --zone=${var.zone} --network=${var.network} --project=${var.project}
gcloud compute network-endpoint-groups update backend1-private-neg-tls --zone=${var.zone} --add-endpoint="ip=${data.dns_a_record_set.backend1.addrs[0]},port=443"
gcloud compute network-endpoint-groups update backend2-private-neg-tls --zone=${var.zone} --add-endpoint="ip=${data.dns_a_record_set.backend2.addrs[0]},port=443"
EOT
  }
}

data "google_compute_network_endpoint_group" "backend1-private-neg" {
  name    = "backend1-private-neg"
  zone    = var.zone
  project = var.project

  depends_on = [null_resource.gcp_private_ip_negs]
}

data "google_compute_network_endpoint_group" "backend2-private-neg" {
  name    = "backend2-private-neg"
  zone    = var.zone
  project = var.project

  depends_on = [null_resource.gcp_private_ip_negs]
}

data "google_compute_network_endpoint_group" "backend1-private-neg-tls" {
  name    = "backend1-private-neg-tls"
  zone    = var.zone
  project = var.project

  depends_on = [null_resource.gcp_private_ip_negs]
}

data "google_compute_network_endpoint_group" "backend2-private-neg-tls" {
  name    = "backend2-private-neg-tls"
  zone    = var.zone
  project = var.project

  depends_on = [null_resource.gcp_private_ip_negs]
}

resource "google_compute_backend_service" "backend2-backend-internal" {
  name                  = "backend2-backend-internal"
  project               = var.project
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
  health_checks         = [google_compute_health_check.td-tcp-health-check-80.id]

  backend {
    group                 = data.google_compute_network_endpoint_group.backend2-private-neg.id
    balancing_mode        = "RATE"
    capacity_scaler       = 1.0
    max_rate_per_endpoint = 5000
  }
}

resource "google_compute_backend_service" "backend1-backend-internal" {
  name                  = "backend1-backend-internal"
  project               = var.project
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
  health_checks         = [google_compute_health_check.td-tcp-health-check-80.id]

  backend {
    group                 = data.google_compute_network_endpoint_group.backend1-private-neg.id
    balancing_mode        = "RATE"
    capacity_scaler       = 1.0
    max_rate_per_endpoint = 5000
  }
}

resource "google_compute_backend_service" "backend2-backend-internal-tls" {
  name                  = "backend2-backend-internal-tls"
  project               = var.project
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
  health_checks         = [google_compute_health_check.td-tcp-health-check-443.id]
  protocol              = "HTTPS"

  backend {
    group                 = data.google_compute_network_endpoint_group.backend2-private-neg-tls.id
    balancing_mode        = "RATE"
    capacity_scaler       = 1.0
    max_rate_per_endpoint = 5000
  }
}

resource "google_compute_backend_service" "backend1-backend-internal-tls" {
  name                  = "backend1-backend-internal-tls"
  project               = var.project
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
  health_checks         = [google_compute_health_check.td-tcp-health-check-443.id]
  protocol              = "HTTPS"

  backend {
    group                 = data.google_compute_network_endpoint_group.backend1-private-neg-tls.id
    balancing_mode        = "RATE"
    capacity_scaler       = 1.0
    max_rate_per_endpoint = 5000
  }
}

resource "google_compute_url_map" "td-urlmap" {
  name    = "td-urlmap"
  project = var.project

  default_route_action {
    weighted_backend_services {
      backend_service = local.backend1_service
      weight          = 80
    }
    weighted_backend_services {
      backend_service = local.backend2_service
      weight          = 20
    }
  }
}

resource "google_compute_target_http_proxy" "td-http-proxy" {
  name       = "td-http-proxy"
  project    = var.project
  url_map    = google_compute_url_map.td-urlmap.id
  proxy_bind = true
}

resource "google_compute_global_forwarding_rule" "td-forwarding-rule" {
  name                  = "td-forwarding-rule"
  project               = var.project
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
  port_range            = 8082
  ip_address            = "0.0.0.0"
  network               = var.network
  target                = google_compute_target_http_proxy.td-http-proxy.id
}

resource "google_compute_health_check" "td-tcp-health-check-80" {
  name               = "td-tcp-health-check-80"
  project            = var.project
  timeout_sec        = 5
  check_interval_sec = 15

  tcp_health_check {
    port = "80"
  }
}

resource "google_compute_health_check" "td-tcp-health-check-443" {
  name               = "td-tcp-health-check-443"
  project            = var.project
  timeout_sec        = 5
  check_interval_sec = 15

  tcp_health_check {
    port = "443"
  }
}

