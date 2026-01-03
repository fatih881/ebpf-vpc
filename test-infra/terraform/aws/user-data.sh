#!/bin/bash
set -e

RUNNER_HOME="/home/fedora/actions-runner"
RUNNER_VERSION="2.316.0"
RUNNER_ARCH="x64"

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
instance_id=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v "http://169.254.169.254/latest/meta-data/instance-id")

echo "Starting GitHub Actions Runner setup on instance $${instance_id} in ${aws_region}"

sudo dnf update -y
sudo dnf install -y git libicu curl

sudo -u fedora mkdir -p "$${RUNNER_HOME}"
cd "$${RUNNER_HOME}"

sudo -u fedora curl -o actions-runner-linux-$${RUNNER_ARCH}-$${RUNNER_VERSION}.tar.gz -L \
"https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/actions-runner-linux-$${RUNNER_ARCH}-$${RUNNER_VERSION}.tar.gz"

sudo -u fedora tar xzf "./actions-runner-linux-$${RUNNER_ARCH}-$${RUNNER_VERSION}.tar.gz"

sudo -u fedora "$${RUNNER_HOME}/config.sh" \
    --url "https://github.com/${gh_owner}/${gh_repo}" \
    --token "${gh_runner_token}" \
    --labels "self-hosted,linux,x64,fedora" \
    --name "${gh_owner}-${gh_repo}-runner-$${instance_id}" \
    --unattended \
    --replace

sudo "$${RUNNER_HOME}/svc.sh" install fedora
sudo "$${RUNNER_HOME}/svc.sh" start

echo "GitHub Actions Runner setup complete."
