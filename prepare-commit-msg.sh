#!/usr/bin/env bash
###############################################################################
#  Azure DevOps work-item picker
#  –
#  – Reads $DEVOPS_BASE_URL from  ~/.azure-devops-env        (unchanged)
#  – Runs your saved WIQL query                              (unchanged)
#  – Transforms the result with the very same jq you wrote   (unchanged)
#  – Colours Type + Title in fzf and prints the raw JSON
#
#  Requires: az (with devops ext), jq ≥1.6, fzf ≥0.35
###############################################################################
set -euo pipefail

CONFIG_FILE="$HOME/.azure-devops-env"
QUERY_ID="645a21fa-2c39-4f1b-ab93-b87078e545c2"

# ─── sanity checks ───────────────────────────────────────────────────────────
for cmd in az jq fzf; do
  command -v "$cmd" >/dev/null 2>&1 \
    || { echo "Error: '$cmd' not found in \$PATH" >&2; exit 1; }
done

[[ -f $CONFIG_FILE ]] \
  || { echo "Error: config file '$CONFIG_FILE' not found." >&2; exit 1; }

# shellcheck source=/dev/null
source "$CONFIG_FILE"          # must export DEVOPS_BASE_URL
: "${DEVOPS_BASE_URL:?DEVOPS_BASE_URL not set in $CONFIG_FILE}"

# ─── run WIQL query (UNCHANGED) ──────────────────────────────────────────────
output=$(az boards query \
           --organization "$DEVOPS_BASE_URL" \
           --id           "$QUERY_ID")

# ─── field subset with YOUR jq filter (UNCHANGED) ────────────────────────────
formatted="$(echo "$output" | jq '.[].fields
      | {title: ."System.Title",
         id:    ."System.Id",
         type:  ."System.WorkItemType",
         state: ."System.State"}')"

[[ -z $formatted ]] && { echo "No work items returned." >&2; exit 0; }

# ─── colourful fzf menu (identical colouring logic) ──────────────────────────
# Potential additional fzf options:
#--height=90% --border \
#--preview='echo {2} | jq -C' \
#--preview-window=down,20%,border-bottom |

picked=$(
  printf '%s\n' "$formatted" |
  jq -r -c '
    def a(n):  "\u001b[" + (n|tostring) + "m";
    def reset: a(0);
    def tcol(t):
         if t=="User Story" then 32      # green
    elif t=="Task"       then 36         # cyan
    elif t=="Feature"    then 33         # yellow
    elif t=="Chore"      then 35         # magenta
    else 37 end;                         # fallback white
    (a(tcol(.type)) + .type + reset) + " ─ " + .title
    + "\t" + (tojson)
  ' |
  fzf --ansi \
      --delimiter=$'\t' --with-nth=1 |
  cut -f2
)

[[ -z $picked ]] && { echo "No item selected." >&2; exit 1; }

printf '%s\n' "$picked"

