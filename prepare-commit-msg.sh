#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  prepare-commit-msg hook
#  – Prepends "[#ID] " to the message, where ID comes from:
#      1. the branch name 
#      2. an Azure DevOps fzf picker (if "invalid" branch name)
# ---------------------------------------------------------------------------
set -euo pipefail

# Try reading ticket number from branch name, and capture it
# "-" + 3-5 digits anywhere in the branch name
COMMIT_MSG_FILE=$1
BRANCH=$(git symbolic-ref --quiet --short HEAD || true)

regex=".*-([0-9]{3,5}).*"
if [[ $BRANCH =~ $regex ]]; then
  ID="${BASH_REMATCH[1]}"
  sed -i "1s/^/[#${ID}] /" "$COMMIT_MSG_FILE"
  exit 0
fi

# Fetch tickets from azure devops, selectable with fzf
CONFIG_FILE="$HOME/.azure-devops-env"
QUERY_ID="645a21fa-2c39-4f1b-ab93-b87078e545c2"

# Validate dependencies
for cmd in az jq fzf; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "prepare-commit-msg: '$cmd' not found in \$PATH." >&2; exit 1; }
done

[[ -f $CONFIG_FILE ]] || {
  echo "prepare-commit-msg: config '$CONFIG_FILE' missing." >&2; exit 1; }

# shellcheck source=/dev/null
source "$CONFIG_FILE"          # must export $DEVOPS_BASE_URL
: "${DEVOPS_BASE_URL:?DEVOPS_BASE_URL not set in $CONFIG_FILE}"

# ── run WIQL query – UNCHANGED from your script ───────────────────────
output=$(az boards query \
           --organization "$DEVOPS_BASE_URL" \
           --id           "$QUERY_ID")

formatted="$(echo "$output" | jq '.[].fields
  | {title: ."System.Title",
     id:    ."System.Id",
     type:  ."System.WorkItemType",
     state: ."System.State"}')"

[[ -z $formatted ]] && { echo "No work items." >&2; exit 0; }

# Colorful fzf menu ────────────────────
picked_json=$(
  printf '%s\n' "$formatted" |
  jq -r -c '
    def a(n):  "\u001b[" + (n|tostring) + "m";
    def reset: a(0);
    def tcol(t):
         if t=="User Story" then 32
    elif t=="Task"       then 36
    elif t=="Feature"    then 33
    elif t=="Chore"      then 35
    else 37 end;
    (a(tcol(.type)) + .type + reset) + " ─ " + .title
    + "\t" + (tojson)
  ' |
  fzf --ansi                       \
      --delimiter=$'\t' --with-nth=1 |
  cut -f2
)

# Abort if nothing chosen (Esc / Ctrl-C)
[[ -z $picked_json ]] && { echo "Commit aborted." >&2; exit 1; }

ID=$(jq -r '.id' <<<"$picked_json")

sed -i "1s/^/[#${ID}] /" "$COMMIT_MSG_FILE"

