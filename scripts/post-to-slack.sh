#!/bin/bash
# Post a message to Slack using the bot token.
# Usage: ./scripts/post-to-slack.sh <message-file>
#   or:  ./scripts/post-to-slack.sh <channel-id> <message-file>
#
# Reads SLACK_BOT_TOKEN and SLACK_CHANNEL_ID from .env in the repo root.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Load .env
if [ -f "$REPO_ROOT/.env" ]; then
  set -a
  source "$REPO_ROOT/.env"
  set +a
fi

if [ -z "$SLACK_BOT_TOKEN" ]; then
  echo "ERROR: SLACK_BOT_TOKEN not set. Check .env file." >&2
  exit 1
fi

# Parse args: either (message-file) or (channel-id, message-file)
if [ $# -eq 1 ]; then
  CHANNEL="$SLACK_CHANNEL_ID"
  MSG_FILE="$1"
elif [ $# -eq 2 ]; then
  CHANNEL="$1"
  MSG_FILE="$2"
else
  echo "Usage: $0 [channel-id] <message-file>" >&2
  exit 1
fi

if [ -z "$CHANNEL" ]; then
  echo "ERROR: No channel specified and SLACK_CHANNEL_ID not set." >&2
  exit 1
fi

if [ ! -f "$MSG_FILE" ]; then
  echo "ERROR: Message file not found: $MSG_FILE" >&2
  exit 1
fi

# Read message and escape for JSON
MESSAGE=$(cat "$MSG_FILE")
JSON_PAYLOAD=$(jq -n --arg channel "$CHANNEL" --arg text "$MESSAGE" \
  '{channel: $channel, text: $text, unfurl_links: false, unfurl_media: false}')

RESPONSE=$(curl -s -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD")

OK=$(echo "$RESPONSE" | jq -r '.ok')
if [ "$OK" = "true" ]; then
  TS=$(echo "$RESPONSE" | jq -r '.ts')
  echo "Message posted successfully. ts=$TS"
  echo "https://ambient-ai.slack.com/archives/$CHANNEL/p${TS//./}"
else
  ERROR=$(echo "$RESPONSE" | jq -r '.error')
  echo "ERROR: Slack API returned: $ERROR" >&2
  echo "$RESPONSE" >&2
  exit 1
fi
