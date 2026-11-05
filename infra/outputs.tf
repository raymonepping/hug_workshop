output "metadata" {
  value = {
    name    = var.name
    runtime = var.runtime
    ports   = var.ports
    urls    = { for k, p in var.ports : k => "http://127.0.0.1:${p}" if k != "postgres" }
  }
}
