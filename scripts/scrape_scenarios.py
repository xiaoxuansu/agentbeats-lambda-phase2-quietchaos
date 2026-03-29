#!/usr/bin/env python3
"""
Scrape scenario data from the AgentBeats S3 index page.

Parses the HTML to extract (category, name, description, folder) for all 424
scenarios and writes them to classifier_data/scenarios.json.

Usage:
    python scripts/scrape_scenarios.py
"""

import json
import re
import urllib.request
from pathlib import Path

INDEX_URL = "https://agentbeats-lambda.s3.us-east-1.amazonaws.com/index.html"
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "scenarios" / "security_arena" / "agents" / "attacker" / "classifier_data"


def fetch_index_html(url: str) -> str:
    with urllib.request.urlopen(url) as resp:
        return resp.read().decode("utf-8")


def parse_scenarios(html: str) -> list[dict]:
    """
    Each scenario card is an <a> tag with data attributes:
      <a href="./folder/index.html" class="scenario-card"
         data-attack-type="indirect_injection"
         data-name="AgriAttack"
         data-description="...">
    """
    import html as html_mod

    card_pattern = re.compile(
        r'<a\s+href="\./([^/]+)/index\.html"\s+class="scenario-card"'
        r'\s+data-attack-type="([^"]+)"'
        r'\s+data-name="([^"]+)"'
        r'\s+data-description="([^"]*)"',
        re.DOTALL,
    )

    scenarios = []
    for m in card_pattern.finditer(html):
        folder = m.group(1)
        category = m.group(2).strip()
        name = m.group(3).strip()
        description = html_mod.unescape(m.group(4)).strip()

        scenarios.append({
            "category": category,
            "name": name,
            "description": description,
            "folder": folder,
        })

    return scenarios


def main():
    print(f"Fetching index page from {INDEX_URL} ...")
    html = fetch_index_html(INDEX_URL)
    print(f"Fetched {len(html)} bytes")

    scenarios = parse_scenarios(html)
    print(f"Parsed {len(scenarios)} scenarios")

    # Print category distribution
    from collections import Counter
    dist = Counter(s["category"] for s in scenarios)
    for cat, count in dist.most_common():
        print(f"  {cat}: {count}")

    # Write output
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUTPUT_DIR / "scenarios.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(scenarios, f, indent=2, ensure_ascii=False)
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
