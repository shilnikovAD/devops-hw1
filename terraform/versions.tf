terraform {
  required_version = ">= 1.6"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host     = "ssh://${var.ssh_user}@${var.vm_host}:22"
  ssh_opts = ["-o", "StrictHostKeyChecking=accept-new"]
}
