#!/usr/bin/env python3
"""Discover and execute every top-level test_ function in tests/test_*.mojo."""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mojo", default="mojo")
    args = parser.parse_args()
    imports = []
    calls = []
    for path in sorted((ROOT / "tests").glob("test_*.mojo")):
        names = re.findall(r"^def (test_\w+)\(", path.read_text(), re.M)
        if not names:
            raise SystemExit(f"No tests discovered in {path}")
        for name in names:
            alias = f"test_{len(calls)}"
            imports.append(f"from tests.{path.stem} import {name} as {alias}")
            calls.append((alias, f"{path.stem}.{name}"))
    if not calls:
        raise SystemExit("No tests discovered")
    source = imports + ["", "def main() raises:", "    var failed = 0"]
    for alias, name in calls:
        source += [
            "    try:",
            f"        {alias}()",
            "    except e:",
            "        failed += 1",
            f'        print("FAIL {name}:", e)',
        ]
    source += [
        f'    print("Executed {len(calls)} tests; failures:", failed)',
        "    if failed:",
        '        raise Error("Regex tests failed")',
        "",
    ]
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    runner = build / "test_runner.mojo"
    runner.write_text("\n".join(source))
    print(f"Running {len(calls)} tests", flush=True)
    subprocess.run(
        [args.mojo, "run", "-I", str(ROOT), str(runner)], cwd=ROOT, check=True
    )


if __name__ == "__main__":
    main()
