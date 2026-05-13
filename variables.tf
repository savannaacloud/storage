variable "prefix" {
  description = "Prefix for every resource name so multiple environments coexist."
  type        = string
  default     = "storage-demo"
}

variable "region" {
  description = "Savannaa region: ng-abuja-1 or ng-lagos-1."
  type        = string
  default     = "ng-abuja-1"
}

variable "image_name" {
  description = "OS image to look up via data.sws_image. Used as the volume_attachment demo target."
  type        = string
  default     = "Ubuntu 22.04 LTS"
}

variable "volume_size_gb" {
  description = "Size of the demo volume (GiB)."
  type        = number
  default     = 20
}

variable "volume_type" {
  description = "Backend volume type — gp-ssd (general purpose) or io-ssd (provisioned IOPS). Match what's available in your region; default works on both."
  type        = string
  default     = "gp-ssd"
}

variable "snapshot_after_create" {
  description = "Take a snapshot of the volume after creation (~30s extra)."
  type        = bool
  default     = true
}

variable "network_id" {
  description = "Network ID for the demo instance that mounts the volume. (Storage objects themselves are region-scoped, not network-scoped.)"
  type        = string
}

variable "object_buckets" {
  description = "Names of object-storage buckets to create. Empty list = skip."
  type        = list(string)
  default     = ["assets", "logs", "backups"]
}

variable "enable_file_storage" {
  description = "Create an NFS-style shared file system (sws_file_storage)."
  type        = bool
  default     = true
}

variable "file_storage_size_gb" {
  description = "Size of the file-storage share (GiB)."
  type        = number
  default     = 100
}

variable "backup_retention_days" {
  description = "Daily-backup retention for the demo volume."
  type        = number
  default     = 7
}
