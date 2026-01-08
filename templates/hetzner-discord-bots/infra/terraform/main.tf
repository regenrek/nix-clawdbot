terraform {
  required_version = ">= 1.6.0"

  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = ">= 1.50.0"
    }
  }
}

variable "hcloud_token" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "admin_cidr" {
  type = string
}

variable "bootstrap_ssh" {
  type = bool
  default = true
}

variable "server_type" {
  type = string
  default = "cx22"
}

variable "location" {
  type = string
  default = "nbg1"
}

variable "wireguard_port" {
  type = string
  default = "51820"
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_ssh_key" "admin" {
  name       = "clawdbot-admin"
  public_key = var.ssh_public_key
}

module "bots01" {
  source        = "./modules/bot_host"
  name          = "bots01"
  admin_cidr    = var.admin_cidr
  ssh_key_id    = hcloud_ssh_key.admin.id
  bootstrap_ssh = var.bootstrap_ssh
  server_type   = var.server_type
  location      = var.location
  wireguard_port = var.wireguard_port
}
