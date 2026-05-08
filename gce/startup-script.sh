#!/bin/bash
# Startup script for Ferentin Service Edge on COS-backed GCE VMs in a MIG.
#
# Responsibilities:
#   1. Mount/format persistent disks under /mnt/disks/{certs,policy}.
#   2. Fetch ENROLLMENT_TOKEN and FERENTIN_KEY_PASSPHRASE from Secret Manager.
#   3. chown the volumes to UID 1000 (the non-root user inside the container).
#   4. Inject the secrets into the container's env (Docker reads from /etc/profile.d).
#
# This script runs as root on the VM. The container itself is started by
# COS's container-runtime via the instance metadata's container-declaration —
# we don't `docker run` here.
#
# Required instance metadata:
#   - container-declaration (set by gcloud compute instances create-with-container)
#   - secret-enrollment-token-name: name of the Secret Manager secret holding
#     the enrollment token (e.g., projects/PROJECT_ID/secrets/ferentin-edge-enroll/versions/latest)
#   - secret-passphrase-name: name of the Secret Manager secret holding the
#     at-rest encryption passphrase

set -euo pipefail

# Read metadata
META() {
  curl -s -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1"
}

ENROLL_SECRET=$(META secret-enrollment-token-name || true)
PASSPHRASE_SECRET=$(META secret-passphrase-name || true)

if [[ -z "$ENROLL_SECRET" || -z "$PASSPHRASE_SECRET" ]]; then
  echo "ERROR: Required metadata attributes missing. Set via --metadata=secret-enrollment-token-name=...,secret-passphrase-name=..." >&2
  exit 1
fi

# Fetch secrets via the metadata-server-issued access token (the VM's runtime SA
# must hold roles/secretmanager.secretAccessor on these secrets)
ACCESS_TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["access_token"])')

ENROLL_TOKEN=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://secretmanager.googleapis.com/v1/$ENROLL_SECRET:access" \
  | python3 -c 'import base64,json,sys;print(base64.b64decode(json.load(sys.stdin)["payload"]["data"]).decode())')

PASSPHRASE=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://secretmanager.googleapis.com/v1/$PASSPHRASE_SECRET:access" \
  | python3 -c 'import base64,json,sys;print(base64.b64decode(json.load(sys.stdin)["payload"]["data"]).decode())')

# Prepare host paths for the container's bind mounts. UID 1000 is the
# non-root user inside the service-edge image.
mkdir -p /mnt/disks/certs /mnt/disks/policy /var/log/ferentin
chown -R 1000:1000 /mnt/disks/certs /mnt/disks/policy /var/log/ferentin

# Inject secrets into the container's env via the COS container-declaration's
# env mechanism. The simplest approach: write a systemd drop-in that exports
# them when the container service starts. COS uses cloud-init + a containerd
# unit named `konlet-startup`.
mkdir -p /etc/systemd/system/konlet-startup.service.d
cat > /etc/systemd/system/konlet-startup.service.d/secrets.conf <<EOF
[Service]
Environment="ENROLLMENT_TOKEN=$ENROLL_TOKEN"
Environment="FERENTIN_KEY_PASSPHRASE=$PASSPHRASE"
EOF

systemctl daemon-reload
systemctl restart konlet-startup.service

echo "Service Edge startup complete."
