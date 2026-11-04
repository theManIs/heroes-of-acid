"""Статичная модель преграды через fal.ai (Meshy-6).

usage: python3 -I pipelines/obstacle-fal/generate.py <name> "<prompt>"
Ключ FAL_KEY берётся из .env и никуда не печатается. Результат: obstacles/generations/<name>/model.glb, request.json, result.json.
"""
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ENDPOINT = "fal-ai/meshy/v6/text-to-3d"


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
    name, prompt = sys.argv[1], sys.argv[2]
    out = Path("obstacles/generations") / name
    out.mkdir(parents=True, exist_ok=True)
    body = {"prompt": prompt, "mode": "full"}
    (out / "request.json").write_text(json.dumps({"endpoint": ENDPOINT, **body}, ensure_ascii=False, indent=2) + "\n")
    job = call("POST", f"https://queue.fal.run/{ENDPOINT}", body)
    t0 = time.time()
    while call("GET", job["status_url"]).get("status") != "COMPLETED":
        if time.time() - t0 > 900:
            raise SystemExit("timeout")
        time.sleep(10)
    result = call("GET", job["response_url"])
    (out / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    glb = result.get("model_glb", {}).get("url") or result.get("model_urls", {}).get("glb", {}).get("url")
    if not glb:
        raise SystemExit("no glb in result: " + ", ".join(result.keys()))
    with urllib.request.urlopen(glb, timeout=300) as r:
        (out / "model.glb").write_bytes(r.read())
    print(out / "model.glb", f"{time.time() - t0:.0f}s")


main()
