output "url" {
  value = "http://${var.vm_host}:${var.external_port}/"
}
output "container" {
  value = module.web.container_name
}
output "network" {
  value = module.web.network_name
}
