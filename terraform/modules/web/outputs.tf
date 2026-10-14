output "container_name" {
  value = docker_container.web.name
}
output "network_name" {
  value = docker_network.this.name
}
