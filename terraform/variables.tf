variable "project_id" {
  type    = string
  default = "personal-500014"
}

variable "region" {
  type    = string
  default = "asia-south1"
}

variable "zone" {
  type    = string
  default = "asia-south1-a"
}

variable "cluster_name" {
  type    = string
  default = "o2-assignment-gke"
}

variable "machine_type" {
  type    = string
  default = "n2-standard-2"
}

variable "admin_cidr" {
  type        = string
  description = "Developer public IPv4 /32 allowed to reach the Kubernetes API."

  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && endswith(var.admin_cidr, "/32")
    error_message = "Supply a single public IPv4 address with /32."
  }
}
