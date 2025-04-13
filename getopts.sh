# Will be combined into sd-open when I get it working
# Gets a -b to allow users to start developing from another branch then master.
# I.e. `./getopts.sh -b feature-live-feed luna bff`, will launch feature-live-feed and override luna & bff
# Copied from the portal with no overrides and master branch selected
# Working concept, but seems to have a breaking flaw (not tested):
# The feature branches are not created for every source, just the ones where the branch is created. So often just backend etc.
# This script will still override all of them, and probably not work then
baseUrl="https://testing.smartdok.dev/Loader?next=%2FStart.aspx&web-url=https%3A%2F%2Fsd-master-web.azurewebsites.net&frontend-url=https%3A%2F%2Fsmartdokui.z16.web.core.windows.net%2Fmaster%2F&smartapi-url=https%3A%2F%2Fsd-master-smartapi.azurewebsites.net&mobileapi-url=https%3A%2F%2Fsd-master-mobileapi.azurewebsites.net&smartdokapi-url=https%3A%2F%2Fsd-master-api.azurewebsites.net&luna-url=https%3A%2F%2Fsd-master-lunaapi.azurewebsites.net&bff-url=https%3A%2F%2Fsmartdok-bff-master.azurewebsites.net&overlay-url=https%3A%2F%2Fportal.smartdok.dev%2Foverlay.js&export-url=https%3A%2F%2Fsmartdok-export-master.azurewebsites.net&document-service-url=https%3A%2F%2Fsmartdok-documents-master.azurewebsites.net&document-center-url=https%3A%2F%2Fsd-document-center-master.azurewebsites.net&htmlpdf-url=https%3A%2F%2Fsmartdok-htmlpdf-master.azurewebsites.net&officepdf-url=https%3A%2F%2Fsmartdok-office-pdf-master.azurewebsites.net"

# getopts b: VARNAME
# -b flag = branch namej
while getopts ":b:" opt; do
  case $opt in
    b)
      echo "-b was triggered, Parameter: $OPTARG" >&2
      baseUrl="$(echo $baseUrl | sed "s#master#$OPTARG#g")"
      echo $baseUrl
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

shift $((OPTIND - 1))

for source in "$@"
do
    echo "$source"
done

exit 1
