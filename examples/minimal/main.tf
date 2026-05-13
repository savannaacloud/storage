terraform {
  required_providers {
    sws = { source = "savannaacloud/sws", version = "~> 0.4" }
  }
}

# Smallest possible storage footprint: just a 20 GB volume, no VM, no
# snapshots, no buckets. Apply this first to confirm your auth + region
# work before turning on the larger module.

resource "sws_volume" "data" {
  name = "storage-minimal"
  size = 20
}

output "volume_id" { value = sws_volume.data.id }
