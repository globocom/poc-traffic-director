resource "google_compute_health_check" "td-tcp-health-check-15001" {
  name    = "td-tcp-health-check-15001"
  project = var.project

  timeout_sec         = 5
  check_interval_sec  = 15
  healthy_threshold   = 2
  unhealthy_threshold = 2

  tcp_health_check {
    port         = 15001
    proxy_header = "NONE"
  }
}

resource "google_compute_instance_template" "td-middle-proxy-template" {
  name_prefix  = "td-middle-proxy-template-"
  machine_type = "e2-medium"
  region       = var.region
  project      = var.project

  tags = var.template_tags

  labels = {
    gce-service-proxy = "on"
  }

  disk {
    source_image = "debian-cloud/debian-10"
  }

  network_interface {
    subnetwork         = var.subnet
    subnetwork_project = var.vpc_project
  }

  metadata = {
    enable-guest-attributes  = "TRUE"
    enable-osconfig          = "true"
    gce-service-proxy        = "{\"api-version\": \"0.2\", \"proxy-spec\": {\"tracing\": \"ON\", \"access-log\": \"/var/log/envoy/access.log\", \"network\": \"\"}}"
    gce-software-declaration = "{\"softwareRecipes\": [{\"name\": \"install-gce-service-proxy-agent\", \"desired_state\": \"INSTALLED\", \"installSteps\": [{\"scriptRun\": {\"script\": \"#! /bin/bash\\nZONE=$( curl --silent http://metadata.google.internal/computeMetadata/v1/instance/zone -H Metadata-Flavor:Google | cut -d/ -f4 )\\nexport SERVICE_PROXY_AGENT_DIRECTORY=$(mktemp -d)\\nsudo gsutil cp   gs://gce-service-proxy-$${ZONE}/service-proxy-agent/releases/service-proxy-agent-0.2.tgz   $${SERVICE_PROXY_AGENT_DIRECTORY}   || sudo gsutil cp     gs://gce-service-proxy/service-proxy-agent/releases/service-proxy-agent-0.2.tgz     $${SERVICE_PROXY_AGENT_DIRECTORY}\\nsudo tar -xzf $${SERVICE_PROXY_AGENT_DIRECTORY}/service-proxy-agent-0.2.tgz -C $${SERVICE_PROXY_AGENT_DIRECTORY}\\n$${SERVICE_PROXY_AGENT_DIRECTORY}/service-proxy-agent/service-proxy-agent-bootstrap.sh\"}}]}]}"
  }

  service_account {
    email = google_service_account.td-vms-account.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/pubsub",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_project_service" "trafficdirector-api" {
  project = var.project
  service = "trafficdirector.googleapis.com"
}

resource "google_compute_region_instance_group_manager" "td-middle-proxy-instance-group" {
  name               = "td-middle-proxy-instance-group"
  region             = var.region
  base_instance_name = "td-middle-proxy"
  project            = var.project

  version {
    instance_template = google_compute_instance_template.td-middle-proxy-template.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.td-tcp-health-check-15001.id
    initial_delay_sec = 300
  }

  named_port {
    name = "td-port"
    port = google_compute_global_forwarding_rule.td-forwarding-rule.port_range
  }

  named_port {
    name = "td-port-insecure"
    port = google_compute_global_forwarding_rule.td-forwarding-rule-insecure.port_range
  }
}

resource "google_compute_region_autoscaler" "td-middle-proxy-instance-group" {
  name    = "td-middle-proxy-instance-group"
  region  = var.region
  target  = google_compute_region_instance_group_manager.td-middle-proxy-instance-group.id
  project = var.project

  autoscaling_policy {
    max_replicas    = 2
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}


