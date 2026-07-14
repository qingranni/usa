#!/usr/bin/env bash
set -euo pipefail

ASSETS="Universal Search App/Assets.xcassets"

# asset-name|image-url
PAIRS=(
"cancun-1|https://mediaim.expedia.com/lodging/58000000/57180000/57171900/57171807/476515a7.jpg"
"cancun-2|https://mediaim.expedia.com/lodging/1000000/20000/13000/12937/c80fa3fa.jpg"
"cancun-3|https://mediaim.expedia.com/lodging/20000000/19370000/19369300/19369216/903afe38.jpg"
"cabo-1|https://mediaim.expedia.com/lodging/2000000/1150000/1143300/1143264/4b002683.jpg"
"cabo-2|https://mediaim.expedia.com/lodging/2000000/1720000/1716700/1716692/0c3d27b5.jpg"
"cabo-3|https://mediaim.expedia.com/lodging/2000000/1480000/1477200/1477156/90b5ce00.jpg"
"pv-1|https://mediaim.expedia.com/lodging/3000000/2620000/2614800/2614708/fa283f3f.jpg"
"pv-2|https://mediaim.expedia.com/lodging/2000000/1930000/1929300/1929211/4035bf08.jpg"
"pv-3|https://mediaim.expedia.com/lodging/1000000/30000/24200/24197/933f24b8.jpg"
"tulum-1|https://mediaim.expedia.com/lodging/11000000/10960000/10951100/10951036/9d92cb74.jpg"
"tulum-2|https://mediaim.expedia.com/lodging/12000000/11690000/11688200/11688126/cd5e0abf.jpg"
"tulum-3|https://mediaim.expedia.com/lodging/12000000/11540000/11539100/11539068/e2fcf7e3.jpg"
"playa-1|https://mediaim.expedia.com/lodging/2000000/1160000/1151600/1151540/e03f3ca2.jpg"
"playa-2|https://mediaim.expedia.com/lodging/11000000/10960000/10951100/10951036/9d92cb74.jpg"
"playa-3|https://mediaim.expedia.com/lodging/2000000/1060000/1054600/1054536/5e8318dc.jpg"
"la-1|https://mediaim.expedia.com/lodging/1000000/30000/25800/25715/fba39dca.jpg"
"la-2|https://mediaim.expedia.com/lodging/1000000/20000/11500/11485/e35324fe.jpg"
"la-3|https://mediaim.expedia.com/lodging/19000000/18960000/18952900/18952850/faa5ba25.jpg"
"tampa-1|https://mediaim.expedia.com/lodging/1000000/10000/2100/2051/678eaef4.jpg"
"tampa-2|https://mediaim.expedia.com/lodging/1000000/10000/2100/2098/61a36718.jpg"
"tampa-3|https://mediaim.expedia.com/lodging/16000000/15920000/15914400/15914352/da0937cd.jpg"
)

fail=0
for pair in "${PAIRS[@]}"; do
  name="${pair%%|*}"
  url="${pair#*|}"
  dir="$ASSETS/$name.imageset"
  mkdir -p "$dir"
  if curl -fsSL --max-time 30 "$url" -o "$dir/$name.jpg"; then
    size=$(stat -f%z "$dir/$name.jpg")
    if [ "$size" -lt 2000 ]; then
      echo "WARN  $name -> only $size bytes"
      fail=1
    else
      echo "OK    $name ($size bytes)"
    fi
    cat > "$dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$name.jpg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
  else
    echo "FAIL  $name <- $url"
    fail=1
  fi
done

echo "---"
[ "$fail" -eq 0 ] && echo "ALL HEROES OK" || echo "SOME HEROES FAILED"
