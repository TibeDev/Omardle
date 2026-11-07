#!/usr/bin/env python3
"""Bundle a validated five-letter word list from its MIT-licensed source."""

import json
import re
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_URL = "https://raw.githubusercontent.com/darkermango/5-Letter-words/main/"
MAX_WORDS_BYTES = 256 * 1024


def download(name: str, limit: int) -> bytes:
    request = urllib.request.Request(
        BASE_URL + name,
        headers={"User-Agent": "OmarchyWordle/1.0"},
    )
    with urllib.request.urlopen(request, timeout=8) as response:
        if response.status != 200:
            raise RuntimeError(f"Unexpected HTTP status for {name}: {response.status}")
        data = response.read(limit + 1)
    if len(data) > limit:
        raise RuntimeError(f"{name} exceeded {limit} bytes")
    return data


def main() -> None:
    raw_words = download("words.txt", MAX_WORDS_BYTES).decode("utf-8")
    words = sorted(
        {
            word
            for word in raw_words.splitlines()
            if re.fullmatch(r"[a-z]{5}", word)
        }
    )
    if not words or len(words) > 10000:
        raise RuntimeError("Downloaded word list failed validation")

    encoded_words = json.dumps(" ".join(words), separators=(",", ":"))
    (ROOT / "Dictionary.js").write_text(
        "var WORD_LIST = " + encoded_words + ".split(" + json.dumps(" ") + ");\n"
        "function isValidGuess(word) {\n"
        "    var value = String(word || \"\").toLowerCase();\n"
        "    return /^[a-z]{5}$/.test(value) && WORD_LIST.indexOf(value) !== -1;\n"
        "}\n",
        encoding="utf-8",
    )
    print(f"Bundled {len(words)} five-letter words.")


if __name__ == "__main__":
    main()
