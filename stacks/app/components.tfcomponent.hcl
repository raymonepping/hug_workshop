component "nginx" {
  source = "../../modules/nginx"
  inputs = {
    # default; overridden per-deployment
    external_port = 8080
  }
}
