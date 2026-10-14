module "web" {
  source        = "./modules/web"
  name          = var.name
  subnet        = var.subnet
  image         = var.image
  external_port = var.external_port

  html = templatefile("${path.root}/templates/index.html.tftpl", {
    greeting = var.greeting
    name     = var.name
    network  = "${var.name}-net"
    subnet   = var.subnet
    port     = var.external_port
  })
}
