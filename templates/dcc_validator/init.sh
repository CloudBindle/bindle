#!/bin/bash
#
# note: initializes the submission system
# usage: ./init.sh https://submissions.dcc.icgc.org http://localhost:5380 guest password my_initial_release my_project_key [my_project_name] [my_project_alias]

# ===========================================================================

origin_host=${1?} && shift
destination_host=${1?} && shift
username=${1?} && shift
passwd=${1?} && shift
initial_release_name=${1?} && shift
project_key=${1?}
project_name=$2 && project_name=${project_name:=${project_key?}}
project_alias=$3 && project_alias=${project_alias:=${project_key?}}

tmp_dir="/tmp/dcc" && mkdir -p ${tmp_dir?}
dictionary_file="${tmp_dir?}/dictionary.json"
 codelists_file="${tmp_dir?}/codelists.json"

# ===========================================================================

echo "origin_host=${origin_host?}"
echo "destination_host=${destination_host?}"
echo "username=${username?}"
echo "passwd=[...]"
echo "initial_release_name=${initial_release_name?}"
echo "project_key=${project_key?}"
echo "project_name=${project_name?}"
echo "project_alias=${project_alias?}"

# ===========================================================================

function ensure_open() {
 awk '{gsub(/"state" *: *"CLOSED"/,"\"state\":\"OPENED\"")}1'
}

function extract_version() {
 python -c "import json,sys;print json.loads(sys.stdin.read())['version'];"
}

# ===========================================================================

# Drop database, if it exists
echo "dropping mongo icgc-dev database"
/usr/bin/mongo icgc-dev --eval "db.dropDatabase()"
#/usr/bin/mongo --verbose icgc-dev --eval "db.Project.drop()"
#/usr/bin/mongo --verbose icgc-dev --eval "db.Release.drop()"
#/usr/bin/mongo --verbose icgc-dev --eval "db.User.drop()"

# Clean file system, if it exists
echo "removing /mnt/dcc-portal/dcc_root_dir/*"
rm -rvf /mnt/dcc-portal/dcc_root_dir/*
#rm -rvf /tmp/dcc_root_dir/*

# download origin dictionary and ensure state is OPENED
echo "getting dictionary"
curl ${origin_host?}/ws/nextRelease/dictionary   -H "Accept: application/json" | ensure_open > ${dictionary_file?} && echo "OK" || echo "KO"

# download origin codelists
echo "getting codelists"
curl ${origin_host?}/ws/codeLists                -H "Accept: application/json" > ${codelists_file?} && echo "OK" || echo "KO"

# extract dictionary version (needed for initial release later)
echo "extracting dictionary version"
dictionary_version=$(cat ${dictionary_file?} | extract_version) && [ -n "${dictionary_version?}" ] || { echo "ERROR: could not find a version in dictionary"; }
echo "dictionary_version=${dictionary_version?}"


# Check that server api is indeed available
curl_state=0
for idx in {1..8}
do
   echo "Checking submission server is ready..."
   curl --silent --write-out %{http_code} -H "Accept: application/json" -H "Authorization: X-DCC-Auth $(echo -n ${username?}:${passwd?} | base64)" ${destination_host?}/ws/systems/sftp -o /tmp/foo > /tmp/curl_state
   curl_state=$(</tmp/curl_state)
   if [ ${curl_state} = "200" ]; then
      break
   fi
   echo "return code is {$curl_state}, waiting for submission system to come up...sleeping 5"
   sleep 5
done

if [ ${curl_state} != "200" ]; then
   echo "There is an error with the submission server! Exiting..."
   exit 1
fi


# upload codelists to destination
echo "uploading codelists"
curl -XPOST ${destination_host?}/ws/codeLists    -H "Accept: application/json" -H "Authorization: X-DCC-Auth $(echo -n ${username?}:${passwd?} | base64)" -H "Content-Type: application/json" \
 --data @${codelists_file?} && echo "OK" || echo "KO"

# upload dictionary to destination
echo "uploading dictionary"
curl -XPOST ${destination_host?}/ws/dictionaries -H "Accept: application/json" -H "Authorization: X-DCC-Auth $(echo -n ${username?}:${passwd?} | base64)" -H "Content-Type: application/json" \
 --data @${dictionary_file?} && echo "OK" || echo "KO"

# upload an initial release (should probably be a POST rather...)
echo "creating initial release"
curl -XPUT ${destination_host?}/ws/releases      -H "Accept: application/json" -H "Authorization: X-DCC-Auth $(echo -n ${username?}:${passwd?} | base64)" -H "Content-Type: application/json" \
 --data "{ \"name\" : \"${initial_release_name?}\", \"dictionaryVersion\" : \"${dictionary_version?}\", \"submissions\": [], \"state\" : \"OPENED\" }" && echo "OK" || echo "KO"

# add a project
echo "adding project"
curl -H "Accept: application/json" -XPOST ${destination_host?}/ws/projects     -H "Authorization: X-DCC-Auth $(echo -n ${username?}:${passwd?} | base64)" -H "Content-Type: application/json" \
 --data "{\"key\": \"${project_key?}\", \"name\": \"${project_name?}\", \"alias\": \"${project_alias?}\", \"users\": [\"guest\"], \"groups\": []}" && echo "OK" || echo "KO"



# ===========================================================================

echo "cleaning up"
rm -v ${tmp_dir?}/*
rmdir -v ${tmp_dir?}

echo "done"

# Signal error if there is no dictionary detected
if [ "${dictionary_version}" = "" ]; then
   exit 1
fi
exit 0
# ===========================================================================


