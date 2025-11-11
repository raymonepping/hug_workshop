terraform {
  required_version = ">= 1.6.0"
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.54.0"
    }
  }
}

provider "tfe" {
  hostname = "app.terraform.io"
}
