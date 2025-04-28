#!/usr/bin/env bash

# Fastest possible: handle branch tag immediately
COMMIT_MSG_FILE=$1
COMMIT_SOURCE=${2:-}
BRANCH=$(git symbolic-ref --quiet --short HEAD || true)

# Only proceed if it's a real commit, not a merge etc.
if [ -n "$COMMIT_SOURCE" ]; then
  exit 0
fi

# Try to find ID directly in branch name: "...-1234..."
if [[ $BRANCH =~ -([0-9]{3,5}) ]]; then
  ID="${BASH_REMATCH[1]}"
  sed -i "1s/^/[#${ID}] /" "$COMMIT_MSG_FILE"
  exit 0
fi

# ---------- Only fetch tickets if no ID found ---------------------------------

CONFIG_FILE="$HOME/.azure-devops-env"
QUERY_ID="645a21fa-2c39-4f1b-ab93-b87078e545c2"
SHOW_PREVIEW=true  # Toggle full preview

# Require tools only now
for cmd in az jq fzf; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "❌ prepare-commit-msg: '$cmd' not found in \$PATH." >&2
    exit 1
  }
done

[[ -f $CONFIG_FILE ]] || {
  echo "❌ prepare-commit-msg: config '$CONFIG_FILE' missing." >&2
  exit 1
}

# shellcheck source=/dev/null
source "$CONFIG_FILE"
: "${DEVOPS_BASE_URL:?DEVOPS_BASE_URL not set in $CONFIG_FILE}"

# ---------- Fetch work items -------------------------------------------------
output=$(az boards query \
           --organization "$DEVOPS_BASE_URL" \
           --id           "$QUERY_ID")

formatted=$(echo "$output" | jq '.[].fields
  | {
     id:    ."System.Id",
     type:  ."System.WorkItemType",
     state: ."System.State",
     assigned: (."System.AssignedTo"."displayName" // "Unassigned"),
     title: ."System.Title"
   }')

[[ -z $formatted ]] && { echo "⚠️  No work items found." >&2; exit 0; }

# ---------- Picker -----------------------------------------------------------
picked_json=$(printf '%s\n' "$formatted" |
jq -r -c '
  def icon(t):
    if   t=="Bug"        then "🐞"
    elif t=="Chore"      then "⚙️"
    elif t=="Discover"   then "🧪"
    elif t=="Epic"       then "👑"
    elif t=="Feature"    then "🏆"
    elif t=="Release"    then "🔨"
    elif t=="Task"       then "📋"
    elif t=="User Story" then "📖"
    else                      "⚠️" end;

  (icon(.type) + " " + .title) + "\t" + (tojson)
' |
{
  if [ "$SHOW_PREVIEW" = true ]; then
    fzf --delimiter=$'\t' --with-nth=1 \
        --preview '
          echo {2} | jq -r "
            \"ID: \(.id)\n\" +
            \"Type: \(.type)\n\" +
            \"State: \(.state)\n\" +
            \"Assigned: \(.assigned)\n\n\" +
            \"Title: \(.title)\"
          " | sed \
            -e "s/^ID:/\x1b[1;36m🆔 ID:\x1b[0m/" \
            -e "s/^Type:/\x1b[1;33m🏷️ Type:\x1b[0m/" \
            -e "s/^State:/\x1b[1;35m📌 State:\x1b[0m/" \
            -e "s/^Assigned:/\x1b[1;32m👤 Assigned:\x1b[0m/" \
            -e "s/^Title:/\x1b[1;37m📋 Title:\x1b[0m/"
        ' \
        --preview-window=right:30%:wrap \
        --height=80% \
        --border=rounded \
        --prompt="🔎 Select a work item > " \
        --pointer="➤" \
        --marker="✓" \
        --color=fg+:bold,marker:green,prompt:magenta
  else
    fzf --delimiter=$'\t' --with-nth=1
  fi
} | cut -f2
)

# ---------- Insert into Commit ------------------------------------------------
if [[ -z $picked_json ]]; then
  # User pressed Escape, or nothing picked: continue normal commit
  exit 0
fi

ID=$(jq -r '.id' <<<"$picked_json")
sed -i "1s/^/[#${ID}] /" "$COMMIT_MSG_FILE"

