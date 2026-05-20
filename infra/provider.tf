provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Course      = "DGITI-UPB"
      Owner       = "johan.rc2020"
    }
  }
}

provider "random" {}
