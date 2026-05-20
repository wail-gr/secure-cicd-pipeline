# =============================================================================
# GCP HTTPS Load Balancer — Cloud Run Backend
# =============================================================================
# Provisions a global HTTPS Load Balancer with managed SSL certificate
# routing traffic to the Cloud Run service.
#
# Usage:
#   terraform init
#   terraform plan -var="project_id=YOUR_PROJECT" -var="domain=api.example.com"
#   terraform apply
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Cloud Run service region"
  type        = string
  default     = "us-central1"
}

variable "domain" {
  description = "Custom domain for the HTTPS Load Balancer"
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "secure-api"
}

# ---------------------------------------------------------------------------
# Provider
# ---------------------------------------------------------------------------

provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------------------------
# Network Endpoint Group (NEG) — Serverless
# ---------------------------------------------------------------------------

resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "${var.service_name}-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.service_name
  }
}

# ---------------------------------------------------------------------------
# Backend Service
# ---------------------------------------------------------------------------

resource "google_compute_backend_service" "api_backend" {
  name                  = "${var.service_name}-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.id
  }

  # Enable Cloud CDN for static responses
  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    default_ttl                  = 3600
    max_ttl                      = 86400
    negative_caching             = true
    serve_while_stale            = 86400
    signed_url_cache_max_age_sec = 7200
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# ---------------------------------------------------------------------------
# URL Map
# ---------------------------------------------------------------------------

resource "google_compute_url_map" "api_url_map" {
  name            = "${var.service_name}-url-map"
  default_service = google_compute_backend_service.api_backend.id
}

# ---------------------------------------------------------------------------
# Managed SSL Certificate
# ---------------------------------------------------------------------------

resource "google_compute_managed_ssl_certificate" "api_cert" {
  name = "${var.service_name}-cert"

  managed {
    domains = [var.domain]
  }
}

# ---------------------------------------------------------------------------
# HTTPS Proxy
# ---------------------------------------------------------------------------

resource "google_compute_target_https_proxy" "api_https_proxy" {
  name    = "${var.service_name}-https-proxy"
  url_map = google_compute_url_map.api_url_map.id

  ssl_certificates = [
    google_compute_managed_ssl_certificate.api_cert.id
  ]
}

# ---------------------------------------------------------------------------
# Global Forwarding Rule (Public IP)
# ---------------------------------------------------------------------------

resource "google_compute_global_address" "api_ip" {
  name = "${var.service_name}-ip"
}

resource "google_compute_global_forwarding_rule" "api_forwarding" {
  name                  = "${var.service_name}-forwarding"
  target                = google_compute_target_https_proxy.api_https_proxy.id
  port_range            = "443"
  ip_address            = google_compute_global_address.api_ip.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# ---------------------------------------------------------------------------
# HTTP → HTTPS Redirect
# ---------------------------------------------------------------------------

resource "google_compute_url_map" "http_redirect" {
  name = "${var.service_name}-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "http_redirect_proxy" {
  name    = "${var.service_name}-http-redirect-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http_redirect_forwarding" {
  name                  = "${var.service_name}-http-redirect"
  target                = google_compute_target_http_proxy.http_redirect_proxy.id
  port_range            = "80"
  ip_address            = google_compute_global_address.api_ip.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "load_balancer_ip" {
  description = "Global anycast IP for the HTTPS Load Balancer"
  value       = google_compute_global_address.api_ip.address
}

output "https_url" {
  description = "HTTPS URL for the API"
  value       = "https://${var.domain}"
}
