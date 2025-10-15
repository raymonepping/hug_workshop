# components.tfcomponent.hcl (at repo root on stack-app)
component "nginx" {
  source = "./modules/nginx"  # <- correct

  inputs = {
    external_port = 8080
  }
}
