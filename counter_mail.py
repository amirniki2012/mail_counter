import json
import logging
import os
import time
import re
from threading import Thread, Lock
import sys
import signal

# Set up logging
# logging.basicConfig(filename='/var/log/mail-checker/script_log.txt', level=logging.INFO,
#                     format='%(asctime)s - %(levelname)s - %(message)s')

default_log_path = "/var/log/exim_mainlog"
alternative_log_path = "/var/log/exim/mainlog"
temp_file = "/var/log/mail-checker/temp_log.txt"
counts_file = "/var/log/mail-checker/successful_email_counts.json"
domainowners_file = "/etc/virtual/domainowners"

if os.path.exists("/usr/local/cpanel"):
    log_path = default_log_path
    use_cpanel_regex = True
else:
    log_path = alternative_log_path
    use_cpanel_regex = False

if use_cpanel_regex:
    sender_pattern = re.compile(
        r'(?P<datetime>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+(?P<msgid>\S+)\s+'
        r'(?:Sender identification U=(?P<user1>\w+).*? S=(?P<sender1>\S+)|'
        r'<=\s*(?P<sender2>\S+)\s+U=(?P<user2>\w+))'
    )
    status_pattern = re.compile(
        r'(?P<msgid>\S+) (?:=>|->) .*? C="(?P<status>250 OK|SMTP error from remote mail server.*?)"'
    )
else:
    success_pattern = re.compile(
        r'F=<([^@]+)@([^>]+)>(.*?C="(?P<status1>250 OK.*|SMTP error from remote mail server.*?)")?(?(status1)|.*?(?P<status2>SMTP error from remote mail server.*?))'
    )
    temp_success_pattern = re.compile(
        r'Sender: ([^@]+)@([^|]+) \| Status: (250 OK.*|SMTP error from remote mail server.*)'
    )

user_success_counts = {}
counts_lock = Lock()
running = True

def load_domainowners():
    domain_to_user = {}
    if os.path.exists(domainowners_file):
        with open(domainowners_file, "r") as f:
            for line in f:
                try:
                    domain, user = line.strip().split(": ")
                    domain_to_user[domain] = user
                    logging.info(f"Loaded domain: {domain} -> user: {user}")
                except ValueError:
                    logging.error(f"Invalid line in domainowners: {line.strip()}")
    else:
        logging.error(f"Domainowners file not found: {domainowners_file}")
    return domain_to_user

def load_counts():
    global user_success_counts
    if os.path.exists(counts_file):
        with open(counts_file, "r") as f:
            try:
                user_success_counts = json.load(f)
                logging.info(f"Loaded counts: {user_success_counts}")
            except json.JSONDecodeError:
                user_success_counts = {}
                logging.warning("Counts file was empty or invalid, starting fresh.")

def save_counts():
    with counts_lock:
        logging.info(f"Saving counts: {user_success_counts}")
        with open(counts_file, "w") as f:
            json.dump(user_success_counts, f, indent=4)

def process_temp_file():
    user_pattern = re.compile(r"User: (\w+)")
    domain_to_user = load_domainowners() if not use_cpanel_regex else {}

    while running:
        try:
            with open(temp_file, "r") as temp_log:
                lines = temp_log.readlines()
                logging.info(f"Read {len(lines)} lines from temp_file: {lines}")
        except FileNotFoundError:
            lines = []
            logging.warning("temp_file not found, skipping...")

        if not lines:
            time.sleep(1)
            continue

        new_lines = []
        for line in lines:
            logging.debug(f"Processing line: {line.strip()}")
            if use_cpanel_regex:
                user_match = user_pattern.search(line)
                if user_match:
                    user = user_match.group(1)
                    with counts_lock:
                        user_success_counts[user] = user_success_counts.get(user, 0) + 1
                        logging.info(f"Incremented count for user: {user}")
                else:
                    new_lines.append(line)
            else:
                temp_match = temp_success_pattern.search(line)
                if temp_match:
                    domain = temp_match.group(2).strip()
                    user = domain_to_user.get(domain, "unknown")
                    logging.info(f"Found domain: {domain}, mapped to user: {user}")
                    with counts_lock:
                        user_success_counts[user] = user_success_counts.get(user, 0) + 1
                        logging.info(f"Incremented count for user: {user}")
                else:
                    new_lines.append(line)
                    logging.debug(f"Line did not match temp_success_pattern: {line.strip()}")

        save_counts()

        with open(temp_file, "w") as temp_log:
            temp_log.writelines(new_lines)
            logging.info(f"Wrote {len(new_lines)} lines back to temp_file")

        print("\nSuccessful email sends:")
        with counts_lock:
            if user_success_counts:
                for user, count in user_success_counts.items():
                    print(f"User: {user}, Successful emails sent: {count}")
            else:
                print("No successful sends recorded yet.")
        time.sleep(1)

def tail_f(file_path):
    with open(file_path, 'r', encoding='latin1', errors='ignore') as log_file, open(temp_file, 'a', buffering=1) as temp_log:
        log_file.seek(0, 2)
        message_status = {}
        processed_msgids = set()

        while running:
            line = log_file.readline()
            if not line:
                time.sleep(0.3)
                continue

            if 'SpamAssassin' in line or 'Warning: "SpamAssassin' in line:
                continue

            if use_cpanel_regex:
                sender_match = sender_pattern.search(line)
                if sender_match:
                    data = sender_match.groupdict()
                    msgid = data["msgid"]

                    if msgid not in processed_msgids:
                        processed_msgids.add(msgid)
                        log_entry = f"{data['datetime']} | Message ID: {msgid} | "

                        if data.get("user1"):
                            log_entry += f"User: {data['user1']} | Sender: {data['sender1']}"
                        else:
                            log_entry += f"User: {data['user2']} | Sender: {data['sender2']}"

                        if msgid in message_status:
                            log_entry += f" | Status: {message_status.pop(msgid)}"

                        log_entry += "\n"
                        print(log_entry, end="")
                        temp_log.write(log_entry)

                status_match = status_pattern.search(line)
                if status_match:
                    msgid = status_match.group("msgid")
                    status = status_match.group("status")

                    if msgid not in processed_msgids:
                        processed_msgids.add(msgid)
                        log_entry = f"{message_status.get(msgid, 'Unknown Status')} | Status: {status}\n"
                        print(log_entry, end="")
                        temp_log.write(log_entry)
                    else:
                        message_status[msgid] = status
            else:
                success_match = success_pattern.search(line)
                if success_match:
                    sender = success_match.group(1) + "@" + success_match.group(2)
                    status = success_match.group("status1") if success_match.group("status1") else success_match.group("status2")
                    log_entry = f"Sender: {sender} | Status: {status}\n"
                    print(log_entry, end="")
                    temp_log.write(log_entry)
                    logging.info(f"Wrote to temp_file: {log_entry.strip()}")

            time.sleep(0.3)

def signal_handler(sig, frame):
    global running
    print("\n❌ Stopping monitoring...")
    running = False
    time.sleep(1)
    save_counts()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

if __name__ == "__main__":
    open(temp_file, "w").close()
    load_counts()

    writer_thread = Thread(target=tail_f, args=(log_path,), daemon=True)
    processor_thread = Thread(target=process_temp_file, daemon=True)

    writer_thread.start()
    processor_thread.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        signal_handler(None, None)
