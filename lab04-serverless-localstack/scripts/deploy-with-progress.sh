#!/usr/bin/env bash
set -euo pipefail

# Deploy helper that shows an estimated progress based on CloudFormation resources
# Usage: ./scripts/deploy-with-progress.sh [stack-name] [stage]

STACK_NAME="${1:-data-processing-service-local}"
STAGE="${2:-local}"
SERVICE="data-processing-service"

TEMPLATE_DIR=".serverless"
TEMPLATE_FILE="$TEMPLATE_DIR/cloudformation-template-update-stack.json"

echo "Packaging service (serverless package --stage $STAGE)..."
npx serverless package --stage "$STAGE"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Error: CloudFormation template not found at $TEMPLATE_FILE"
  exit 1
fi

# Count resources in the generated template
if command -v jq >/dev/null 2>&1; then
  TOTAL_RESOURCES=$(jq '.Resources|keys|length' "$TEMPLATE_FILE")
else
  echo "Warning: 'jq' not found, falling back to basic count (may be inaccurate)."
  TOTAL_RESOURCES=$(grep -o "Type: AWS::" -R "$TEMPLATE_FILE" | wc -l || true)
fi

echo "Total CloudFormation resources detected: $TOTAL_RESOURCES"

LOGFILE="/tmp/serverless-deploy.log"
rm -f "$LOGFILE"

echo "Starting deploy (serverless deploy --stage $STAGE). Logs -> $LOGFILE"
SLS_DEBUG=* npx serverless deploy --stage "$STAGE" > "$LOGFILE" 2>&1 &
DEPLOY_PID=$!

echo "Deploy PID: $DEPLOY_PID"

show_progress() {
  local created=0
  if [[ "$TOTAL_RESOURCES" -gt 0 ]]; then
    created=$(aws --endpoint-url=http://localhost:4566 cloudformation list-stack-resources --stack-name "$SERVICE-$STAGE" --query "StackResourceSummaries[?ResourceStatus=='CREATE_COMPLETE'||ResourceStatus=='UPDATE_COMPLETE'] | length(@)" --output text 2>/dev/null || echo 0)
  fi
  local pct=0
  if [[ "$TOTAL_RESOURCES" -gt 0 ]]; then
    pct=$(( created * 100 / TOTAL_RESOURCES ))
  fi
  printf "Progress: %d/%d (%d%%)\r" "$created" "$TOTAL_RESOURCES" "$pct"
}

while kill -0 "$DEPLOY_PID" 2>/dev/null; do
  show_progress
  sleep 2
done

wait "$DEPLOY_PID" || true
echo
echo "Deploy finished. Last 200 lines of serverless output:"
tail -n 200 "$LOGFILE" || true

echo "You can also inspect CloudFormation events:"
echo "aws --endpoint-url=http://localhost:4566 cloudformation describe-stack-events --stack-name $SERVICE-$STAGE"
