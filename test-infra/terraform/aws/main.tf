# main.tf for AWS GitHub Actions Runner

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
}

variable "gh_owner" {
  type        = string
}

variable "gh_repo" {
  type        = string
}

variable "gh_runner_token" {
  type        = string
  sensitive   = true
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
}

variable "subnet_id" {
  type        = string
}

variable "security_group_ids" {
  type        = list(string)
}

variable "key_name" {
  type        = string
  default     = ""
}

data "aws_ami" "latest_runner" {
  owners      = [data.aws_caller_identity.current.account_id]

  filter {
    name   = "name"
    values = ["ebpf-vpc-runner-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  most_recent = true
}

data "aws_caller_identity" "current" {}


resource "aws_instance" "github_runner" {
  ami           = data.aws_ami.latest_runner.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  security_groups = var.security_group_ids

  key_name = var.key_name == "" ? null : var.key_name

  tags = {
    Name        = "github-runner-${var.gh_owner}-${var.gh_repo}"
    Project     = "ebpf-vpc"
    RunnerOwner = var.gh_owner
    RunnerRepo  = var.gh_repo
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    gh_owner        = var.gh_owner
    gh_repo         = var.gh_repo
    gh_runner_token = var.gh_runner_token
    instance_id     = aws_instance.github_runner.id
    aws_region      = var.aws_region
  }))

  lifecycle {
    ignore_changes = [
    ]
  }
}
