component "nginx" {
  source = "git::https://github.com/raymonepping/hug_workshop.git//modules/nginx?ref=main"
  inputs = {
    external_port = 8080
  }
}
