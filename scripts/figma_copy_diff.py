#!/usr/bin/env python3
"""
figma_copy_diff.py — diff the visible text on a Figma node against CopyStrings.json.

Automates the "capture strings from the board, then diff with our copy file" pass.
Read-only: it only calls the Figma REST API and reads the local JSON.

Usage:
    FIGMA_TOKEN=xxx scripts/figma_copy_diff.py \
        --file KWS5GTfRXvuteSXctOIrS1 --node 1910-19420

  --file   Figma file key (the KWS5... segment of the file URL)
  --node   Node id to walk (accepts 1910-19420 or 1910:19420)
  --json   Path to CopyStrings.json (defaults to the app's copy)
  --fuzzy  Similarity ratio for the "likely wording mismatch" bucket (default 0.72)

Get a personal access token at https://www.figma.com/developers/api#access-tokens
and export it as FIGMA_TOKEN.

Buckets reported:
  1. In Figma, missing from JSON   — board text with no JSON value
  2. Likely wording mismatch       — close-but-not-equal pairs (fuzzy)
  3. In JSON, not seen on the node — JSON values absent from the board

Caveat: this is a MECHANICAL diff. It can't distinguish product copy from
designer annotations, fixture/data values, or clipped text, so treat the output
as a review candidate list — not a verdict. For semantic grouping, feed the board
to the Figma MCP agent instead.
"""
import argparse
import difflib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_JSON = REPO / "Universal Search App" / "Content" / "CopyStrings.json"


def norm(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()


def fetch_node(file_key: str, node_id: str, token: str) -> dict:
    ids = node_id.replace(":", "-")
    url = f"https://api.figma.com/v1/files/{file_key}/nodes?ids={ids}"
    req = urllib.request.Request(url, headers={"X-Figma-Token": token})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"Figma API error {e.code}: {e.read().decode()[:300]}")
    except urllib.error.URLError as e:
        sys.exit(f"Network error reaching Figma: {e}")


def collect_text(node: dict, out: set) -> None:
    if not isinstance(node, dict):
        return
    if node.get("type") == "TEXT":
        chars = node.get("characters")
        if chars and chars.strip():
            out.add(norm(chars))
    for child in node.get("children") or []:
        collect_text(child, out)


def flatten_json(obj, out: set) -> None:
    if isinstance(obj, dict):
        for v in obj.values():
            flatten_json(v, out)
    elif isinstance(obj, list):
        for v in obj:
            flatten_json(v, out)
    elif isinstance(obj, str) and obj.strip():
        out.add(norm(obj))


def main() -> None:
    ap = argparse.ArgumentParser(description="Diff Figma node text against CopyStrings.json")
    ap.add_argument("--file", required=True, help="Figma file key")
    ap.add_argument("--node", required=True, help="Node id (1910-19420 or 1910:19420)")
    ap.add_argument("--json", default=str(DEFAULT_JSON), help="Path to CopyStrings.json")
    ap.add_argument("--fuzzy", type=float, default=0.72, help="Mismatch similarity threshold")
    args = ap.parse_args()

    token = os.environ.get("FIGMA_TOKEN")
    if not token:
        sys.exit("Set FIGMA_TOKEN (https://www.figma.com/developers/api#access-tokens).")

    data = fetch_node(args.file, args.node, token)
    figma: set = set()
    for wrap in data.get("nodes", {}).values():
        collect_text(wrap.get("document", {}), figma)
    if not figma:
        sys.exit("No TEXT nodes found — check the file key / node id.")

    jvals: set = set()
    flatten_json(json.loads(Path(args.json).read_text()), jvals)

    jlower = {v.lower(): v for v in jvals}
    flower = {v.lower() for v in figma}

    missing = sorted(v for v in figma if v.lower() not in jlower)
    json_only = sorted(v for v in jvals if v.lower() not in flower)

    # Fuzzy pass: for each "missing" Figma string, find the closest JSON value.
    mismatches = []
    still_missing = []
    json_lower_keys = list(jlower.keys())
    for f in missing:
        near = difflib.get_close_matches(f.lower(), json_lower_keys, n=1, cutoff=args.fuzzy)
        if near:
            mismatches.append((f, jlower[near[0]]))
        else:
            still_missing.append(f)
    matched_json = {j for _, j in mismatches}
    json_only = [j for j in json_only if j not in matched_json]

    print(f"# Figma node {args.node}: {len(figma)} board strings vs {len(jvals)} JSON values\n")

    print(f"## 1. In Figma, missing from JSON ({len(still_missing)})")
    for s in still_missing:
        print(f"  - {s!r}")

    print(f"\n## 2. Likely wording mismatch ({len(mismatches)})")
    for f, j in mismatches:
        print(f"  - Figma: {f!r}\n    JSON:  {j!r}")

    print(f"\n## 3. In JSON, not seen on this node ({len(json_only)})")
    for s in json_only:
        print(f"  - {s!r}")


if __name__ == "__main__":
    main()
