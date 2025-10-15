deployment "blue" {
  inputs = {
    external_port = 8080
  }
}

deployment "green" {
  inputs = {
    external_port = 8081
  }
}
