terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

variable "external_port" {
  type    = number
  default = 8080
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = false
}

resource "docker_container" "nginx" {
  name  = "hug-nginx-${var.external_port}"
  image = docker_image.nginx.name

  ports {
    internal = 80
    external = var.external_port
  }
}

output "container_name" {
  value = docker_container.nginx.name
}

output "endpoint" {
  value = "http://localhost:${var.external_port}"
}
