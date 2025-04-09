
```markdown
# Mail Counter Scripts

This project contains a set of scripts to monitor and manage email usage for different hosting control panels, such as cPanel and DirectAdmin. The scripts check email counts and send alerts when limits are exceeded.

## Project Structure

- **`counter_mail.py`**: Python script for counting emails (details not provided in the workspace).
- **`fetch_mail_users.py`**: Python script for fetching mail users (details not provided in the workspace).
- **`cpanel_check_mail_count_NOT_SMTP.sh`**: Script to check email counts for cPanel (non-SMTP).
- **`cpanel_check_mail_count_SMTP.sh`**: Script to check email counts for cPanel (SMTP).
- **`directadmin_check_mail_count_NOT_SMTP.sh`**: Script to check email counts for DirectAdmin (non-SMTP).
- **`directadmin_check_mail_count_SMTP.sh`**: Script to check email counts for DirectAdmin (SMTP).

## Features

- **Email Count Monitoring**: Tracks the number of emails sent by users.
- **Alert System**: Sends email alerts when a user's email count exceeds the defined limit (300 emails).
- **Debug Logging**: Logs debug information to help with troubleshooting.

## Usage

### For cPanel

1. **Non-SMTP Email Count Check**:
   ```bash
   ./cpanel_check_mail_count_NOT_SMTP.sh user@example.com
   ```

2. **SMTP Email Count Check**:
   ```bash
   ./cpanel_check_mail_count_SMTP.sh example.com
   ```

### For DirectAdmin

1. **Non-SMTP Email Count Check**:
   ```bash
   ./directadmin_check_mail_count_NOT_SMTP.sh user@example.com
   ```

2. **SMTP Email Count Check**:
   ```bash
   ./directadmin_check_mail_count_SMTP.sh example.com
   ```

## Configuration

- **Log Files**:
  - `script.log`: General log file for script execution.
  - `notsmtpdebug.log` and `smtpdebug.log`: Debug logs for non-SMTP and SMTP checks.

- **Data Files**:
  - `mails_users.txt`: Contains user-to-email mappings.
  - `successful_email_counts.json`: Stores email count data.

## Exim Configuration

### For cPanel

Add the following ACLs to the appropriate sections in your Exim configuration file:

#### Section: `custom_begin_outgoing_notsmtp_checkall`
```plaintext
custom_begin_outgoing_notsmtp_checkall:
  deny
    condition = ${if and {{!match_domain{$sender_address_domain}{gmail.com}} {eq{${run{/usr/local/bin/check_mail_count_NOT_SMTP.sh $sender_address}{yes}{no}}}{no}}}{yes}{no}}
    message = You have reached your daily email sending limit. Please wait until 12 AM to try again
    log_message = DNS Issue Checker counter (NOT SMTP)
```

#### Section: `custom_begin_outgoing_smtp_checkall`
```plaintext
custom_begin_outgoing_smtp_checkall:
  deny
    condition = ${if and {{!match_domain{$sender_address_domain}{gmail.com}} {eq{${run{/usr/local/bin/check_mail_count_SMTP.sh $sender_address}{yes}{no}}}{no}}}{yes}{no}}
    message = You have reached your daily email sending limit. Please wait until 12 AM to try again
    log_message = DNS Issue Checker counter (SMTP)
```

### For DirectAdmin

Add the following ACLs to the appropriate sections in your Exim configuration file:

#### Section: `acl_script`
```plaintext
acl_script:
  deny
    condition = ${if and {{!match_domain{$sender_address_domain}{gmail.com}} {eq{${run{/usr/local/bin/check_mail_count_NOT_SMTP.sh $sender_address}{yes}{no}}}{no}}}{yes}{no}}
    message = You have reached your daily email sending limit. Please wait until 12 AM to try again
    log_message = DNS Issue Checker counter (NOT SMTP)
```

#### Section: `acl_check_message`
```plaintext
acl_check_message:
  deny
    condition = ${if and {{!match_domain{$sender_address_domain}{gmail.com}} {eq{${run{/usr/local/bin/check_mail_count_SMTP.sh $sender_address}{yes}{no}}}{no}}}{yes}{no}}
    message = You have reached your daily email sending limit. Please wait until 12 AM to try again
    log_message = DNS Issue Checker counter (SMTP)
```

## Requirements

- Bash shell
- `sendmail` utility
- Proper permissions to access log and data files

## License

This project is licensed under the MIT License.
```
```markdown
## Log File Permissions

To ensure proper functionality, the log files should have the following permissions and ownership:

1. **Set Permissions**:
    ```bash
    chmod 666 script.log notsmtpdebug.log smtpdebug.log
    ```

2. **Set Ownership**:
    ```bash
    chown root:mail script.log notsmtpdebug.log smtpdebug.log
    ```

3. **Create Log Files (if not already created)**:
    ```bash
    touch script.log notsmtpdebug.log smtpdebug.log
    chmod 666 script.log notsmtpdebug.log smtpdebug.log
    chown root:mail script.log notsmtpdebug.log smtpdebug.log
    ```

## Script File Permissions

To make the bash scripts executable, set the appropriate permissions:

1. **Set Executable Permissions**:
    ```bash
    chmod +x cpanel_check_mail_count_NOT_SMTP.sh cpanel_check_mail_count_SMTP.sh directadmin_check_mail_count_NOT_SMTP.sh directadmin_check_mail_count_SMTP.sh
    ```
```
