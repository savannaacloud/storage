locals {
  prefix = var.prefix
}

# ── Images (data source) ───────────────────────────────────────────────────
# Images are read-only: customers don't upload them via terraform, they
# pick one by name. data.sws_image gives you the id you'll need on the
# instance + on the boot volume.

data "sws_image" "ubuntu" {
  name = var.image_name
}

# ── Volumes ────────────────────────────────────────────────────────────────
# Block volume — gets attached to one VM at a time (multi-attach is on the
# roadmap but not the default). `volume_type` chooses the backend storage
# tier (gp-ssd / io-ssd).

resource "sws_volume" "data" {
  name        = "${local.prefix}-data"
  size        = var.volume_size_gb
  volume_type = var.volume_type
}

# Demo instance the volume attaches to. Tiny + cheap so the example is fast.
resource "sws_keypair" "demo" {
  name       = "${local.prefix}-key"
  public_key = file(pathexpand(var.ssh_public_key_file))
}

resource "sws_instance" "vm" {
  name       = "${local.prefix}-vm"
  plan       = "m1.small"
  image      = var.image_name
  network_id = var.network_id
  keypair    = sws_keypair.demo.name
  public_ip  = true
}

resource "sws_volume_attachment" "data" {
  instance_id = sws_instance.vm.id
  volume_id   = sws_volume.data.id
}

# ── Snapshots ──────────────────────────────────────────────────────────────
# Crash-consistent snapshot of the volume. Take one immediately after
# create so the example end-to-end works without you having to seed data.

resource "sws_volume_snapshot" "data" {
  count = var.snapshot_after_create ? 1 : 0

  name      = "${local.prefix}-data-snap1"
  volume_id = sws_volume.data.id
}

# ── Backups (policy) ───────────────────────────────────────────────────────
# Recurring backup schedule. backup_policy attaches a cron-style retention
# rule to one or more volumes — Savannaa runs the snapshot + offsite copy
# according to the policy. Distinct from sws_volume_snapshot (which is a
# single point-in-time copy you trigger explicitly).

resource "sws_backup_policy" "daily" {
  name = "${local.prefix}-daily"
  config = jsonencode({
    schedule        = "0 3 * * *"   # 03:00 every day
    retention_days  = var.backup_retention_days
    resource_ids    = [sws_volume.data.id]
    resource_type   = "volume"
  })
}

# ── Object Storage ─────────────────────────────────────────────────────────
# S3-style buckets. The provider exposes name only; bucket-level options
# (versioning, lifecycle, ACLs) are still console-only as of v0.4.

resource "sws_object_bucket" "buckets" {
  for_each = toset(var.object_buckets)
  name     = "${local.prefix}-${each.value}"
}

# ── File Storage ───────────────────────────────────────────────────────────
# NFS-style shared filesystem. Mountable from any VM in the same project.
# Useful for static assets, app uploads, shared logs.

resource "sws_file_storage" "shared" {
  count = var.enable_file_storage ? 1 : 0

  name = "${local.prefix}-shared"
  config = jsonencode({
    size_gb         = var.file_storage_size_gb
    protocol        = "NFS"
    network_id      = var.network_id
  })
}

# ── Volume Types ───────────────────────────────────────────────────────────
# Volume types aren't a separate terraform resource — they're an attribute
# (`volume_type`) on sws_volume. Available types in each region are listed
# at https://savannaa.com/storage/types (or in the console "Create Volume"
# wizard). Common defaults:
#
#   gp-ssd  — general-purpose SSD (this module's default)
#   io-ssd  — provisioned IOPS SSD, higher cost, predictable latency
#   hdd     — capacity HDD (Lagos region only, no Abuja yet)
#
# Tag a volume with a different type by setting var.volume_type.
