FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_ALLOW_RUNASROOT=1
RUN apt-get update && apt-get install -y \
    curl jq git build-essential \
    libssl-dev libffi-dev \
    ca-certificates gnupg lsb-release \
    libdigest-sha-perl \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y docker-ce-cli
WORKDIR /actions-runner
ARG GH_TOKEN
RUN LATEST_RELEASE=$(curl -s -H "Authorization: Bearer $GH_TOKEN" https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name) && \
    RUNNER_VERSION=$(echo ${LATEST_RELEASE} | sed 's/v//g') && \
    curl -o runner.tar.gz -L https://github.com/actions/runner/releases/download/${LATEST_RELEASE}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    tar xzf runner.tar.gz && \
    rm runner.tar.gz && \
    ./bin/installdependencies.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]