#!/usr/bin/env bash

CONFIG_FILE="~/.azure-devops-env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Required configuration file not found at '$CONFIG_FILE'" >&2
    echo "Please create it or check the path." >&2
    exit 1
fi

# Safe to source now
source "$CONFIG_FILE"
source 


valid_types=("epic", "feature", "user story", "task", "bug", "chore", "discover")

#Make cli argument lowercase to match with valid types
itemType="${1,,}"

if ! [[ ${valid_types[*]} =~ "$itemType" ]]; then 
	echo "Not a valid work item"
	exit 1 
fi

# Create a temporary file and ensure it’s removed on exit
tmpfile=$(mktemp /tmp/edit.XXXXXX)
trap "rm -f '$tmpfile'" EXIT

# Open the file in the user's default editor (or vi if EDITOR not set)
${EDITOR:-vim} "$tmpfile"

# Read the edited content
user_input="$(tr -d '\r' < "$tmpfile")"

if [[ "$user_input" = "" ]]; then
	echo "No user input, exiting"
	exit 1
fi

# Split at the first double newline
# TODO: What happens if you have double newline in "description"? Is it all there?
title="${user_input%%$'\n\n'*}"
description="${user_input#*$'\n\n'}"

output=$(az boards work-item create \
    --title "$title" \
    --description "$description" \
    --type "$itemType" \
    --assigned-to "$DEVOPS_USER_NAME" \
    --area "$DEVOPS_TEAM_AREA_PATH" \
    --organization "$DEVOPS_BASE_URL" \
    --project "$DEVOPS_PROJECT" \
    --open)
    
echo "$output"
