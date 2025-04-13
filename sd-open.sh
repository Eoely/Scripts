#!/usr/bin/env bash
CONFIG_FILE="$HOME/ngrok.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Required configuration file not found at '$CONFIG_FILE'" >&2
    echo "Please create it or check the path." >&2
    exit 1
fi

baseUrl="https://testing.smartdok.dev/Loader?next=%2FStart.aspx&overlay-url=https%3A%2F%2Fportal.smartdok.dev%2Foverlay.js"
frontEndUrl="https%3A%2F%2Fsmartdokui.z16.web.core.windows.net%2Fmaster%2F"
# TODO: Read as flag argument with default to master
# branch="feature-forms-V3"
branch="feature-handbook-test"

# data="$(curl -sS https://portal.smartdok.dev/environments.json)"
data="$(cat ./portal.json)"
branchData="$(echo $data | jq --arg branch $branch '.[] | select(.name == $branch)')"

# Check if the branch has UI created exclusively, as it is not listed in "urls".
# if it does, update frontEnd Url with branch one
# Could skip all of this if the branch is just "master". But does no harm if it executes. KISS for now
hasFrontEnd="$(echo $data | jq --arg branch $branch '.[] | select(.name == $branch).branches["smartdok-ui"]')"
if [[ ! "$hasFrontEnd" = null ]]; then
    frontEndUrl="$(echo $frontEndUrl | sed "s#master#$branch#")"
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

    if [[ $@ =~ "$key" ]]; then
        echo "Hello world"
    fi

    # Append url param, with lowercase key
    # "&smartapi-url=https......"
    baseUrl="${baseUrl}&${key,,}-url=${url}"
done

echo $baseUrl

exit 1

# Old snippet

for source in "$@"; do
    subdomain="$(yq ".tunnels.${source}.subdomain" $CONFIG_FILE)"
    if [[ "$subdomain" = null ]]; then
        echo "Error: Value ${source} not found in config" >&2
        exit 1
    fi

    # Complete expected url, encoded. ("https://")
    url="https%3A%2F%2F${subdomain}.eu.ngrok.io"

    #url paramter representing the override
    paramKey="&${source}-url="

    # Replaces the url parameter value with the ngrok subdomain
    baseUrl="$(echo $baseUrl | sed "s#\($paramKey\)[^&]*#\1$url#")"
done

# Print the generated URL, if there is issues opening it.
echo "$baseUrl"

# Open the url in the browser. I imagine that this will only work for windows
# So would have to expand when necessary
start $baseUrl

exit 1
