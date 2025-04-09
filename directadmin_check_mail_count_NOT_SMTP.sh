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
echo "To: $USER_EMAIL"
echo "Subject: هشدار محدودیت ارسال ایمیل"
echo "MIME-Version: 1.0"
echo "Content-Type: text/html; charset=UTF-8"
echo
echo "$BODY"
) | /sbin/sendmail -t

    echo "Email sent to $USER_EMAIL from LimooHost."
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
