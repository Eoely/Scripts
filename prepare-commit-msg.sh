#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  prepare-commit-msg hook
#  – Prepends “[#ID] ” to the commit message, taking the ID either from
#    1. the branch name (“…-1234…”) or
#    2. an Azure DevOps picker if the branch name has no ticket number.
#    The picker now shows <icon><space><title> instead of "<type> ─ title".
# ---------------------------------------------------------------------------
#
#
# TODO:Find a better way to do the end of cursor, curently in .giconfig-work. Should be confined to this script

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=${2:-}
BRANCH=$(git symbolic-ref --quiet --short HEAD || true)

if [ -n "$COMMIT_SOURCE" ]; then
  exit 0
fi

regex='.*-([0-9]{3,5}).*'
if [[ $BRANCH =~ $regex ]]; then
  ID="${BASH_REMATCH[1]}"
  sed -i "1s/^/[#${ID}] /" "$COMMIT_MSG_FILE"
  exit 0
fi

CONFIG_FILE="$HOME/.azure-devops-env"
QUERY_ID="645a21fa-2c39-4f1b-ab93-b87078e545c2"

for cmd in az jq fzf; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "prepare-commit-msg: '$cmd' not found in \$PATH." >&2; exit 1; }
done

[[ -f $CONFIG_FILE ]] || {
  echo "prepare-commit-msg: config '$CONFIG_FILE' missing." >&2; exit 1; }

# shellcheck source=/dev/null
source "$CONFIG_FILE"
: "${DEVOPS_BASE_URL:?DEVOPS_BASE_URL not set in $CONFIG_FILE}"

# ---------- fetch work items -------------------------------------------------
output=$(az boards query \
           --organization "$DEVOPS_BASE_URL" \
           --id           "$QUERY_ID")

formatted=$(echo "$output" | jq '.[].fields
  | {title: ."System.Title",
     id:    ."System.Id",
     type:  ."System.WorkItemType"}')

[[ -z $formatted ]] && { echo "No work items." >&2; exit 0; }

# ---------- fzf picker -------------------------------------------------------
picked_json=$(printf '%s\n' "$formatted" |
jq -r -c '
  # map “type” → Azure-style emoji
  def icon(t):
       if   t=="Bug"        then "🐞 "
       elif t=="Chore"      then "⚙️ "
       elif t=="Discover"   then "🧪 "
       elif t=="Epic"       then "👑 "
       elif t=="Feature"    then "🏆 "
       elif t=="Release"    then "🔨 "
       elif t=="Task"       then "📋 "
       elif t=="User Story" then "📖 "
       else                      "⚠️ " end;

  # emit: "<icon><title><TAB><full-json>"
  (icon(.type) + .title) + "\t" + (tojson)
' |
fzf --delimiter=$'\t' --with-nth=1 |
cut -f2
)


# The user didn't pick a ticket, commit without any tag
if [[ -z $picked_json ]]; then
  exit 0
fi

ID=$(jq -r '.id' <<<"$picked_json")
sed -i "1s/^/[#${ID}] /" "$COMMIT_MSG_FILE"

