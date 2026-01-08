# Hetzner Discord-only bots (NixOS)

Production-ready template for **4 Discord-only Clawdbot instances** on a single Hetzner VM.

## What this gives you

- One-command bootstrap: Terraform + nixos-anywhere + disko
- WireGuard admin plane (VPN-only access after bootstrap)
- 4 bots (maren/sonja/gunnar/melinda) with **separate Linux users** + tokens
- sops-nix secrets with activation-time rendering
- Hardened systemd services + SMTP egress block

## Repo layout

```text
templates/hetzner-discord-bots/
  flake.nix
  configs/fleet.nix
  disko/bots01.nix
  nix/hosts/bots01.nix
  nix/modules/clawdbot-fleet.nix
  nix/nftables/egress-block.nft
  infra/terraform/{main.tf,outputs.tf}
  infra/terraform/modules/bot_host/main.tf
  scripts/bootstrap.sh
  secrets/.sops.yaml
  secrets/bots01.yaml
```

## 1) Configure Discord routing

Edit `templates/hetzner-discord-bots/configs/fleet.nix`:

- Replace `YOUR_GUILD_ID`
- Replace channel names (slugged, lowercase, no `#`)
- Adjust per-bot channel lists and mention rules

Routing is the single source of truth. Per-bot JSON config is generated from it and token-injected at activation time.

If you change `bots`, update `secrets/bots01.yaml` with matching `discord_token_<name>` keys.

## 2) Generate age key + sops file

```bash
cd templates/hetzner-discord-bots
mkdir -p secrets/hosts
age-keygen -o secrets/hosts/bots01.agekey
age-keygen -y secrets/hosts/bots01.agekey > secrets/hosts/bots01.age.pub
```

Update `secrets/.sops.yaml` with the `bots01.age.pub` contents.

Edit `secrets/bots01.yaml` values, then encrypt:

```bash
sops -e -i secrets/bots01.yaml
```

Prepare nixos-anywhere extra files (key for first boot):

```bash
mkdir -p secrets/extra-files/bots01/var/lib/sops-nix
cp secrets/hosts/bots01.agekey secrets/extra-files/bots01/var/lib/sops-nix/key.txt
```

## 3) Set your SSH and WireGuard keys

Edit `nix/hosts/bots01.nix`:

- `users.users.admin.openssh.authorizedKeys.keys`
- `services.clawdbotFleet.wireguard.adminPeerPublicKey`

## 4) Provision + install

```bash
cd templates/hetzner-discord-bots
export HCLOUD_TOKEN=...
export ADMIN_CIDR="your.ip.addr/32"
export SSH_PUBKEY_FILE="$HOME/.ssh/id_ed25519.pub"

./scripts/bootstrap.sh
```

Terraform is already modularized. Add a second host by instantiating another `bot_host` module in `infra/terraform/main.tf`.

Or copy `.env.example` to `.env` and load it with your shell/direnv.

## 5) Lock down to VPN-only

After WireGuard works:

1) Set `services.clawdbotFleet.bootstrapSsh = false;` in `nix/hosts/bots01.nix`
2) Rebuild over WireGuard:

```bash
nixos-rebuild switch --flake .#bots01 --target-host root@10.44.0.1
```

3) Remove public SSH rule from Hetzner firewall:

```bash
cd infra/terraform
terraform apply -auto-approve \
  -input=false \
  -var "hcloud_token=${HCLOUD_TOKEN}" \
  -var "admin_cidr=${ADMIN_CIDR}" \
  -var "ssh_public_key=$(cat "${SSH_PUBKEY_FILE}")" \
  -var "bootstrap_ssh=false"
```

## Operations

- Update routing: edit `configs/fleet.nix`, re-run `nixos-rebuild switch`.
- Rotate tokens: edit `secrets/bots01.yaml`, `sops -e -i`, rebuild.

## Module export

You can import the fleet module elsewhere:

```nix
{
  imports = [ ./nix/modules/clawdbot-fleet.nix ];
}
```

The module expects `nix-clawdbot` in `specialArgs` (see `templates/hetzner-discord-bots/flake.nix`).

## Verify

```bash
systemctl status clawdbot-maren
journalctl -u clawdbot-maren -f
```

## Notes

- Hetzner firewall is implicit-deny for any direction where rules are defined.
- Outbound SMTP is blocked on-host (`nix/nftables/egress-block.nft`).
- Discord starts only when a `discord` config exists and a token is set.
