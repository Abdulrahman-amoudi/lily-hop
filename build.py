#!/usr/bin/env python3
"""Builds the single-file index.html: embeds every sfx/*.mp3 as a data URI."""
import base64, json, pathlib
root = pathlib.Path(__file__).parent
data = {p.stem: "data:audio/mpeg;base64," + base64.b64encode(p.read_bytes()).decode() for p in sorted((root / "sfx").glob("*.mp3"))}
src = (root / "index.src.html").read_text()
assert "/*SFX*/{}" in src
(root / "index.html").write_text(src.replace("/*SFX*/{}", json.dumps(data)))
print("built index.html with", len(data), "sounds")
