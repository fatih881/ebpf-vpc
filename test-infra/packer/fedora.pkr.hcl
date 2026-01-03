packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
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

variable "iso_url" {
  type    = string
  default = "https://download.fedoraproject.org/pub/fedora/linux/releases/43/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-43-1.6.x86_64.qcow2"
}

variable "iso_checksum" {
  type    = string
  default = "file:https://download.fedoraproject.org/pub/fedora/linux/releases/43/Cloud/x86_64/images/Fedora-Cloud-43-1.6-x86_64-CHECKSUM"
}

source "qemu" "fedora" {
  iso_url           = var.iso_url
  iso_checksum      = var.iso_checksum
  disk_image        = true
  output_directory  = "output-fedora-nocloud"
  shutdown_command  = "echo 'packer' | sudo -S shutdown -P now"
  ssh_username      = "fedora"
  ssh_password      = "packer"
  ssh_timeout       = "20m"
  vm_name           = "fedora-nocloud.qcow2"
  net_device        = "virtio-net"
  disk_interface    = "virtio"
  boot_wait         = "5s"
  headless          = true
  memory            = 2048
  cpus              = 2
  format            = "qcow2"
  cd_files = [
    "./config/user-data",
    "./config/meta-data"
  ]
  cd_label = "cidata"
}

build {
  sources = ["source.qemu.fedora"]
  provisioner "file" {
    source      = "/home/sysadmin/.ssh/ansible.pub"
    destination = "/tmp/ansible.pub"
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /home/fedora/.ssh",
      "mv /tmp/ansible.pub /home/fedora/.ssh/ansible.pub",
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
      "--extra-vars", "ansible_sudo_pass=packer",
      "--extra-vars", "ssh_key_root=/dev/null",
      "--extra-vars", "ssh_key_ansible=/dev/null",
      "-c", "local"
    ]
  }
}
