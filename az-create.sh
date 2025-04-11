#!/usr/bin/env bash

# Create a temporary file and ensure it’s removed on exit
tmpfile=$(mktemp /tmp/edit.XXXXXX)
trap "rm -f '$tmpfile'" EXIT

# Open the file in the user's default editor (or vi if EDITOR not set)
${EDITOR:-vi} "$tmpfile"

# Read the edited content
user_input=$(cat "$tmpfile")

# Split at the first double newline
title="${user_input%%$'\n\n'*}"
description="${user_input#*$'\n\n'}"

# Now you have your title and description:
echo "=== Title ==="
echo "$title"
echo
echo "=== Description ==="
echo "$description"
