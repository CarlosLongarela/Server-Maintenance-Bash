#!/bin/bash

# Default values.
THRESHOLD=80           # Threshold for CPU usage in percentage.
DURATION_THRESHOLD=300 # Duration  in seconds to exceed the threshold before alerting (5 minutes).
INTERVAL=10            # Interval in seconds for checking CPU usage.
LANGUAGE="EN"          # Language for alerts: EN (English) or ES (Spanish).

# include file with Telegram variables
source TELEGRAM_CONFIG

# Function to show help message in English.
show_help_en() {
    echo "Usage: $0 [-t <CPU usage threshold in percentage>] [-d <duration in seconds>] [-i <check interval in seconds>] [-l <language>] [-h] [-a]"
    echo ""
    echo "Parameters:"
    echo "  -t <threshold>      CPU usage threshold in percentage (default: 80)"
    echo "  -d <duration>       Duration in seconds above the threshold before triggering an alert (default: 300 seconds)"
    echo "  -i <interval>       Check interval in seconds (default: 10 seconds)"
    echo "  -l <language>       Alert language: EN (English) or ES (Spanish) (default: EN)"
    echo "  -h                  Show this help message in English"
    echo "  -a                  Show this help message in Spanish"
    exit 0
}

# Function to show help message in Spanish.
show_help_es() {
    echo "Uso: $0 [-t <umbral de uso de CPU en porcentaje>] [-d <duración en segundos>] [-i <intervalo de comprobación en segundos>] [-l <idioma>] [-h] [-a]"
    echo ""
    echo "Parámetros:"
    echo "  -t <umbral>         Umbral de uso de CPU en porcentaje (por defecto: 80)"
    echo "  -d <duración>       Duración en segundos por encima del umbral antes de activar una alerta (por defecto: 300 segundos)"
    echo "  -i <intervalo>      Intervalo de comprobación en segundos (por defecto: 10 segundos)"
    echo "  -l <idioma>         Idioma de las alertas: EN (Inglés) or ES (Español) (por defecto: EN)"
    echo "  -h                  Mostrar este mensaje de ayuda en inglés"
    echo "  -a                  Mostrar este mensaje de ayuda en español"
    exit 0
}

# Obtain the options we passed to the script.
while getopts "t:d:i:l:h:a" opt; do
    case "$opt" in
        t) THRESHOLD=$OPTARG ;;
        d) DURATION_THRESHOLD=$OPTARG ;;
        i) INTERVAL=$OPTARG ;;
        l) LANGUAGE=$OPTARG ;;
        h) show_help_en ;;
        a) show_help_es ;;
        *) show_help_en ;;
    esac
done

# Language validation.
if [[ "$LANGUAGE" != "EN" && "$LANGUAGE" != "ES" ]]; then
    echo "Language not supported: $LANGUAGE"
    show_help_en
fi

# Internal variables.
above_threshold_time=0
SERVER_NAME=$(hostname) # Obtains the server name.

# Function to send a message to Telegram.
send_telegram_message() {
  local message=$1
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="${message}" > /dev/null
}

# Function to generate the message based on the language.
generate_message() {
    local cpu_usage=$1
    if [ "$LANGUAGE" == "EN" ]; then
        echo "⚠️ Attention! CPU usage has been at ${cpu_usage}% for more than $DURATION_THRESHOLD seconds on server: $SERVER_NAME."
    else
        echo "⚠️ Atención ! El uso de la CPU ha estado al ${cpu_usage}% durante más de $DURATION_THRESHOLD segundos en el servidor: $SERVER_NAME."
    fi
}

# Infinite loop to monitor the CPU.
while true; do
    # Obtains the CPU usage using `top`.
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')  # Sums the use of the CPU in user + system.
    cpu_usage=${cpu_usage%.*}  # Deletes the decimals, if necessary.

    # Check if the CPU usage exceeds the threshold.
    if [ "$cpu_usage" -gt "$THRESHOLD" ]; then
        # Increment the time the CPU is above the threshold.
        above_threshold_time=$((above_threshold_time + INTERVAL))

        # If the CPU has been above the threshold for more than DURATION_THRESHOLD seconds, send an alert.
        if [ "$above_threshold_time" -ge "$DURATION_THRESHOLD" ]; then
            # Generate the message based on the language.
            message=$(generate_message "$cpu_usage")
            send_telegram_message "$message"
            above_threshold_time=0  # Reset the counter to avoid sending multiple alerts.
        fi
    else
        # If the CPU usage falls below the threshold, reset the counter.
        above_threshold_time=0
    fi

    # Wait before the next check.
    sleep $INTERVAL
done
