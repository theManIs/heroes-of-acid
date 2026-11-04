"""Концепт четвероногого существа через fal.ai (gpt-image).

usage: python3 -I pipelines/creature-quadruped/concept.py <id> <name> "<prompt>"
Ключ FAL_KEY берётся из .env и никуда не печатается. Результат: creatures/<id>/concept/<name>.png и <name>.json.
"""
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ENDPOINT = "fal-ai/gpt-image-1.5"


def key() -> str:
    for line in Path(".env").read_text().splitlines():
        if line.startswith("FAL_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit("FAL_KEY not found in .env")


def call(method: str, url: str, body: dict = None) -> dict:
    req = urllib.request.Request(url, method=method, headers={"Authorization": "Key " + key(), "Content-Type": "application/json"},
                                 data=json.dumps(body).encode() if body is not None else None)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        raise SystemExit(f"HTTP {e.code}: {e.read()[:500].decode(errors='ignore')}")


def main() -> None:
    creature, name, prompt = sys.argv[1:4]
    out = Path("creatures") / creature / "concept"
    out.mkdir(parents=True, exist_ok=True)
    body = {"prompt": prompt, "image_size": "1536x1024", "quality": "high", "num_images": 1, "output_format": "png"}
    (out / f"{name}.json").write_text(json.dumps({"endpoint": ENDPOINT, **body}, ensure_ascii=False, indent=2) + "\n")
    job = call("POST", f"https://queue.fal.run/{ENDPOINT}", body)
    t0 = time.time()
    while call("GET", job["status_url"]).get("status") != "COMPLETED":
        if time.time() - t0 > 300:
            raise SystemExit("timeout")
        time.sleep(3)
    result = call("GET", job["response_url"])
    with urllib.request.urlopen(result["images"][0]["url"], timeout=120) as r:
        (out / f"{name}.png").write_bytes(r.read())
    print(out / f"{name}.png", f"{time.time() - t0:.0f}s")


main()
