terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# provision and configure AWS backend
module "aws_autobootstrap" {
  source       = "./aws_autobootstrap"
  project_name = lower(replace(var.server_name,".","-"))
  region       = var.region
}

module "aws_networking" {
  source       = "./aws_networking"
  network_name = var.server_name
  region       = var.region
}

module "aws_server" {
  source          = "./aws_server"
  server_name     = var.server_name
  region          = var.region
  ami             = "ami-09439f09c55136ecf"
  vpc_id          = module.aws_networking.vpc_id
  security_groups = [aws_security_group.web.id]
  subnet_id       = module.aws_networking.subnet_id["0"]
  public_key      = var.public_key
}

locals {
  domains = {
    for idx, domain in var.domains : "${idx}" => {
      domain = domain
      ips    = [module.aws_server.public_ip]
    }
  }
}

module "aws_dns" {
  source  = "./aws_dns"
  domains = local.domains
}

resource "local_file" "nameservers" {
  filename = "${path.module}/nameservers"
  content  = <<-EOT
  %{for idx, zone in module.aws_dns.name_servers~}
[${local.domains[idx].domain}]
    %{for ns in zone~}
${ns}
    %{endfor~}
  %{endfor~}
  EOT
}


resource "local_file" "bootstrap_inventory" {
  content  = <<-EOT
[all:vars]
ansible_ssh_private_key_file=../ssh/ssh_key

[aws_linux2:vars]
ansible_user=ec2-user

[aws_linux2]
${module.aws_server.public_ip}
  EOT
  filename = "${path.module}/ansible_wordpress/inventory/bootstrap/hosts"
}

resource "local_file" "production_inventory" {
  content  = <<-EOT
[all:vars]
ansible_user=ansible
ansible_ssh_private_key_file=../ssh/ssh_key

[cloud]
${module.aws_server.public_ip}

[database]
${module.aws_server.public_ip}

[wordpress]
${module.aws_server.public_ip}
  EOT
  filename = "${path.module}/ansible_wordpress/inventory/production/hosts"
}
