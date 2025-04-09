#!/bin/bash
mails_users_file="/var/log/mail-checker/mails_users.txt"
LOG_FILE="/var/log/mail-checker/script.log"
DEBUG_LOG_FILE="/var/log/mail-checker/smtpdebug.log"
JSON_FILE="/var/log/mail-checker/successful_email_counts.json"

# Log start immediately
echo "Script started at: $(date)" >> "$DEBUG_LOG_FILE" 2>&1
echo "Running as: $(whoami)" >> "$DEBUG_LOG_FILE" 2>&1
echo "Input: $1" >> "$DEBUG_LOG_FILE" 2>&1
sync  # Force write to disk

# Enable debug output
exec 2>> "$DEBUG_LOG_FILE"
set -x

if [[ -z "$1" ]]; then
    echo "Skipped: No input provided." | tee -a "$DEBUG_LOG_FILE" 2>&1
    sync
    exit 0
fi

DOMAIN="$1"
if [[ "$DOMAIN" == *"@"* ]]; then
    DOMAIN="${DOMAIN#*@}"
fi

USER=""
if [[ -n "$DOMAIN" ]]; then
    USER=$(cat /etc/virtual/domainowners | grep "$DOMAIN" | awk '{print $2}')
fi
USER=$(echo "$USER" | sed 's/^ *//;s/ *$//')
if [[ -z "$USER" ]]; then
    echo "Skipped: No user found for domain $DOMAIN" | tee -a "$DEBUG_LOG_FILE" 2>&1
    sync
    exit 0
fi

EMAIL_COUNT=$(grep -o "\"$USER\": [0-9]*" "$JSON_FILE" | awk -F': ' '{print $2}')
echo "Email count for $USER: $EMAIL_COUNT" | tee -a "$DEBUG_LOG_FILE" 2>&1
sync

if [[ -z "$EMAIL_COUNT" ]]; then
    EMAIL_COUNT=0
fi

if [[ "$EMAIL_COUNT" -ge 300 ]]; then
    EMAIL=$(grep "^$USER:" "$mails_users_file" | cut -d: -f2)
    echo "Debug: EMAIL=$EMAIL" | tee -a "$DEBUG_LOG_FILE" 2>&1

    if [[ -z "$EMAIL" ]]; then
        echo "No email found for user $USER" | tee -a "$DEBUG_LOG_FILE" 2>&1
        sync
        exit 1  # Indicate failure to Exim
    else
        echo "Email for $USER: $EMAIL" | tee -a "$DEBUG_LOG_FILE" 2>&1
    fi

    BODY="email Body"

    (
    echo "From: <noreply@example.com>"
    echo "To: $EMAIL"
    echo "Subject:  Email Limit Exceeded"
    echo "MIME-Version: 1.0"
    echo "Content-Type: text/html; charset=UTF-8"
    echo
    echo "$BODY"
    ) | /sbin/sendmail -t

    echo "Email sent to $EMAIL from LimooHost." | tee -a "$DEBUG_LOG_FILE" 2>&1
    sync
    exit 1  # Signal Exim to deny the email
fi

# Register in log
echo "Execution at: $(date)" >> "$LOG_FILE" 2>&1
echo "Domain: $DOMAIN" >> "$LOG_FILE" 2>&1
echo "User: $USER" >> "$LOG_FILE" 2>&1
echo "Email Count: $EMAIL_COUNT" >> "$LOG_FILE" 2>&1
echo "--------------------------" >> "$LOG_FILE" 2>&1

echo "Log updated successfully." | tee -a "$DEBUG_LOG_FILE" 2>&1
sync
exit 0  # Success, email count below limit
