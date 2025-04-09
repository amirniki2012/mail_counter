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

    SUBJECT="هشدار محدودیت ارسال ایمیل"
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
        با سلام<br>
        کاربر گرامی<br>
        ارسال ایمیل از سمت سرویس شما با نام کاربری <strong>$USER</strong> در سرور <strong>$HOSTNAME</strong> از محدودیت روزانه عبور کرده است.<br>
        با توجه به قوانین تعداد ارسال ایمیل روزانه در هاست‌های اشتراکی، ارسال ایمیل شما تا ۱۲ بامداد محدود خواهد ماند.<br>
        در صورت نیاز به ارسال ایمیل بیش از ۳۰۰ عدد در روز پیشنهاد می‌کنیم نسبت به تهیه هاست ایمیل اقدام نمایید。
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
