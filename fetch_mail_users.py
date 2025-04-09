import os
import subprocess
import json
import logging

# Configure logging format and level
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

# File path to store fetched user emails
mails_users_file = "/var/log/mail-checker/mails_users.txt"

def fetch_directadmin_emails():
    """
    Fetch emails from DirectAdmin user.conf files located in the user's directory.
    The email is extracted from each user's user.conf file.
    """
    logging.info("Detected DirectAdmin. Fetching user emails.")
    
    # Directory where user configs are located in DirectAdmin
    user_dir = "/usr/local/directadmin/data/users"
    
    # Open the output file to write the user-email pairs
    with open(mails_users_file, "w") as f:
        for user in os.listdir(user_dir):
            user_path = os.path.join(user_dir, user)
            if os.path.isdir(user_path):  # Check if it's a directory (user directory)
                conf_file = os.path.join(user_path, "user.conf")  # Path to the user.conf file
                if os.path.isfile(conf_file):  # If the config file exists
                    with open(conf_file, "r") as conf:
                        email = "unknown"  # Default email if not found in the config file
                        # Loop through each line of the user.conf to find email
                        for line in conf:
                            if line.startswith("email="):  # Check if the line starts with email=
                                email = line.split("=", 1)[1].strip()  # Extract email
                                break
                    # Write user:email pair to the file
                    f.write(f"{user}:{email}\n")
    logging.info(f"DirectAdmin emails saved to {mails_users_file}")

def fetch_cpanel_emails():
    """
    Fetch emails from cPanel using the WHM API to list accounts and their emails.
    """
    logging.info("Detected cPanel. Fetching user emails via WHM API.")
    try:
        # Run the WHM API command to list all accounts
        result = subprocess.run(
            "whmapi1 --output=jsonpretty listaccts",
            shell=True, check=True, capture_output=True, text=True
        )
        
        # Parse the JSON output from WHM API response
        data = json.loads(result.stdout)

        # Check if 'data' and 'acct' exist in the response
        if 'data' in data and 'acct' in data['data']:
            # Delete old email file if it exists
            if os.path.exists(mails_users_file):
                os.remove(mails_users_file)  # Remove the old file
                logging.info(f"Deleted old file: {mails_users_file}")
            
            # Write username:email pairs to the file
            with open(mails_users_file, "w") as f:
                for account in data['data']['acct']:  # Loop through each account
                    username = account.get('user', 'unknown')  # Get the username
                    email = account.get('email', 'unknown')  # Get the email
                    f.write(f"{username}:{email}\n")
            logging.info(f"cPanel emails saved to {mails_users_file}")
        else:
            logging.warning("No accounts found in WHM API response.")
    except subprocess.CalledProcessError as e:
        # Handle subprocess errors (e.g., API call failures)
        logging.error(f"Failed to fetch cPanel accounts: {e.stderr}")
    except json.JSONDecodeError as e:
        # Handle errors while parsing the JSON response
        logging.error(f"Failed to parse WHM API response: {e}")

def fetch_user_emails():
    """
    Detect the control panel (DirectAdmin or cPanel) and fetch user emails accordingly.
    """
    # Check if DirectAdmin is installed
    if os.path.exists("/usr/local/directadmin"):
        fetch_directadmin_emails()  # Fetch emails from DirectAdmin
    else:
        logging.info("No DirectAdmin detected, assuming cPanel.")  # Assume cPanel if DirectAdmin is not found
        fetch_cpanel_emails()  # Fetch emails from cPanel

# Main execution
if __name__ == "__main__":
    fetch_user_emails()  # Call the function to start fetching emails based on the detected control panel
