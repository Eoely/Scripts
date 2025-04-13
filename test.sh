baseUrl="https://testing.smartdok.dev/Loader?next=%2FStart.aspx"
frontEndUrl="https://smartdokui.z16.web.core.windows.net/master"
echo $frontEndUrl

# TODO: read this in as flag, and default to master if not passed
branch="feature-forms-V3"
# branch="feature-handbook-test"

data="$(curl -sS https://portal.smartdok.dev/environments.json)"

# Check if the branch has UI created exclusively, as it is not listed in "urls".
# if it does, update frontEnd Url with branch one
hasFrontEnd="$(echo $data | jq --arg branch $branch '.[] | select(.name == $branch).branches["smartdok-ui"]')"
if [[ ! "$hasFrontEnd" = null ]]; then
    frontEndUrl="$(echo $frontEndUrl | sed "s#master#$branch#")"
fi

echo $frontEndUrl

exit 1

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
