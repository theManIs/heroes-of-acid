"""Текстура земли через fal.ai (FLUX), вид сверху.

usage: python3 -I pipelines/ground-fal/generate.py <name> <seed> "<prompt>" [gpt]
gpt: модель OpenAI fal-ai/gpt-image-1.5 вместо FLUX, seed она не принимает.
Ключ FAL_KEY берётся из .env и никуда не печатается. Результат: ground/generations/<name>/raw.png и request.json.
"""
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ENDPOINT = "fal-ai/flux/dev"
ENDPOINT_GPT = "fal-ai/gpt-image-1.5"
SIZE = 1024


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
    name, seed, prompt = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    out = Path("ground/generations") / name
    out.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) > 4 and sys.argv[4] == "gpt":
        endpoint = ENDPOINT_GPT
        body = {"prompt": prompt, "image_size": f"{SIZE}x{SIZE}", "quality": "high", "num_images": 1, "output_format": "png"}
    else:
        endpoint = ENDPOINT
        body = {"prompt": prompt, "image_size": {"width": SIZE, "height": SIZE}, "num_inference_steps": 28, "guidance_scale": 3.5,
                "seed": seed, "output_format": "png", "enable_safety_checker": False}
    (out / "request.json").write_text(json.dumps({"endpoint": endpoint, **body}, ensure_ascii=False, indent=2) + "\n")
    job = call("POST", f"https://queue.fal.run/{endpoint}", body)
    t0 = time.time()
    while call("GET", job["status_url"]).get("status") != "COMPLETED":
        if time.time() - t0 > 300:
            raise SystemExit("timeout")
        time.sleep(3)
    result = call("GET", job["response_url"])
    with urllib.request.urlopen(result["images"][0]["url"], timeout=120) as r:
        (out / "raw.png").write_bytes(r.read())
    print(out / "raw.png", f"{time.time() - t0:.0f}s")


main()
