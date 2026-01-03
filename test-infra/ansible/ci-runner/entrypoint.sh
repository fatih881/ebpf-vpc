#!/bin/bash
set -e
if [ -z "$GH_PAT" ] || [ -z "$GH_REPO_URL" ]; then
    echo "Error: GH_PAT and GH_REPO_URL environment variables are required."
    exit 1
fi
REPO_NAME=$(echo "${GH_REPO_URL}" | sed -e 's|https://github.com/||' -e 's|/$||')

echo "--> Getting Registration Token for ${REPO_NAME}..."
REG_TOKEN=$(curl -sX POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GH_PAT}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${REPO_NAME}/actions/runners/registration-token | jq .token --raw-output)

if [ "$REG_TOKEN" == "null" ] || [ -z "$REG_TOKEN" ]; then
    echo "Error: Failed to get registration token. Check your PAT scopes (repo, workflow)."
    exit 1
fi
echo "fetch location"

COUNTRY=$(curl -s --connect-timeout 5 https://api.country.is | jq -r .country 2>/dev/null || echo "")
COUNTRY=$(echo "$RESPONSE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/^-//;s/-$//')

if [ -z "$COUNTRY" ] || [ "$COUNTRY" == "error" ]; then
  COUNTRY="unknown"
fi

echo "Detected Country: ${COUNTRY}"

echo "Checking existing runners"
RUNNERS_JSON=$(curl -s -H "Authorization: Bearer ${GH_PAT}" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/${REPO_NAME}/actions/runners?per_page=100)

MAX_ID=0
EXISTING_NAMES=$(echo "$RUNNERS_JSON" | jq -r '.runners[].name')

while read -r name; do
  if [[ "$name" =~ ^${COUNTRY}-([0-9]+)$ ]]; then
    ID="${BASH_REMATCH[1]}"
    if (( ID > MAX_ID )); then
      MAX_ID=$ID
    fi
  fi
done <<< "$EXISTING_NAMES"

NEXT_ID=$((MAX_ID + 1))
RUNNER_NAME="${COUNTRY}-${NEXT_ID}"

echo " Assigning Runner Name: ${RUNNER_NAME}"

echo "--> Configuring Runner..."
./config.sh \
    --url "${GH_REPO_URL}" \
    --token "${REG_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --work "_work" \
    --labels "self-hosted,linux,x64,bare-metal,${COUNTRY}" \
    --unattended \
    --replace
cleanup() {
    echo "--> Removing runner..."
    ./config.sh remove --token "${REG_TOKEN}"
}
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

echo "--> Starting Runner..."
./run.sh & wait $!