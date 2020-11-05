#!/bin/bash

#variables
targetSite='<App URL>'
appName='<App name>'
today=`date +"%Y_%m_%d"`
reportName="${today}_${appName}_DAST_baseline.html"
spiderDuration='2'
configFile="${appName}_config.conf"
loginUrl='<App login form URL>'
username='username'
password='password'
usernameField='j_username'
passwordField='j_password'
submitField='submit'
#######################################################################
create_ticket_url='https://<JIRA instance URL>/rest/api/2/issue/'
credential='Username:password -> BASE64'
project_key='<DAST project key>'
summary="DAST Scan for ${appName} - ${today}."
description="Baseline scanning for ${appName} has been completed. Do refer to the attached report for details." 
issuetype='Task'
component='11544'


#execute baseline scan
docker run --rm --network="host" -v $(pwd):/zap/wrk/:rw -t ictu/zap2docker-weekly zap-baseline.py \
-t $targetSite \
-r $reportName \
--hook=/zap/auth_hook.py \
-j \
-m $spiderDuration \
-g $configFile \
-c $configFile \
-z "auth.loginurl=$loginUrl \
auth.username=\"$username\" \
auth.password=\"$password\" \
auth.username_field=\"$usernameField\" \
auth.password_field=\"$passwordField\" \
auth.submit_field="$submitField" \
"

#check if file exist and return error if it doesnt
if [ ! -f "$reportName" ]; then
	echo "$reportName does not exist." && exit 1
else
	echo "$reportName does exist."
fi

#create issue in Jira
curl -X POST \
  $create_ticket_url \
  -H "Authorization: Basic $credential" \
  -H 'Content-Type: application/json' \
  -H 'Host: jira.myeg.com.my' \
  -d "{
    \"fields\": {
        \"project\": {
            \"key\": \"$project_key\"},
        \"summary\": \"$summary\",
        \"description\": \"$description\",
        \"issuetype\": {
            \"name\": \"$issuetype\"},
        \"components\": [{
        	 \"id\": \"$component\"}]
    }
}" > jiraresponse.json

#attach report to issue
issue_id=`jq -r '.id' jiraresponse.json`
attachment_url="https://<JIRA instance URL>/rest/api/2/issue/${issue_id}/attachments"

curl -D- -X POST \
  $attachment_url \
  -H "Authorization: Basic $credential" \
  -H 'X-Atlassian-Token: nocheck' \
  -H 'Host: <JIRA instance URL>' \
  -F "file=@$(pwd)/$reportName"
