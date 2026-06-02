#!/usr/bin/env bash
# set_project_fields.sh
#
# Project Life #2 のアイテムに対して Status / Area を一括設定する。
#
# Usage:
#   set_project_fields.sh <ITEM_ID> [--status NAME] [--area NAME]
#
# Example:
#   set_project_fields.sh PVTI_xxx --status Todo --area dev/AI
#
# ITEM_ID は `gh project item-list 2 --owner imutaroh --format json` の `.items[].id`。
# Field ID / Option ID は references/project_life_ids.md と同期している。
# 構造が変わったらこのスクリプトも更新すること。
set -euo pipefail

PROJECT_ID="PVT_kwHODDLAY84BXouL"

STATUS_FIELD="PVTSSF_lAHODDLAY84BXouLzhS0RIU"
declare -A STATUS_OPT=(
  ["Todo"]="20e57f3e"
  ["In Progress"]="4e84ccd9"
  ["Review"]="be2accf1"
  ["Pending"]="97724816"
  ["Done"]="de4d5180"
)

AREA_FIELD="PVTSSF_lAHODDLAY84BXouLzhS0V8U"
declare -A AREA_OPT=(
  ["Mind"]="704b1f98"
  ["dev/AI"]="d5ca1188"
  ["Work"]="5defc752"
  ["Life"]="d697154a"
)

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <ITEM_ID> [--status NAME] [--area NAME]" >&2
  exit 1
fi

ITEM_ID=$1; shift

STATUS=""
AREA=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status) STATUS="$2"; shift 2 ;;
    --area)   AREA="$2";   shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

set_field() {
  local field_id=$1
  local opt_id=$2
  local label=$3
  gh api graphql -f query="
    mutation {
      updateProjectV2ItemFieldValue(input: {
        projectId: \"$PROJECT_ID\",
        itemId: \"$ITEM_ID\",
        fieldId: \"$field_id\",
        value: { singleSelectOptionId: \"$opt_id\" }
      }) { projectV2Item { id } }
    }" > /dev/null && echo "  OK $label"
}

if [[ -n "$STATUS" ]]; then
  opt="${STATUS_OPT[$STATUS]:-}"
  [[ -z "$opt" ]] && { echo "unknown status: $STATUS" >&2; exit 1; }
  set_field "$STATUS_FIELD" "$opt" "Status=$STATUS"
fi

if [[ -n "$AREA" ]]; then
  opt="${AREA_OPT[$AREA]:-}"
  [[ -z "$opt" ]] && { echo "unknown area: $AREA (use exact name from references/project_life_ids.md)" >&2; exit 1; }
  set_field "$AREA_FIELD" "$opt" "Area=$AREA"
fi
