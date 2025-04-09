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

BODY=$(cat <<EOF
<html>
<head>
<title></title>
<style type="text/css">span.preheader{display:none!important;mso-hide:all;}</style>
</head>
<body>
<table align="center" border="0" cellpadding="0" cellspacing="0" style="background-color: #F5F7FA;table-layout: fixed; direction: rtl; font-family: iransans, iranyekan, azarmehr, vazir, vazirmatn, shabnam, system ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Fira Sans' , 'Droid Sans' , 'Helvetica Neue' , sans-serif;" width="600">
<thead>
<tr>
<td align="center"><a href="http://limoo.host/"><img alt="limoo host logo" src="https://limoo.host/email-template/limoo-host-logo.png" style="padding: 40px;" /></a></td>
</tr>
</thead>
<tbody style="background-color: white;">
<tr>
<td style="padding: 40px;">
    با سلام
    <br>
    کاربر گرامی
    <br>
    ارسال ایمیل از سمت سرویس شما با نام کاربری <strong>$USER</strong> در سرور <strong>$HOSTNAME</strong> از محدودیت روزانه عبور کرده است.
    <br>
    با توجه به قوانین تعداد ارسال ایمیل روزانه در هاست‌های اشتراکی، ارسال ایمیل شما تا ۱۲ بامداد محدود خواهد ماند.
    <br>
    در صورت نیاز به ارسال ایمیل بیش از ۳۰۰ عدد در روز پیشنهاد می‌کنیم نسبت به تهیه هاست ایمیل اقدام نمایید.
</td>
</tr>
</tbody>
<tfoot style="background-color: #F5F7FA;">
<tr>
<td style="padding: 0 40px;">
<div style="border-bottom: 1px solid #D2D5DA; padding: 24px 0; text-align: center;">
<p style="font-size: 12px; font-weight: 500; margin:0">حرف‌های زیادی برای گفتن داریم؛ ما را در شبکه‌های اجتماعی دنبال کنید.</p>
<div style="margin-top:16px">
<a href="http://limoo.host/" style="text-decoration: none; margin: 0 10px;"><img alt="limoo host website address" src="https://limoo.host/email-template/domain-icon.png" /></a>
<a href="https://t.me/limoohost" style="text-decoration: none;margin: 0 10px;"><img alt="limoo host instagram address" src="https://limoo.host/email-template/instagram-icon.png" /></a>
<a href="https://www.instagram.com/limoo.host" style="text-decoration: none;margin: 0 10px;"><img alt="limoo host telegram address" src="https://limoo.host/email-template/telegram-icon.png" /></a>
<a href="https://www.twitter.com/limoohost" style="text-decoration: none; margin: 0 10px;"><img alt="twitter limoo host address" src="https://limoo.host/email-template/twitter-icon.png" /></a>
<a href="https://www.youtube.com/@limoohost8320" style="text-decoration: none; margin: 0 10px;"><img alt="twitter limoo host address" src="https://limoo.host/email-template/youtube-icon.png" /></a>
<a href="https://www.linkedin.com/company/limoo-host/" style="text-decoration: none; margin: 0 10px;"><img alt="twitter limoo host address" src="https://limoo.host/email-template/linkedin-icon.png" /></a>
</div>
</div>
</td>
</tr>
</tfoot>
</table>
</body>
</html>
EOF
)
    (
    echo "From: LimooHost <noreply@limoo.host>"
    echo "To: $EMAIL"
    echo "Subject: هشدار محدودیت ارسال ایمیل"
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
