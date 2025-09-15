# Data sources
data "google_client_config" "default" {}

data "google_container_engine_versions" "main" {
  location = var.region
}

# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
  routing_mode           = "REGIONAL"
}

# Subnet
resource "google_compute_subnetwork" "main" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.main.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# Firewall rules
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.cluster_name}-allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/16", "10.1.0.0/16", "10.2.0.0/16"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.cluster_name}-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

# Service Account for GKE nodes
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-gke-nodes"
  display_name = "GKE Nodes Service Account"
}

resource "google_project_iam_member" "gke_nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/storage.objectViewer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# GKE Cluster
resource "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.main.name
  subnetwork = google_compute_subnetwork.main.name

  # IP allocation policy
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Network policy
  network_policy {
    enabled = true
  }

  # Addons
  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = false
    }

    network_policy_config {
      disabled = false
    }

    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Master auth
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Private cluster config
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  # Maintenance policy
  maintenance_policy {
    recurring_window {
      start_time = "2023-01-01T02:00:00Z"
      end_time   = "2023-01-01T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA"
    }
  }
}

# GKE Node Pool
resource "google_container_node_pool" "main" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.main.name
  node_count = var.node_count

  node_config {
    preemptible  = false
    machine_type = var.machine_type

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = var.common_tags

    tags = ["gke-node", "${var.cluster_name}-gke"]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Disk configuration
    disk_size_gb = 100
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"
  }

  # Autoscaling
  autoscaling {
    min_node_count = 1
    max_node_count = var.node_count + 2
  }

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# Filestore instance for shared storage
resource "google_filestore_instance" "main" {
  name     = "${var.cluster_name}-filestore"
  location = var.region
  tier     = "BASIC_HDD"

  file_shares {
    capacity_gb = 1024
    name        = "share1"
  }

  networks {
    network = google_compute_network.main.name
    modes   = ["MODE_IPV4"]
  }

  labels = var.common_tags
}

# Storage Class for Filestore
resource "kubectl_manifest" "filestore_storage_class" {
  yaml_body = yamlencode({
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "filestore-sc"
    }
    provisioner = "filestore.csi.storage.gke.io"
    parameters = {
      tier      = "standard"
      network   = google_compute_network.main.name
    }
    allowVolumeExpansion = true
  })

  depends_on = [google_container_node_pool.main]
}

# Service Account for Workload Identity (for applications)
resource "google_service_account" "workload_identity" {
  account_id   = "${var.cluster_name}-workload-identity"
  display_name = "Workload Identity Service Account"
}

resource "google_project_iam_member" "workload_identity" {
  for_each = toset([
    "roles/storage.objectViewer",
    "roles/storage.objectCreator",
    "roles/cloudsql.client"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.workload_identity.email}"
}

# Bind Kubernetes Service Account to Google Service Account
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.workload_identity.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/workload-identity-sa]"
}
