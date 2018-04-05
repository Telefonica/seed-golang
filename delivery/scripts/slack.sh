#!/bin/bash -e

# Send slack message.
# It requires the following argument:
# - $1: slack url
# - $2: slack token
# - $3: slack channel
# - $4: text message
# If any of these variables are not set, the message is not sent via slack.
#
# See:
# - https://api.slack.com/incoming-webhooks
slack_msg() {
  local url="$1"
  local token="$2"
  local channel="$3"
  local message="$4"

  echo $message

  if [ -z "$url" ] || [ -z "$token" ] || [ -z "$channel" ]; then
    return
  fi

  curl -s -X POST \
       -H 'Content-type: application/json; charset=utf-8' \
       -H "Authorization: Bearer $token" \
       --data '{"channel":"'"$channel"'", "as_user": true, "text":"'"$message"'"}' \
       "$url"
}

"$@"
