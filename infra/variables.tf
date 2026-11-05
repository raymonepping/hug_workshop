variable "name" { type = string }
variable "runtime" { type = string }
variable "podman_socket" { type = string }
variable "ports" { type = map(number) }
variable "images" { type = map(string) }
variable "profile" { type = string }
variable "mode" { type = string }
variable "running" {
  type    = bool
  default = true
}
