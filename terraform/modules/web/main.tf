resource "docker_network" "this" {
  name         = "${var.name}-net"
  driver       = "bridge"
  attachable   = false
  ingress      = false
  ipv6         = false
  ipam_options = {}

  ipam_config {
    subnet  = var.subnet
    gateway = cidrhost(var.subnet, 1)
  }
}

resource "docker_image" "nginx" {
  name         = var.image
  keep_locally = true
}

resource "docker_container" "web" {
  name    = var.name
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.this.name
  }

  ports {
    internal = 80
    external = var.external_port
  }

  upload {
    file    = "/usr/share/nginx/html/index.html"
    content = var.html
  }

  healthcheck {
    test     = ["CMD", "wget", "-qO-", "http://127.0.0.1/"]
    interval = "10s"
    timeout  = "3s"
    retries  = 3
  }
}
