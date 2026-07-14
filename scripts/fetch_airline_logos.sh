#!/usr/bin/env bash
set -euo pipefail

# Airline logos from Kiwi.com's public logo CDN, keyed by IATA code.
ASSETS="Universal Search App/Assets.xcassets"

# asset-name|IATA
PAIRS=(
"airline-b6|B6"   # JetBlue
"airline-dl|DL"   # Delta
"airline-aa|AA"   # American
"airline-ua|UA"   # United
"airline-nk|NK"   # Spirit
"airline-as|AS"   # Alaska
"airline-wn|WN"   # Southwest
"airline-am|AM"   # Aeromexico
)

fail=0
for pair in "${PAIRS[@]}"; do
  name="${pair%%|*}"
  code="${pair#*|}"
  dir="$ASSETS/$name.imageset"
  url="https://images.kiwi.com/airlines/128/$code.png"
  mkdir -p "$dir"
  if curl -fsSL --max-time 30 "$url" -o "$dir/$name.png"; then
    size=$(stat -f%z "$dir/$name.png")
    if [ "$size" -lt 500 ]; then echo "WARN  $name -> $size bytes"; fail=1; else echo "OK    $name ($size bytes)"; fi
    cat > "$dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$name.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "original"
  }
}
JSON
  else
    echo "FAIL  $name <- $url"; fail=1
  fi
done

echo "---"
[ "$fail" -eq 0 ] && echo "ALL LOGOS OK" || echo "SOME LOGOS FAILED"
