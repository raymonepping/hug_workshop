locals {
  # Map email → username (left side of @)
  users = {
    for email in var.users_set :
    email => split("@", email)[0]
  }

  # Also expose a map username → email if convenient
  users_by_name = {
    for email, username in local.users :
    username => email
  }
}
