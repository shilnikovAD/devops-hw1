variable "vm_host" {
  description = "IP или DNS-имя VM с Docker"
  type        = string
  default     = "111.88.162.133"
}

variable "ssh_user" {
  description = "Пользователь на VM (должен быть в группе docker)"
  type        = string
  default     = "student"
}

variable "name" {
  description = "Префикс имён ресурсов"
  type        = string
  default     = "tf-web"
}

variable "external_port" {
  description = "Порт на хосте (не стандартный 80)"
  type        = number
  default     = 8081

  validation {
    condition     = var.external_port > 1024 && var.external_port < 65536 && !contains([8080], var.external_port)
    error_message = "Порт должен быть 1025-65535 и не 8080 (занят pet-lab)."
  }
}

variable "subnet" {
  description = "Подсеть отдельной Docker-сети"
  type        = string
  default     = "172.30.0.0/24"
}

variable "image" {
  type    = string
  default = "nginx:1.28-alpine"
}

variable "greeting" {
  description = "Текст на странице"
  type        = string
  default     = "Hello from Terraform"
}
