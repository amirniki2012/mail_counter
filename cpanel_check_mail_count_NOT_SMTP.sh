#!/bin/bash
mails_users_file="/var/log/mail-checker/mails_users.txt"
LOG_FILE="/var/log/mail-checker/script.log"
DEBUG_LOG_FILE="/var/log/mail-checker/notsmtpdebug.log"
JSON_FILE="/var/log/mail-checker/successful_email_counts.json"

# Redirect the output of 'set -x' to a separate debug log file
exec 3>&1 1>>"$DEBUG_LOG_FILE" 2>&1

set -x
if [[ -z "$1" ]]; then
    echo "Skipped: No input provided."
    exit 0
fi

EMAIL="$1"
USER="${EMAIL%@*}"
DOMAIN="${EMAIL#*@}"

if [[ -z "$USER" ]]; then
    echo "Skipped: No user extracted from email $EMAIL"
    exit 0
fi

EMAIL_COUNT=$(grep -o "\"$USER\": [0-9]*" "$JSON_FILE" | awk -F': ' '{print $2}')

if [[ "$EMAIL_COUNT" -ge 300 ]]; then
    USER_EMAIL=$(grep "^$USER:" "$mails_users_file" | cut -d: -f2)
    if [[ -z "$USER_EMAIL" ]]; then
        echo "No email found for user $USER"
        exit 0
    fi

    BODY="email Body"

(
echo "From: LimooHost <noreply@example.com>"
echo "To: $USER_EMAIL"
echo "Subject: هشدار محدودیت ارسال ایمیل"
echo "MIME-Version: 1.0"
echo "Content-Type: text/html; charset=UTF-8"
echo
echo "$BODY"
) | sendmail -t

    echo "Email sent to $EMAIL from LimooHost."
    exit 1

fi

echo "Execution at: $(date)" >> "$LOG_FILE"
echo "Email: $EMAIL" >> "$LOG_FILE"
echo "User: $USER" >> "$LOG_FILE"
echo "Email Count: $EMAIL_COUNT" >> "$LOG_FILE"
echo "--------------------------" >> "$LOG_FILE"

echo "Log updated successfully."
set +x
exec 1>&3 2>&1  # Restore the standard output and error
