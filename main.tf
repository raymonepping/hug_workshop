terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = false
}

resource "docker_container" "nginx" {
  name  = "hug-nginx"
  image = docker_image.nginx.name

  ports {
    internal = 80
    external = 8080
  }
}

output "nginx_container_name" {
  value = docker_container.nginx.name
}

output "nginx_container_port" {
  value = docker_container.nginx.ports[0].external
}
