terraform {
  required_version = ">= 1.6, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Keep project APIs enabled when this temporary infrastructure is destroyed.
resource "google_project_service" "apis" {
  for_each           = toset(["compute.googleapis.com", "container.googleapis.com", "iam.googleapis.com"])
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "main" {
  name                    = var.cluster_name
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis]
}

resource "google_compute_subnetwork" "main" {
  name          = var.cluster_name
  network       = google_compute_network.main.id
  ip_cidr_range = "10.80.0.0/24"

  # VPC-native Pods use a separate range from nodes and Services.
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.84.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.85.0.0/20"
  }
}

resource "google_service_account" "nodes" {
  account_id   = "o2-assignment-nodes"
  display_name = "OpenObserve assignment GKE nodes"

  depends_on = [google_project_service.apis]
}

# Add the node role without replacing other project IAM grants.
resource "google_project_iam_member" "nodes" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "main" {
  name       = var.cluster_name
  location   = var.zone
  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.main.id

  # The separate node pool below manages the workload node.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Allow teardown after the assignment test.
  deletion_protection   = false
  networking_mode       = "VPC_NATIVE"
  enable_shielded_nodes = true

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config { workload_pool = "${var.project_id}.svc.id.goog" }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Restrict control-plane access to the developer public IP.
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.admin_cidr
      display_name = "Developer access"
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = 30
    disk_type       = "pd-standard"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  depends_on = [google_project_iam_member.nodes]
}

resource "google_container_node_pool" "main" {
  name       = "vector"
  cluster    = google_container_cluster.main.name
  location   = var.zone
  node_count = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = 30
    disk_type       = "pd-standard"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    metadata = { disable-legacy-endpoints = "true" }
    labels   = { app = "o2-assignment" }
  }
}
