# Storage — Savannaa Terraform Module

End-to-end terraform that deploys every **Storage** product on Savannaa from one root module:

| Product | Resource | Notes |
|---|---|---|
| **Volumes** | `sws_volume` | Block storage. Sized in GiB, tagged with `volume_type`. |
| **Snapshots** | `sws_volume_snapshot` | Point-in-time crash-consistent copy of a volume. |
| **Volume Types** | attribute on `sws_volume` | Not a separate resource — set `volume_type = "gp-ssd"` etc. Module exposes a `var.volume_type` knob. |
| **Backups** | `sws_backup_policy` | Cron-style recurring schedule + retention, attached to volumes. |
| **Object Storage** | `sws_object_bucket` | S3-compatible bucket (versioning/lifecycle are console-only today). |
| **File Storage** | `sws_file_storage` | NFS share, mountable from any VM in the project. |
| **Images** | `data.sws_image` | Read-only — lookup by name to get an image id. |

Also provisions a tiny demo VM + volume-attachment so you can see the volume mount inside an actual instance.

---

## Prerequisites

1. A Savannaa account → **API key** from https://savannaa.com/account/api-keys.
2. **terraform** ≥ 1.5 ([install](https://developer.hashicorp.com/terraform/install)).
3. Your **network ID** from the Savannaa console → Networks page (only the demo VM uses it — storage objects themselves are region-scoped, not network-scoped).

---

## Step-by-step

### 1. Clone

```bash
git clone https://github.com/savannaacloud/storage.git
cd storage
```

### 2. Set credentials

```bash
export SWS_API_URL="https://savannaa.com"
export SWS_API_KEY="sws_..."           # from https://savannaa.com/account/api-keys
```

### 3. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars               # set network_id at minimum
```

### 4. Initialise

```bash
terraform init
```

Downloads the `savannaacloud/sws` provider from the public Terraform registry.

### 5. Preview

```bash
terraform plan
```

You should see roughly:
* 1 × volume + 1 × volume_attachment + 1 × volume_snapshot
* 1 × backup_policy (daily, 7-day retention)
* 3 × object_bucket (assets / logs / backups)
* 1 × file_storage (100 GiB NFS share)
* 1 × keypair + 1 × instance (the demo VM)

### 6. Apply

```bash
terraform apply
```

Type `yes`. Apply takes ~90 s on a warm region (image already pulled), up to 4 min on first run.

### 7. Capture the private key (only once!)

```bash
terraform output -raw keypair_private_key > ~/.ssh/storage-demo.pem
chmod 600 ~/.ssh/storage-demo.pem
```

### 8. Verify the volume is mounted inside the VM

```bash
ssh -i ~/.ssh/storage-demo.pem ubuntu@$(terraform output -raw vm_id)   # use the public IP from the console
sudo lsblk                              # /dev/vdb should be 20 GiB
sudo mkfs.ext4 /dev/vdb && sudo mkdir -p /mnt/data && sudo mount /dev/vdb /mnt/data
df -h /mnt/data
```

### 9. Try the object storage

```bash
export AWS_ACCESS_KEY_ID="$SWS_API_KEY"
export AWS_SECRET_ACCESS_KEY="$SWS_API_SECRET"    # from https://savannaa.com/account/api-keys
export AWS_ENDPOINT_URL_S3=$(terraform output -raw object_endpoint)

aws s3 ls
aws s3 cp /etc/hostname s3://$(terraform output -json object_bucket_names | jq -r '.[0]')/hello.txt
```

### 10. Mount the file share

The provider returns the share `id`; the live NFS mount address is rendered in the console (Storage → File Storage → click the share) or via `GET /api/storage/file-storage/<id>`. Copy that address into the mount command below.

```bash
sudo apt-get install -y nfs-common
sudo mkdir -p /mnt/shared
SHARE_ID=$(terraform output -raw file_storage_id)
# Visit https://savannaa.com/storage/file-storage/$SHARE_ID and copy the NFS address.
sudo mount -t nfs <nfs-address>:/ /mnt/shared
echo "shared from $(hostname)" | sudo tee /mnt/shared/test.txt
```

### 11. Tear down

```bash
terraform destroy
```

~60 s — Savannaa cascade-deletes attachments, snapshots, and bucket contents in the right order.

---

## Layout

```
storage/
├── README.md                    ← you are here
├── versions.tf                  ← provider pin (sws ~> 0.4)
├── variables.tf                 ← knobs (region, sizes, toggles, network)
├── main.tf                      ← every Storage resource + demo VM
├── outputs.tf                   ← volume id, snapshot, bucket names, NFS mount
├── terraform.tfvars.example     ← copy → terraform.tfvars and edit
├── .gitignore                   ← keeps state + keys out of the repo
└── examples/
    └── minimal/                 ← single 20 GiB volume; smoke-test
```

---

## Volume Types — picking the right tier

| Type | Workload | Region availability |
|---|---|---|
| `gp-ssd` | General-purpose (web, dev/test) — module default | Abuja + Lagos |
| `io-ssd` | Provisioned IOPS, predictable latency (DB, FS journal) | Abuja + Lagos |
| `hdd` | Cold archive, large sequential reads | Lagos only |

Set `volume_type = "io-ssd"` in `terraform.tfvars` to switch.

---

## Backups vs Snapshots — when to use which

* **Snapshot (`sws_volume_snapshot`)** — single point-in-time copy you trigger explicitly. Use when you're about to run a risky migration, or as a "save game" before a deploy.
* **Backup policy (`sws_backup_policy`)** — recurring schedule with retention. Savannaa takes the snapshot for you at the cron time + ships a copy to a separate region for disaster recovery. Use for production data.

The module sets both: one immediate snapshot + a daily policy on the same volume.

---

## Common gotchas

* **`volume_type "hdd" not found`** — HDD is Lagos-only; in Abuja stick with `gp-ssd` / `io-ssd`.
* **`bucket name conflict`** — bucket names are unique inside your project. Change `prefix` if a re-apply in a different env collides.
* **`mount: protocol family not supported`** — install `nfs-common` (Ubuntu/Debian) or `nfs-utils` (RHEL/Fedora) before mounting the file share.
* **Snapshot still listed after `terraform destroy`** — Savannaa keeps snapshots for 24 h in the "Recycle Bin" so you can recover from accidental deletes. Empty the bin in the console if you need the storage back immediately.

---

## Region toggle

```hcl
region = "ng-lagos-1"   # was "ng-abuja-1"
```

The object-storage endpoint output automatically picks the right region URL (`abuja.objects.savannaa.com` vs `lagos.objects.savannaa.com`).

---

## Support

* Console: https://savannaa.com/storage
* Docs: https://savannaa.com/docs
* Issues with this module: https://github.com/savannaacloud/storage/issues
