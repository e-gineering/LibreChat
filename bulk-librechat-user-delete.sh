#!/bin/bash

# bulk-librechat-user-delete.sh
# This script reads emails from a file and deletes those users from LibreChat

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path-to-email-file.txt>"
  echo "File should contain one email per line"
  exit 1
fi

EMAIL_FILE=$1

if [ ! -f "$EMAIL_FILE" ]; then
  echo "Error: File $EMAIL_FILE does not exist."
  exit 1
fi

# Check if LIBRECHAT_DIR is set, otherwise use current directory
if [ -z "$LIBRECHAT_DIR" ]; then
  LIBRECHAT_DIR="$(pwd)"
  echo "LIBRECHAT_DIR not set, using current directory: $LIBRECHAT_DIR"
fi

echo "Deleting users from $EMAIL_FILE..."

# Counters for summary
total=0
success=0
fail=0

# Get the total number of lines in the file
total_lines=$(wc -l <"$EMAIL_FILE")

# Process each line in the file by line number
for line_number in $(seq 1 $total_lines); do
  # Get the line at the current line number
  email=$(sed -n "${line_number}p" "$EMAIL_FILE")

  # Skip empty lines or comments
  if [[ -z "$email" || "$email" == \#* ]]; then
    continue
  fi

  # Skip header line
  if [[ "$email" == "email" ]]; then
    continue
  fi

  # Trim whitespace
  email=$(echo "$email" | xargs)

  total=$((total + 1))
  echo "Deleting user with email: $email"

  # Use 'yes' command to provide continuous 'y' input to the script
  # The 'y' will be provided whenever the script asks for confirmation
  yes y | docker compose -f "$LIBRECHAT_DIR/docker-compose.yml" exec -T api node config/delete-user.js "$email"
  status=$?

  # Check if the command was successful
  if [ $status -eq 0 ]; then
    echo "User with email $email deleted successfully"
    success=$((success + 1))
  else
    echo "Failed to delete user with email $email"
    fail=$((fail + 1))
  fi

  echo "-----------------------------------"

done

echo "Done! Deleted: $success, Failed: $fail (Total: $total)"
