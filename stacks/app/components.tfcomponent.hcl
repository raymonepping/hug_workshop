component "nginx" {
  # Pin to the module in your repo's main branch
  source = "git::https://github.com/raymonepping/hug_workshop.git//modules/nginx?ref=main"
  inputs = {
    external_port = 8080
  }
}
