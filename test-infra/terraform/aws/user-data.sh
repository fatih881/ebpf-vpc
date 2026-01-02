#!/bin/bash
set -e

GH_OWNER="${gh_owner}"
GH_REPO="${gh_repo}"
GH_RUNNER_TOKEN="${gh_runner_token}"
INSTANCE_ID="${instance_id}"
AWS_REGION="${aws_region}"

RUNNER_HOME="/home/fedora/actions-runner"
RUNNER_VERSION="2.316.0"
RUNNER_ARCH="x64"

echo "Starting GitHub Actions Runner setup on instance ${INSTANCE_ID} in ${AWS_REGION}"

sudo dnf update -y
sudo dnf install -y git libicu curl

sudo -u fedora mkdir -p "${RUNNER_HOME}"
cd "${RUNNER_HOME}"

sudo -u fedora curl -o actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz -L \
"https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"

sudo -u fedora tar xzf "./actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"

sudo -u fedora "${RUNNER_HOME}/config.sh" \
    --url "https://github.com/${GH_OWNER}/${GH_REPO}" \
    --token "${GH_RUNNER_TOKEN}" \
    --labels "self-hosted,linux,x64,fedora" \
    --name "${GH_OWNER}-${GH_REPO}-runner-${INSTANCE_ID}" \
    --unattended \
    --replace

sudo "${RUNNER_HOME}/svc.sh" install fedora
sudo "${RUNNER_HOME}/svc.sh" start

echo "GitHub Actions Runner setup complete."
