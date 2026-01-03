packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

variable "fedora_version" {
  type    = string
  default = "43"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

source "amazon-ebs" "fedora" {
  ami_name      = "ebpf-vpc-runner-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  instance_type = "t3.small"
  region        = var.aws_region
  source_ami_filter {
    filters = {
      name                = "Fedora-Cloud-Base-${var.fedora_version}*.x86_64-hvm-*-gp2-0"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["125523088429"] # Fedora
  }
  ssh_username = "fedora"
}

build {
  sources = ["source.amazon-ebs.fedora"]

  provisioner "shell" {
    inline = [
      "sudo dnf install -y ansible-core",
      "ansible-galaxy install geerlingguy.docker",
      "ansible-galaxy install geerlingguy.pip",
      "ansible-galaxy collection install community.docker",
      "ansible-galaxy collection install ansible.posix",
      "ansible-galaxy collection install community.general"
    ]
  }
  provisioner "ansible-local" {
    playbook_dir  = "../ansible"
    playbook_file = "../ansible/site.yml"
    extra_arguments = [
      "--extra-vars", "ansible_user=fedora",
      "--extra-vars", "ssh_key_root=/dev/null",
      "--extra-vars", "ssh_key_ansible=/dev/null",
      "-c", "local"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo passwd -l fedora",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo cloud-init clean --logs --seed"
    ]
  }
}
