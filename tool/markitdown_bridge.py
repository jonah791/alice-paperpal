#!/usr/bin/env python3
"""
PaperPal ↔ MarkItDown Bridge

Converts various file formats to Markdown by calling Microsoft's MarkItDown library.
Used as a subprocess from Dart via Process.run.

Usage:
    python markitdown_bridge.py --input <file_path> [--type <format>] [--output <path>]

Formats: pdf, docx, pptx, xlsx, epub, html, image, audio, csv, json, xml, zip, youtube
If --type omitted, auto-detected from extension.

Output: Markdown text to stdout. Errors to stderr. Exit code 0 on success.
"""

import argparse
import json
import sys
import os
from pathlib import Path


def convert_file(file_path: str, file_type: str | None = None) -> str:
    """Convert a file to Markdown using MarkItDown."""
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")

    try:
        from markitdown import MarkItDown
    except ImportError:
        # Fallback: try to install
        print("MarkItDown not installed. Attempting install...", file=sys.stderr)
        import subprocess
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "markitdown"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        from markitdown import MarkItDown

    md = MarkItDown(enable_plugins=False)
    result = md.convert(str(path))
    return result.text_content


def main():
    parser = argparse.ArgumentParser(description="PaperPal MarkItDown Bridge")
    parser.add_argument("--input", required=True, help="Input file path")
    parser.add_argument("--type", help="File type override (pdf, docx, pptx, etc.)")
    parser.add_argument("--output", help="Optional output file path")
    parser.add_argument("--json", action="store_true", help="Output as JSON with metadata")
    args = parser.parse_args()

    try:
        markdown = convert_file(args.input, args.type)
    except ImportError as e:
        result = {"success": False, "error": f"MarkItDown unavailable: {e}", "markdown": ""}
        print(json.dumps(result) if args.json else result["error"])
        sys.exit(1)
    except FileNotFoundError as e:
        result = {"success": False, "error": str(e), "markdown": ""}
        print(json.dumps(result) if args.json else result["error"])
        sys.exit(1)
    except Exception as e:
        result = {"success": False, "error": str(e), "markdown": ""}
        print(json.dumps(result) if args.json else result["error"])
        sys.exit(1)

    if args.output:
        Path(args.output).write_text(markdown, encoding="utf-8")
        result = {"success": True, "output": args.output, "markdown": markdown, "length": len(markdown)}
    else:
        result = {"success": True, "markdown": markdown, "length": len(markdown)}

    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(markdown)


if __name__ == "__main__":
    main()
