locals {
  active = var.running ? { postgres = 5432, vault = 8200, backend = 3004, frontend = 5173 } : {}
}
resource "docker_image" "service" {
  for_each     = var.images
  name         = each.value
  keep_locally = true
}
resource "docker_volume" "postgres" {
  name = "${var.name}-data"
  labels {
    label = "workshop.instance"
    value = var.name
  }
}
resource "docker_network" "lab" {
  count = var.running ? 1 : 0
  name  = "${var.name}-net"
  lifecycle {
    # Podman injects its IPAM driver options; no desired IPAM override exists here.
    ignore_changes = [ipam_options]
  }
  labels {
    label = "workshop.instance"
    value = var.name
  }
}
resource "docker_container" "service" {
  lifecycle {
    # Podman reports host-derived RLIMIT defaults absent from Docker configuration.
    ignore_changes = [ulimit]
  }
  for_each      = local.active
  name          = "${var.name}-${each.key}"
  image         = docker_image.service[each.key].image_id
  hostname      = each.key
  restart       = "no"
  pid_mode      = "private"
  security_opts = ["label=disable"]
  labels {
    label = "workshop.instance"
    value = var.name
  }
  networks_advanced {
    name    = docker_network.lab[0].name
    aliases = [each.key]
  }
  ports {
    internal = each.value
    external = var.ports[each.key]
    ip       = "127.0.0.1"
  }
  env        = each.key == "postgres" ? ["POSTGRES_DB=workshop", "POSTGRES_PASSWORD_FILE=/bootstrap/admin-password"] : each.key == "vault" ? ["VAULT_DISABLE_MLOCK=true"] : each.key == "backend" ? ["PORT=3004", "DB_TYPE=postgres", "DB_HOST=postgres", "DB_NAME=workshop", "VAULT_ADDR=http://vault:8200", "RUNTIME_DIR=/runtime", "WORKSHOP_PROFILE=${var.profile}", "DB_AUTH_MODE=${var.mode}"] : ["PORT=5173", "FRONTEND_API_BASE=http://127.0.0.1:${var.ports["backend"]}"]
  entrypoint = each.key == "vault" ? ["/bin/sh", "-ec", "export VAULT_DEV_ROOT_TOKEN_ID=$(cat /bootstrap/root-token); exec /usr/local/bin/docker-entrypoint.sh server -dev -dev-listen-address=0.0.0.0:8200 1>/dev/null"] : null
  dynamic "volumes" {
    for_each = each.key == "postgres" ? [1] : []
    content {
      volume_name    = docker_volume.postgres.name
      container_path = "/var/lib/postgresql/data"
    }
  }
  dynamic "volumes" {
    for_each = each.key == "frontend" ? [] : [each.key]
    content {
      host_path      = "${var.runtime}/${each.key == "backend" ? "app" : each.key == "postgres" ? "postgres" : "vault"}"
      container_path = each.key == "backend" ? "/runtime" : "/bootstrap"
      read_only      = true
    }
  }
}
