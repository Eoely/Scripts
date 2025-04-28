#!/usr/bin/env bash
# Requirements: ngrok + config, yq, jq, sed, fzf

#TODO:
#General code cleanup, especially encoding logic
#Document center urls are not set?
#Would be a bit cool if it could close all other instances of testing.smartdok.dev

CONFIG_FILE="$HOME/ngrok.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Required configuration file not found at '$CONFIG_FILE'" >&2
    echo "Please create it or check the path." >&2
    exit 1
fi

baseUrl="https://testing.smartdok.dev/Loader?next=%2FStart.aspx&overlay-url=https%3A%2F%2Fportal.smartdok.dev%2Foverlay.js"
baseUrl="https://testing.smartdok.dev/Loader?next=%2FStart.aspx&overlay-url=https%3A%2F%2Fportal.smartdok.dev%2Foverlay.js"
branch="master" # Default, changed programatically
frontEndUrl="https://smartdokui.z16.web.core.windows.net/$branch/"

data="$(curl -sS https://portal.smartdok.dev/environments.json)"
portalBranches="$(echo $data | jq -r '.[] | .name' | tr -d '\r')"

#Resolve flags:
# -b (branch): Pass in named branch which you will open. E.g "sd-open -b feature-live-feed"
# -s (search): Select among branches available
while getopts ":b:s" opt; do
    case $opt in
    b)
        # Return error message if branch does not exist
        if [[ ! $portalBranches =~ $OPTARG ]]; then
            echo "Error: Branch $OPTARG does not exist" >&2
            echo "Valid branches: $portalBranches" >&2
            exit 1
        fi
        branch=$OPTARG
        ;;
    s)
        branch="$(echo -e $portalBranches | sed 's# #\n#g' | fzf)"
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done

branchData="$(echo $data | jq --arg branch $branch '.[] | select(.name == $branch)')"

# Add UI override if passed, always use localhost.
# If needed could add support for ngrok url, via different key (smartdokui).
if [[ $@ =~ "ui" ]]; then
    frontEndUrl="http://localhost:8080"
elif [[ "$branch" != "master" ]]; then
    # Check if the branch has UI created, as it is not listed in "urls".
    # If it does, update frontend Url with branch one.
    hasFrontEnd="$(echo $branchData | jq '.branches["smartdok-ui"]')"
    if [[ "$hasFrontEnd" != null ]]; then
        frontEndUrl="$(echo $frontEndUrl | sed "s#master#$branch#")"
    fi
fi

# Append frontEnd URL
baseUrl="${baseUrl}&frontend-url=${frontEndUrl}"

# Build testing URL by iterating over URLs in env file.
# If branch has specific implementation, it will use that.
# If not it will use master
# Use NGROK url if respective key is passed in
urls="$(echo $branchData | jq '.urls')"
for key in $(echo "$urls" | jq -r 'keys[]' | tr -d '\r'); do
    # Fetch the url by the key, and "encode" it.
    url="$(echo "$urls" | jq -r --arg key "$key" '.[$key]')"

    # luna has different name in env and as query param
    if [[ "$key" == "lunaApi" ]]; then
        key="luna"
    fi

    # If the key is passed in as argument. Use ngrok url, allows overriding
    if [[ $@ =~ "$key" ]]; then
        subdomain="$(yq ".tunnels.${key}.subdomain" $CONFIG_FILE)"
        if [[ "$subdomain" = null ]]; then
            echo "Error: Value ${key} not found in config" >&2
            exit 1
        fi

        url="https://${subdomain}.eu.ngrok.io"
    fi

    # Append url query parameter, with lowercase key
    # "&smartapi-url=https......"
    baseUrl="${baseUrl}&${key,,}-url=${url}"
done

open_url() {
    url="$1"

    if   command -v xdg-open   >/dev/null 2>&1; then xdg-open   "$url" >/dev/null 2>&1 &
    elif command -v wslview    >/dev/null 2>&1; then wslview    "$url" >/dev/null 2>&1 &
    elif command -v open       >/dev/null 2>&1; then open       "$url" >/dev/null 2>&1 &   # macOS / BSD
    elif command -v cmd.exe    >/dev/null 2>&1; then start      "$url" >/dev/null 2>&1 &
    else
        printf 'Could not find a browser launcher. Please open this URL manually:\n%s\n' "$url" >&2
        return 1
    fi
}

open_url "$baseUrl" || exit 1
