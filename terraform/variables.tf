variable "env" {
  description = "Environment name. Used in resource names and tags."
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.env)
    error_message = "env must be staging or prod."
  }
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket for Loki chunks and index. Set per environment."
  type        = string
}

variable "vpc_id" {
  description = "VPC that holds the EKS cluster and the Loki host."
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet for the Loki host. Needs egress for the Loki release download, or a NAT or VPC endpoint."
  type        = string
}

variable "eks_node_security_group_id" {
  description = "Security group of the EKS worker nodes. Alloy on these nodes pushes to Loki."
  type        = string
}

variable "grafana_security_group_id" {
  description = "Security group of the existing Grafana host. Grafana queries Loki."
  type        = string
}

variable "instance_type" {
  description = "Loki host instance type. Restricted to the m5 family by design."
  type        = string

  validation {
    condition     = can(regex("^m5\\.", var.instance_type))
    error_message = "Loki hosts must use the m5 family (for example m5.large or m5.medium)."
  }
}

variable "key_name" {
  description = "Name of an existing EC2 key pair, used for SSH access to the Loki host."
  type        = string
}

variable "jumpbox_cidr" {
  description = "Private IP (with /32) of the jumpbox allowed to SSH to the Loki host and reach port 3100."
  type        = string
}

variable "disk_gb" {
  description = "Root gp3 volume size in GB. Holds the WAL, cache and temporary files, not the logs."
  type        = number
  default     = 50
}

variable "loki_version" {
  description = "Pinned Loki release (without the leading v). Confirm the version before first apply."
  type        = string
  default     = "3.7.4"
}

variable "loki_sha256" {
  description = "SHA-256 of loki-linux-amd64.zip for loki_version. Taken from the release checksum file."
  type        = string
}

variable "loki_memory_max" {
  description = "systemd MemoryMax for the Loki service (for example 6G on m5.large, 3G on m5.medium)."
  type        = string
}

variable "retention_days" {
  description = "Application log retention in Loki."
  type        = number
  default     = 90
}

variable "schema_start_date" {
  description = "Start date of the TSDB v13 schema config. Must not be in the future."
  type        = string
}

variable "ingestion_rate_mb" {
  description = "Per-tenant ingestion rate limit in MB/s."
  type        = number
}

variable "ingestion_burst_mb" {
  description = "Per-tenant ingestion burst limit in MB."
  type        = number
}

variable "tags" {
  description = "Extra tags for all resources."
  type        = map(string)
  default     = {}
}
