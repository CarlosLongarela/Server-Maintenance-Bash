#!/bin/bash

# Default values.
THRESHOLD=1000 # Number of firewall events to trigger the alert.
INTERVAL=300   # Time interval between checks in seconds.
LANGUAGE="EN"  # Language for alerts: EN (English) or ES (Spanish).
COOLDOWN=21600 # Time to wait after an alert in seconds (6 hours by default).

# include file with Cloudflare variables
source CLOUDFLARE_CONFIG

# include file with Telegram variables
source TELEGRAM_CONFIG

# Function to show help message in English.
show_help_en() {
    echo "Usage: $0 -t <event_threshold> -i <interval_seconds> [-l ES|EN] [-h] [-a]"
    echo "  -t: Number of firewall events to trigger the alert (must be greater than 100)."
    echo "  -i: Time interval between checks in seconds (must be greater than 60)."
    echo "  -c: (Optional) Waiting period after an alert in seconds. Default is 21600 (6 hours)."
    echo "  -l: (Optional) Language of the alert message. Default is EN (English)."
    echo "  -h: Show this help message in English."
    echo "  -a: Show this help message in Spanish."
    exit 0
}

# Function to show help message in Spanish.
show_help_es() {
    echo "Uso: $0 -t <umbral_eventos> -i <intervalo_segundos> [-l ES|EN] [-h] [-a]"
    echo "  -t: Número de eventos de firewall para activar la alerta (debe ser mayor de 100)."
    echo "  -i: Intervalo de tiempo entre verificaciones en segundos (debe ser mayor de 60)."
    echo "  -c: (Opcional) Período de espera después de una alerta en segundos. Por defecto 21600 (6 horas)."
    echo "  -l: (Opcional) Idioma del mensaje de alerta. Por defecto EN (Inglés)."
    echo "  -h: Mostrar esta ayuda en inglés."
    echo "  -a: Mostrar esta ayuda en español."
    exit 0
}

# Obtain the options we passed to the script.
while getopts "t:i:c:l:h:a" opt; do
    case "$opt" in
        t) THRESHOLD=$OPTARG ;;
        i) INTERVAL=$OPTARG ;;
        c) COOLDOWN=$OPTARG ;;
        l) LANGUAGE=$OPTARG ;;
        h) show_help_en ;;
        a) show_help_es ;;
        *) show_help_en ;;
    esac
done

# Parameters validation.
if [[ "$THRESHOLD" -le 100 || "$INTERVAL" -le 60 || ! "$LANGUAGE" =~ ^(ES|EN)$ ]]; then
    show_help_en
fi

# Function to send a message to Telegram.
send_telegram_message() {
  local message=$1
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="${message}" > /dev/null
}

# Principal loop
last_alert_time=0
while true; do
  current_time=$(date +%s)

  # Check if the cooldown period has passed since the last alert.
  if (( current_time - last_alert_time >= COOLDOWN )); then
    # Actual date and 24 hours ago in ISO 8601 format.
    DATE_NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    DATE_24H_AGO=$(date -u -d "24 hours ago" +"%Y-%m-%dT%H:%M:%SZ")

    # GraphQL query
    read -r -d '' QUERY << EOF
    {
        viewer {
        zones(filter: {accountTag: "${CF_ACCOUNT_ID}"}) {
            firewallEventsAdaptiveGroups(
            limit: 1,
            filter: {
                datetime_geq: "${DATE_24H_AGO}",
                datetime_leq: "${DATE_NOW}"
            }
            ) {
            count
            }
        }
        }
    }
EOF

    # Make the request with curl.
    response=$(curl -s -X POST "${CF_GRAPHQL_ENDPOINT}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${CF_API_KEY}" \
        --data "{\"query\":\"${QUERY}\"}")

    # Extract the number of firewall events.
    event_count=$(echo "$response" | jq '.data.viewer.zones[0].firewallEventsAdaptiveGroups[0].count')

    # Verification and sending of alert.
    if [[ "$event_count" -gt "$THRESHOLD" ]]; then
        if [[ "$LANGUAGE" == "EN" ]]; then
        message="⚠️ Alert (${CF_ACCOUNT_NAME}): ${event_count} firewall events have been detected in the last 24 hours, exceeding the threshold of ${THRESHOLD}."
        else
        message="⚠️ Alerta (${CF_ACCOUNT_NAME}): Se han detectado ${event_count} eventos de firewall en las últimas 24 horas, lo que supera el umbral de ${THRESHOLD}."
        fi
        send_telegram_message "$message"
        last_alert_time=$current_time
    fi
  fi

  # Wait before the next check.
  sleep "$INTERVAL"
done
