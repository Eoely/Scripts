CONFIG_FILE="$HOME/ngrok.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Required configuration file not found at '$CONFIG_FILE'" >&2
    echo "Please create it or check the path." >&2
    exit 1
fi

baseUrl="https://testing.smartdok.dev/Loader?next=%2FStart.aspx"
frontEndUrl="https://smartdokui.z16.web.core.windows.net/master"

# TODO: read this in as flag, and default to master if not passed
branch="feature-forms-V3"
branch="feature-handbook-test"

# data="$(curl -sS https://portal.smartdok.dev/environments.json)"
data="$(cat ./portal.json)"
branchData="$(echo $data | jq --arg branch $branch '.[] | select(.name == $branch)')"

# Fetch urls and iterate over them. Getting the key values
urls="$(echo $branchData | jq '.urls')"
for key in $(echo "$urls" | jq -r 'keys[]' | tr -d '\r'); do
    value="$(echo "$urls" | jq -r --arg key "$key" '.[$key]')"
    echo "$key = $value"
done

exit 1

# Check if the branch has UI created exclusively, as it is not listed in "urls".
# if it does, update frontEnd Url with branch one
# Could skip all of this if the branch is just "master". But does no harm if it executes. KISS for now
hasFrontEnd="$(echo $data | jq --arg branch $branch '.[] | select(.name == $branch).branches["smartdok-ui"]')"
if [[ ! "$hasFrontEnd" = null ]]; then
    frontEndUrl="$(echo $frontEndUrl | sed "s#master#$branch#")"
fi

# Add frontend-url. TODO: Maybe "addParam" function?
baseUrl="${baseUrl}&frontend-url=${frontEndUrl}"

# TODO: This should not always be the case, only if the branch has UI.
# So first need to see if it has it, if not use master.

baseUrl="$(echo $baseUrl | sed "s#master#$OPTARG#g")"
exit 1

# I think essentially the whole program could be a loop that builds the URL
# And then opens it at the end.
# 1. Define "base url". Testing.smartdok.dev. + loader.aspx stuff
# 2. Curl portal enviornment json file
# 3. Use jq to select to correct branch. Read from flag arg, and default to master if not passed.
# 4. Have special case for frontend-url. Just hardcode the default master frontend url and check if the branch you passed has smartdok-ui defined in branches. Replace master in frontendUrl.
# 5. Iterate over all defined urls.
# 5.1 If key defined as mass argument: use the ngrok config url
# 5.2 Else use url defined in "urls"
# 5.3 We probably need to url decode all the urls then?
