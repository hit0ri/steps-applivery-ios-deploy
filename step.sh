#!/bin/bash

echo "=> Starting Applivery v3 iOS Deploy"

THIS_SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function echoStatusFailed {
  envman add --key APPLIVERY_DEPLOY_STATUS --value "failed"
  echo
  echo 'APPLIVERY_DEPLOY_STATUS: "failed"'
  echo " --------------"
}

############# VALIDATIONS ##############

# IPA
if [ ! -f "${ipa_path}" ] ; then
  echo "# Error"
  echo "* No IPA found to deploy. Specified path was: ${ipa_path}"
  echoStatusFailed
  exit 1
fi

# APPLIVERY API TOKEN
if [ -z "${appToken}" ] ; then
  echo "# Error"
  echo '* No App Token provided as environment variable. Terminating...'
  echoStatusFailed
  exit 1
fi

############# DEFINITIONS ##############

buildNumber="${BITRISE_BUILD_NUMBER}"
repositoryUrl="${GIT_REPOSITORY_URL}"
ciUrl="${BITRISE_APP_URL}"
buildUrl="${BITRISE_BUILD_URL}"
triggerTimestamp="${BITRISE_BUILD_TRIGGER_TIMESTAMP}"
branch="${BITRISE_GIT_BRANCH}"
tag="${BITRISE_GIT_TAG}"
commit="${BITRISE_GIT_COMMIT}"
commitMessage="${BITRISE_GIT_MESSAGE}"
provisionUrl="${BITRISE_PROVISION_URL}"
app_path="${BITRISE_APP_DIR_PATH}"

echo
echo "========== CONFIGURATION =========="
echo "* appToken: *****************"
echo "* app_id: deprecated"
echo "* version_name: ${versionName}"
echo "* changelog: ${changelog}"
echo "* notifyCollaborators: ${notifyCollaborators}"
echo "* notifyEmployees: ${notifyEmployees}"
echo "* notifyMessage: ${notifyMessage}"
echo "* autoremove: deprecated"
echo "* os: deprecated"
echo "* tags: ${tags}"
echo "* filter: ${filter}"
echo "* ipa_path: ${ipa_path}"
echo "* app_path: ${app_path}"
echo
echo "========== DEPLOYMENT VALUES =========="
echo "* commitMessage: ${commitMessage}"
echo "* commit: ${commit}"
echo "* branch: ${branch}"
echo "* tag: ${tag}"
echo "* triggerTimestamp: ${triggerTimestamp}"
echo "* buildUrl: ${buildUrl}"
echo "* ciUrl: ${ciUrl}"
echo "* repositoryUrl: ${repositoryUrl}"
echo "* buildNumber: ${buildNumber}"
echo "* provisionUrl: ${provisionUrl}"


echo
############# Generate Zip ###############
zip -r "/tmp/app.zip" "${app_path}"
tmpAppPath="/tmp/app.zip"
echo "* tmpAppPath: ${tmpAppPath}"


############# GENERATE CURL ##############

curl_cmd="curl"

# Add Cmain params
curl_args=(
  --fail
  -H "Authorization: bearer ${appToken}"
  -F "versionName=${versionName}"
  -F "changelog=${changelog}"
  -F "notifyCollaborators=${notifyCollaborators}"
  -F "notifyEmployees=${notifyEmployees}"
  -F "tags=${tags}"
  -F "filter=${filter}"

  -F "build=@${ipa_path}"
  -F "simulatorBuild=@${tmpAppPath}"
  -F "deployer.name=bitrise"
  -F "deployer.info.commitMessage=${commitMessage}"
  -F "deployer.info.commit=${commit}"
  -F "deployer.info.branch=${branch}"
  -F "deployer.info.tag=${tag}"
  -F "deployer.info.triggerTimestamp=${triggerTimestamp}"
  -F "deployer.info.buildUrl=${buildUrl}"
  -F "deployer.info.ciUrl=${ciUrl}"
  -F "deployer.info.repositoryUrl=${repositoryUrl}"
  -F "deployer.info.buildNumber=${buildNumber}"
)
# Add Codesigning conditionally
if [ "${uploadCodeSigning}" = true ] ; then
  curl_args+=(
    -F "deployer.info.provisionUrl=${provisionUrl}"
    -F "deployer.info.certificateUrl=${certificateUrl}"
    -F "deployer.info.certificatePassphrase=${certificatePassphrase}"
  )
fi

# Add Applivery API URL
curl_args+=("https://upload.applivery.io/v1/integrations/builds")

echo
echo "=> Curl:"
echo "$ $curl_cmd" "${curl_args[@]}"
echo

json=$("$curl_cmd" "${curl_args[@]}")
curl_res=$?

echo
echo "========== RESULT =========="
echo " * cURL command exit code: ${curl_res}"
echo " * JSON response: ${json}"
echo "============================"
echo

if [ ${curl_res} -ne 0 ] ; then
  echo "# Error"
  echo '* cURL command exit code not zero!'
  echoStatusFailed
  exit 1
fi

# error handling
if [[ ${json} ]] ; then
  errors=`ruby "${THIS_SCRIPTDIR}/steps-utils-jsonval/parse_json.rb" \
  --json-string="${json}" \
  --prop=error`
  parse_res=$?
  if [ ${parse_res} -ne 0 ] ; then
     errors="Failed to parse the response JSON"
  fi
else
  errors="No valid JSON result from request."
fi

if [[ ${errors} ]]; then
  echo "# Error"
  echo "* ${errors}"
  echoStatusFailed
  exit 1
fi

# everything is OK

envman add --key "APPLIVERY_DEPLOY_STATUS" --value "success"


# final results
echo "* Deploy Result: Success"

exit 0
