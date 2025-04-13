#!/usr/bin/env bash
# Requirements: ngrok + config, yq, jq,  sed

#TODO:
#General code cleanup, especially encode:
#Document center urls are not set?

CONFIG_FILE="$HOME/ngrok.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Required configuration file not found at '$CONFIG_FILE'" >&2
    echo "Please create it or check the path." >&2
    exit 1
fi

baseUrl="https://testing.smartdok.dev/Loader?next=%2FStart.aspx&overlay-url=https%3A%2F%2Fportal.smartdok.dev%2Foverlay.js"
frontEndUrl="https%3A%2F%2Fsmartdokui.z16.web.core.windows.net%2Fmaster%2F"
branch="master"

data="$(curl -sS https://portal.smartdok.dev/environments.json)"
branchData="$(echo $data | jq --arg branch $branch '.[] | select(.name == $branch)')"

#Resolve optional branch flag (-b)
while getopts ":b:" opt; do
    case $opt in
    b)
        # Return error message if branch does not exist
        # This could be iterated to a branch selection in fzf if wanted.
        portalBranches="$(echo $data | jq -r '.[] | .name')"
        if [[ ! $portalBranches =~ $OPTARG ]]; then
            echo "Error: Branch $OPTARG does not exist" >&2
            echo "Valid branches: $portalBranches" >&2
            exit 1
        fi
        branch=$OPTARG
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

# Add UI override if passed, always use localhost.
# If needed could add support for ngrok url, via different key (smartdokui).
if [[ $@ =~ "ui" ]]; then
    local="localhost%3A8080"
    frontEndUrl="http%3A%2F%2F${local}"
elif [[ "$branch" != "master" ]]; then
    # Check if the branch has UI created, as it is not listed in "urls".
    # if it does, update frontend Url with branch one
    hasFrontEnd="$(echo $branchData | jq '.branches["smartdok-ui"]')"
    if [[ ! "$hasFrontEnd" == null ]]; then
        frontEndUrl="$(echo $frontEndUrl | sed "s#master#$branch#")"
    fi
fi

baseUrl="${baseUrl}&frontend-url=${frontEndUrl}"

# Append the rest of the urls to the base url

# Fetch urls and iterate over them. Getting the key values
urls="$(echo $branchData | jq '.urls')"
for key in $(echo "$urls" | jq -r 'keys[]' | tr -d '\r'); do
    # Fetch the url by the key, and "encode" it.
    url="$(echo "$urls" | jq -r --arg key "$key" '.[$key]' | sed 's#://#%3A%2F%2F#g')"

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

        url="https%3A%2F%2F${subdomain}.eu.ngrok.io"
    fi

    # Append url query parameter, with lowercase key
    # "&smartapi-url=https......"
    baseUrl="${baseUrl}&${key,,}-url=${url}"
done

#Print the baseUrl. Useful for debug.
# echo $baseUrl

# Open the url in the browser, potentially only windows compatible
start $baseUrl
exit 1
