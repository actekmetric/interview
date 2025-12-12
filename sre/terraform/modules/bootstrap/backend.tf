terraform {
  backend "s3" {
    bucket         = "tekmetric-terraform-state-us-east-1-596308305263"
    key            = "bootstrap/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tekmetric-terraform-locks-us-east-1-596308305263"
    encrypt        = true
  }
}
