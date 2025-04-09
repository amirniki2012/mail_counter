#!/bin/bash
mails_users_file="/var/log/mail-checker/mails_users.txt"
LOG_FILE="/var/log/mail-checker/script.log"
DEBUG_LOG="/var/log/mail-checker/smtpdebug.log"
JSON_FILE="/var/log/mail-checker/successful_email_counts.json"

# Redirect set -x output to debug_log.txt
exec 2>>"$DEBUG_LOG"
set -x  # Enable debug mode, output will go to debug_log.txt

if [[ -z "$1" ]]; then
    echo "Skipped: No input provided."
    exit 0
fi

DOMAIN="$1"
if [[ "$DOMAIN" == *"@"* ]]; then
    DOMAIN="${DOMAIN#*@}"
fi

USER=""
if [[ -n "$DOMAIN" ]]; then
    USER=$(awk -F'[:=]' -v domain="$DOMAIN" '$1 == domain {print $2}' /etc/userdatadomains)
fi
USER=$(echo "$USER" | sed 's/^ *//;s/ *$//')
if [[ -z "$USER" ]]; then
    echo "Skipped: No user found for domain $DOMAIN"
    exit 0
fi

EMAIL_COUNT=$(grep -o "\"$USER\": [0-9]*" "$JSON_FILE" | awk -F': ' '{print $2}')

#echo "Debug: EMAIL_COUNT=$EMAIL_COUNT"
if [[ "$EMAIL_COUNT" -ge 300 ]]; then
     EMAIL=$(grep "^$USER:" "$mails_users_file" | cut -d: -f2)
     echo "Debug: EMAIL=$EMAIL"

if [[ -z "$EMAIL" ]]; then
    echo "No email found for user $USER"
else
    echo "Email for $USER: $EMAIL"
fi
    BODY="email Body"


(
echo "From: LimooHost <noreply@example.com>"
echo "To: $EMAIL"
echo "Subject: هشدار محدودیت ارسال ایمیل"
echo "MIME-Version: 1.0"
echo "Content-Type: text/html; charset=UTF-8"
echo
echo "$BODY"
) | sendmail -t

    echo "Email sent to $EMAIL from LimooHost."
    exit 1
fi

# Log to the original log file
echo "Execution at: $(date)" >> "$LOG_FILE"
echo "Domain: $DOMAIN" >> "$LOG_FILE"
echo "User: $USER" >> "$LOG_FILE"
echo "Email Count: $EMAIL_COUNT" >> "$LOG_FILE"
echo "--------------------------" >> "$LOG_FILE"

echo "Log updated successfully."
set +x  # Disable debug mode
