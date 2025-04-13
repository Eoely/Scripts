#!/usr/bin/env bash

# I want a shell script to "automate" the portal opening process. Both opening the branches, and imporantly supporting overrides
#
# `sd-start master` should open master branch with no overrides. Also support i.e. "feature-live-feed" instead of master
# `sd-start master --override luna mobileapi web` etc etc. Same syntax as ngrok start
# Should ideally integrate with the ngrok config directly, both for consistently naming and for getting the correct url
#
# Which branches to show: Could either just be a config of relevant branches, just input any name and hope it works, or fetch relevant branches from azure. Like we do in list-branches


# Does this even make sense? It is not a config file since it does not export anything...
# Not sure what is the best approach then,probably just reading its content to a string.
CONFIG_FILE="$HOME/ngrok.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Required configuration file not found at '$CONFIG_FILE'" >&2
    echo "Please create it or check the path." >&2
    exit 1
fi

# Copied from the portal with no overrides and master branch selected
baseUrl="https://testing.smartdok.dev/Loader?next=%2FStart.aspx&web-url=https%3A%2F%2Fsd-master-web.azurewebsites.net&frontend-url=https%3A%2F%2Fsmartdokui.z16.web.core.windows.net%2Fmaster%2F&smartapi-url=https%3A%2F%2Fsd-master-smartapi.azurewebsites.net&mobileapi-url=https%3A%2F%2Fsd-master-mobileapi.azurewebsites.net&smartdokapi-url=https%3A%2F%2Fsd-master-api.azurewebsites.net&luna-url=https%3A%2F%2Fsd-master-lunaapi.azurewebsites.net&bff-url=https%3A%2F%2Fsmartdok-bff-master.azurewebsites.net&overlay-url=https%3A%2F%2Fportal.smartdok.dev%2Foverlay.js&export-url=https%3A%2F%2Fsmartdok-export-master.azurewebsites.net&document-service-url=https%3A%2F%2Fsmartdok-documents-master.azurewebsites.net&document-center-url=https%3A%2F%2Fsd-document-center-master.azurewebsites.net&htmlpdf-url=https%3A%2F%2Fsmartdok-htmlpdf-master.azurewebsites.net&officepdf-url=https%3A%2F%2Fsmartdok-office-pdf-master.azurewebsites.net"

for source in "$@"
do
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
