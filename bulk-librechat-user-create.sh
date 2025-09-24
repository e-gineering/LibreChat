#!/bin/bash

# bulk-librechat-user-create.sh
# This script reads user information from a CSV file and creates users in LibreChat

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path-to-user-file.csv>"
  echo "CSV format: email,name,username,password,email_verified"
  echo "Note: passwords must be at least 8 characters"
  exit 1
fi

USER_FILE=$1

if [ ! -f "$USER_FILE" ]; then
  echo "Error: File $USER_FILE does not exist."
  exit 1
fi

# Check if LIBRECHAT_DIR is set, otherwise use current directory
if [ -z "$LIBRECHAT_DIR" ]; then
  LIBRECHAT_DIR="$(pwd)"
  echo "LIBRECHAT_DIR not set, using current directory: $LIBRECHAT_DIR"
fi

echo "Creating users from $USER_FILE..."

# Counters for summary
total=0
success=0
skip=0
fail=0

# Get the total number of lines in the file
total_lines=$(wc -l <"$USER_FILE")

# Process each line in the file by line number
for line_number in $(seq 1 $total_lines); do
  # Get the line at the current line number
  line=$(sed -n "${line_number}p" "$USER_FILE")

  # Skip empty lines or comments
  if [[ -z "$line" || "$line" == \#* ]]; then
    continue
  fi

  # Skip header line
  if [[ $line_number -eq 1 && ("$line" == *email* || "$line" == *username*) ]]; then
    continue
  fi

  total=$((total + 1))

  # Parse the CSV line
  email=$(echo "$line" | cut -d, -f1)
  name=$(echo "$line" | cut -d, -f2)
  username=$(echo "$line" | cut -d, -f3)
  password=$(echo "$line" | cut -d, -f4)
  email_verified=$(echo "$line" | cut -d, -f5)

  # Trim whitespace
  email=$(echo "$email" | xargs)
  name=$(echo "$name" | xargs)
  username=$(echo "$username" | xargs)
  password=$(echo "$password" | xargs)
  email_verified=$(echo "$email_verified" | xargs)

  # Check password length
  if [ ${#password} -lt 8 ]; then
    echo "User $username: Password too short (must be 8+ characters) - skipping"
    fail=$((fail + 1))
    continue
  fi

  # Set default for email_verified if not provided
  if [ -z "$email_verified" ]; then
    email_verified_arg="--email-verified=true"
  else
    email_verified_arg="--email-verified=$email_verified"
  fi

  echo "Creating user: $email ($username)"

  # Run the create-user script using docker-compose exec
  output=$(docker compose -f "$LIBRECHAT_DIR/docker-compose.yml" exec -T api node config/create-user.js "$email" "$name" "$username" "$password" $email_verified_arg 2>&1)
  status=$?

  # Check if the user already exists
  if echo "$output" | grep -q "A user with that email or username already exists"; then
    echo "User $username already exists - skipping"
    skip=$((skip + 1))
  # Check if the command was successful
  elif [ $status -eq 0 ]; then
    echo "User $username created successfully"
    success=$((success + 1))
  else
    echo "Failed to create user $username"
    echo "Error: $(echo "$output" | grep -i "error" || echo "$output" | tail -1)"
    fail=$((fail + 1))
  fi

done

echo "Done! Created: $success, Skipped: $skip, Failed: $fail (Total: $total)"
