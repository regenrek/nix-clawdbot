#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

: "${HCLOUD_TOKEN:?set HCLOUD_TOKEN}"
: "${ADMIN_CIDR:?set ADMIN_CIDR (your.ip.addr/32)}"
: "${SSH_PUBKEY_FILE:?set SSH_PUBKEY_FILE (path to your .pub)}"

if [ ! -f "${SSH_PUBKEY_FILE}" ]; then
  echo "SSH public key not found: ${SSH_PUBKEY_FILE}" >&2
  exit 1
fi

pushd infra/terraform >/dev/null
terraform init -input=false
terraform apply -auto-approve \
  -input=false \
  -var "hcloud_token=${HCLOUD_TOKEN}" \
  -var "admin_cidr=${ADMIN_CIDR}" \
  -var "ssh_public_key=$(cat "${SSH_PUBKEY_FILE}")" \
  -var "bootstrap_ssh=true"

IPV4="$(terraform output -raw ipv4)"
popd >/dev/null

echo "Target IPv4: ${IPV4}"

nix run github:nix-community/nixos-anywhere -- \
  --extra-files ./secrets/extra-files/bots01 \
  --flake .#bots01 \
  root@"${IPV4}"

echo
printf '%s
' \
  "Installed." \
  "Next:" \
  "1) Bring up WireGuard on your machine (peer 10.44.0.2)." \
  "2) Flip clawdbot.bootstrapSsh=false in nix/hosts/bots01.nix and rebuild." \
  "3) Re-apply terraform with bootstrap_ssh=false to remove public SSH."
