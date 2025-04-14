#!/bin/bash
mails_users_file="/var/log/mail-checker/mails_users.txt"
LOG_FILE="/var/log/mail-checker/script.log"
DEBUG_LOG_FILE="/var/log/mail-checker/smtpdebug.log"
JSON_FILE="/var/log/mail-checker/successful_email_counts.json"
TODAY=$(date +%Y-%m-%d)
EXIM_LOG="/var/log/exim/mainlog"
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
        MATCH_LINE=$(grep "$EMAIL" "$EXIM_LOG" | grep "$TODAY" | grep "F=<$FROM_ADDRESS" | grep 'C="250 OK' | tail -n 1)
        echo "Email for $USER: $EMAIL" | tee -a "$DEBUG_LOG_FILE" 2>&1
    fi
    if [[ -n "$MATCH_LINE" ]]; then
        echo "Found successful email for $EMAIL today." | tee -a "$DEBUG_LOG_FILE" 2>&1
        echo "User already received notification today, skipping." | tee -a "$DEBUG_LOG_FILE" 2>&1
        sync
        exit 1
    fi
    
BODY=$(cat <<EOF
<html>
<head>
<title></title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style type="text/css">
  /* Reset styles */
  body { margin: 0; padding: 0; }
  table { border-collapse: collapse; }
  img { border: 0; outline: none; text-decoration: none; }
  a { text-decoration: none; }
  /* Responsive styles */
  .container {
    max-width: 600px; /* Max width for desktop */
    width: 100%; /* Full width for mobile */
    margin: 0 auto;
    background-color: #F5F7FA;
    font-family: iransans, iranyekan, azarmehr, vazir, vazirmatn, shabnam, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif;
    direction: rtl;
  }
  .header img {
    max-width: 100%;
    height: auto;
    padding: 20px;
  }
  .content {
    background-color: white;
    padding: 20px;
    text-align: right;
  }
  .footer {
    background-color: #F5F7FA;
    padding: 20px;
    text-align: center;
    font-size: 12px;
  }
  .social-icons img {
    width: 24px;
    height: 24px;
    margin: 0 5px;
  }
  .divider {
    border-bottom: 1px solid #D2D5DA;
    padding-bottom: 20px;
    margin-bottom: 20px;
  }
  /* Media query for mobile */
  @media only screen and (max-width: 480px) {
    .content { padding: 15px; }
    .footer { padding: 15px; font-size: 10px; }
    .header img { padding: 10px; }
    .social-icons img { width: 20px; height: 20px; }
  }
</style>
</head>
<body>
<table class="container" cellpadding="0" cellspacing="0">
  <thead>
    <tr>
      <td class="header" align="center">
        <a href="http://limoo.host/">
          <img alt="limoo host logo" src="https://limoo.host/email-template/limoo-host-logo.png">
        </a>
      </td>
    </tr>
    </thead>
    <tbody>
      <tr>
        <td class="content">
          با سلام<br><br>
          کاربر گرامی،<br>
          ارسال ایمیل از سوی سرویس شما با نام کاربری <strong>limoodata</strong>، از سقف مجاز روزانه در سرور <strong>oghab100.limoo.host</strong> فراتر رفته است.<br><br>
          بر اساس قوانین تعداد مجاز ارسال ایمیل روزانه در هاست‌های اشتراکی، محدودیت ارسال ایمیل برای شما تا ساعت ۱۲ امشب فعال شده است.<br><br>
          در صورتی که نیاز به ارسال بیش از ۳۰۰ ایمیل در روز دارید، پیشنهاد می‌کنیم در کنار سرویس اصلی خود، از یک هاست ایمیل اختصاصی استفاده کنید.<br><br>
          با احترام<br>
          تیم پشتیبانی لیموهاست
        </td>
      </tr>
    </tbody>
    <tfoot>
      <tr>
      <td class="footer">
        <div class="divider">
          حرف‌های زیادی برای گفتن داریم؛ ما را در شبکه‌های اجتماعی دنبال کنید。
        </div>
        <div class="social-icons">
          <a href="http://limoo.host/"><img alt="website" src="https://limoo.host/email-template/domain-icon.png"></a>
          <a href="https://t.me/limoohost"><img alt="telegram" src="https://limoo.host/email-template/telegram-icon.png"></a>
          <a href="https://www.instagram.com/limoo.host"><img alt="instagram" src="https://limoo.host/email-template/instagram-icon.png"></a>
          <a href="https://www.twitter.com/limoohost"><img alt="twitter" src="https://limoo.host/email-template/twitter-icon.png"></a>
          <a href="https://www.youtube.com/@limoohost8320"><img alt="youtube" src="https://limoo.host/email-template/youtube-icon.png"></a>
          <a href="https://www.linkedin.com/company/limoo-host/"><img alt="linkedin" src="https://limoo.host/email-template/linkedin-icon.png"></a>
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
