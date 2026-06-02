#!/usr/bin/env bash
# set_project_fields.sh
#
# Project Life #2 のアイテムに対して Status / Quadrant / Area を一括設定する。
#
# Usage:
#   set_project_fields.sh <ITEM_ID> [--status NAME] [--quadrant Q1|Q2|Q3|Q4] [--area NAME]
#
# Example:
#   set_project_fields.sh PVTI_xxx --status Todo --quadrant Q2 --area dev
#
# ITEM_ID は `gh project item-list 2 --owner imutaroh --format json` の `.items[].id`。
# Field ID / Option ID は references/project_life_ids.md と同期している。
# 構造が変わったらこのスクリプトも更新すること。
set -euo pipefail

PROJECT_ID="PVT_kwHODDLAY84BXouL"

STATUS_FIELD="PVTSSF_lAHODDLAY84BXouLzhS0RIU"
declare -A STATUS_OPT=(
  ["Todo"]="05859249"
  ["In Progress"]="3c81879e"
  ["Review"]="fbe41ce3"
  ["Pending"]="cad6c6a3"
  ["Done"]="ed91ac74"
)

QUADRANT_FIELD="PVTSSF_lAHODDLAY84BXouLzhS0V8Q"
declare -A QUADRANT_OPT=(
  ["Q1"]="07074fa4"
  ["Q2"]="bef87806"
  ["Q3"]="223a3f9b"
  ["Q4"]="bbf33342"
)

AREA_FIELD="PVTSSF_lAHODDLAY84BXouLzhS0V8U"
declare -A AREA_OPT=(
  ["コンテンツ"]="2a99415d"
  ["AI"]="c1076792"
  ["アウトプット"]="b09f18b5"
  ["健康"]="4913ceb1"
  ["Scarlet"]="43aa5b54"
  ["and roots"]="6874f546"
  ["金融"]="a151978a"
  ["dev"]="3d15ddf8"
  ["人"]="c49be055"
)

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <ITEM_ID> [--status NAME] [--quadrant Q1|Q2|Q3|Q4] [--area NAME]" >&2
  exit 1
fi

ITEM_ID=$1; shift

STATUS=""
QUADRANT=""
AREA=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)   STATUS="$2";   shift 2 ;;
    --quadrant) QUADRANT="$2"; shift 2 ;;
    --area)     AREA="$2";     shift 2 ;;
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

if [[ -n "$QUADRANT" ]]; then
  opt="${QUADRANT_OPT[$QUADRANT]:-}"
  [[ -z "$opt" ]] && { echo "unknown quadrant: $QUADRANT" >&2; exit 1; }
  set_field "$QUADRANT_FIELD" "$opt" "Quadrant=$QUADRANT"
fi

if [[ -n "$AREA" ]]; then
  opt="${AREA_OPT[$AREA]:-}"
  [[ -z "$opt" ]] && { echo "unknown area: $AREA (use exact name from references/project_life_ids.md)" >&2; exit 1; }
  set_field "$AREA_FIELD" "$opt" "Area=$AREA"
fi
