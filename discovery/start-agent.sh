#!/usr/bin/env bash
# Genereert agent.yaml met echte credentials (env vars worden niet doorgegeven aan de backend)
# en start de Orb Agent. Voer uit in /vagrant/discovery.

set -e
cd "$(dirname "$0")"

CREDS_FILE="/opt/diode/oauth2/client/client-credentials.json"
ALT_CREDS_FILE="/vagrant/diode/oauth2/client/client-credentials.json"
if [ ! -f "$CREDS_FILE" ]; then
  if [ -f "$ALT_CREDS_FILE" ]; then
    CREDS_FILE="$ALT_CREDS_FILE"
  else
    echo "Fout: $CREDS_FILE niet gevonden. Draai eerst de Diode quickstart."
    exit 1
  fi
fi

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst niet gevonden. Installeer met: sudo apt-get install -y gettext-base"
  exit 1
fi

export DIODE_CLIENT_ID="diode-ingest"
export DIODE_CLIENT_SECRET=$(sudo jq -r '.[] | select(.client_id == "diode-ingest") | .client_secret' "$CREDS_FILE")

if [ -z "$DIODE_CLIENT_SECRET" ]; then
  echo "Fout: kon diode-ingest secret niet ophalen uit $CREDS_FILE"
  exit 1
fi

# Optioneel: voor device_discovery, export DEVICE_USERNAME en DEVICE_PASSWORD
export DEVICE_USERNAME="${DEVICE_USERNAME:-}"
export DEVICE_PASSWORD="${DEVICE_PASSWORD:-}"

# Vul template in zodat de backend echte waarden krijgt (niet ${VAR})
envsubst '${DIODE_CLIENT_ID} ${DIODE_CLIENT_SECRET} ${DEVICE_USERNAME} ${DEVICE_PASSWORD}' < agent.yaml.example > agent.yaml
echo "agent.yaml gegenereerd met credentials."

exec sudo docker run --rm --network host -v "$(pwd):/opt/orb" \
  netboxlabs/orb-agent:latest run -c /opt/orb/agent.yaml
