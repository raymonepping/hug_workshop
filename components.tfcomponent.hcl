component "nginx" {
  source = "../../modules/nginx"
  inputs = {
    # will be overridden per-deployment
    external_port = 8080
  }
}
