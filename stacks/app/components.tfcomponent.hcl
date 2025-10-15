component "nginx" {
  source = "./modules/nginx"  

  inputs = {
    external_port = 8080  
  }
}
