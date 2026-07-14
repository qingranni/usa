#!/bin/bash
set -euo pipefail

SRC="$HOME/Desktop/Files/egds-prototype-kit-template/packages/specs/sources/egds/icons/expedia"
DST="$HOME/Desktop/Files/Universal Search App/Universal Search App/Assets.xcassets/EGDSIcons"

mkdir -p "$DST"

# EGDS glyph slugs referenced by the app (see EGDSIcon.swift resolver).
slugs=(
  chevron-left arrow-forward arrow-downward arrow-upward
  home favorite favorite-outline mode-edit
  lob-hotels flight flight-takeoff flight-land directions-car
  local-activity place map chat add close history distance
  bed remove search tune attractions ai trips
  account-circle person group child calendar
  check check-circle circle-outlined copy-content refresh mic delete
)

for slug in "${slugs[@]}"; do
  src="$SRC/egds-icon-glyph-$slug.svg"
  if [[ ! -f "$src" ]]; then
    echo "MISSING: $slug" >&2
    continue
  fi
  set="$DST/egds-$slug.imageset"
  mkdir -p "$set"
  cp "$src" "$set/$slug.svg"
  cat > "$set/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$slug.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "template"
  }
}
JSON
done

# Namespace group so assets are referenced as "EGDSIcons/egds-<slug>" is optional;
# we keep flat names ("egds-<slug>") by NOT providing a provides-namespace flag.
cat > "$DST/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Imported ${#slugs[@]} EGDS icon imagesets into $DST"
ls "$DST" | wc -l
