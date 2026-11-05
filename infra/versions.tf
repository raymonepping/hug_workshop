terraform {
  required_version = ">= 1.6, < 2.0"
  backend "local" {}
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.2"
    }
  }
}
provider "docker" {
  host = var.podman_socket
}
