#!/usr/bin/env bash

CONFIG_FILE="$HOME/.azure-devops-env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Required configuration file not found at '$CONFIG_FILE'" >&2
    echo "Please create it or check the path." >&2
    exit 1
fi

# Safe to source now
source "$CONFIG_FILE"
 az boards query --organization https://dev.azure.com/VismaSmartDok  --id 645a21fa-2c39-4f1b-ab93-b87078e545c2
queryId="645a21fa-2c39-4f1b-ab93-b87078e545c2"



output=$(az boards query \
    --organization "$DEVOPS_BASE_URL" \
    --id "$queryId")

formatted="$(echo $output | jq '.[].fields | {title: ."System.Title", id: ."System.Id", type: ."System.WorkItemType", state: ."System.State"}')"

picked=$(
  # 1) stream the JSON lines held in $formatted
  printf '%s\n' "$formatted" |

  # 2) build two TAB-separated fields:
  #    • field-1 = coloured "[Type] ─ Title"  (what the user sees)
  #    • field-2 = untouched JSON            (stays hidden, survives selection)
  jq -r -c '
    def a(n):  "\u001b[" + (n|tostring) + "m";  # make an ANSI colour
    def reset: a(0);
    def tcol(t):                                # type → colour map
         if t=="User Story" then 32             # green
    elif t=="Task"       then 36                # cyan
    elif t=="Feature"    then 33                # yellow
    elif t=="Chore"      then 35                # magenta
    else 37 end;                                # fallback = white
    (a(tcol(.type)) + .type + reset)
    + " ─ " + .title
    + "\t" + (tojson)
  ' |

  # 3) fire up fzf with colours and a JSON preview
  fzf --ansi \
      --delimiter=$'\t' --with-nth=1 \
      --preview='echo {2..} | jq -C' \
      --preview-window=down,60%,border-bottom |

  # 4) strip the pretty column, keep only the raw JSON
  cut -f2
)

# --- do whatever you like with the chosen JSON -----------------------------
printf 'Picked item:\n%s\n' "$picked"
