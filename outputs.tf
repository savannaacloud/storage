output "image_id" {
  description = "Image data-source result — proves the lookup succeeded."
  value       = data.sws_image.ubuntu.id
}

output "volume_id" {
  value = sws_volume.data.id
}

output "volume_attachment_device" {
  description = "Inside the VM this volume appears as /dev/vdb (or similar — check `lsblk`)."
  value       = try(sws_volume_attachment.data.device, "vdb")
}

output "snapshot_id" {
  value = try(sws_volume_snapshot.data[0].id, null)
}

output "backup_policy_id" {
  value = sws_backup_policy.daily.id
}

output "object_bucket_names" {
  description = "S3-compatible bucket names you can point AWS SDKs at."
  value       = [for b in sws_object_bucket.buckets : b.name]
}

output "object_endpoint" {
  description = "Endpoint to set as AWS_ENDPOINT_URL_S3 in your SDK / aws-cli config."
  value       = "https://${var.region == "ng-abuja-1" ? "abuja" : "lagos"}.objects.savannaa.com"
}

output "file_storage_id" {
  description = "File share id. Grab the NFS mount address from the console — Storage → File Storage → this id — or via the API: GET /api/storage/file-storage/<id>."
  value       = try(sws_file_storage.shared[0].id, null)
}

output "keypair_name" {
  description = "Keypair Nova injects into the demo VM. SSH using the private half of the public key you passed via var.ssh_public_key_file."
  value       = sws_keypair.demo.name
}

output "keypair_fingerprint" {
  description = "MD5 fingerprint Nova returned for the registered public key."
  value       = sws_keypair.demo.fingerprint
}

output "vm_id" {
  value = sws_instance.vm.id
}
