terraform {
  backend "s3" {
    bucket         = "tekmetric-terraform-state-096610237522"
    key            = "bootstrap/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tekmetric-terraform-locks-096610237522"
    encrypt        = true
  }
}