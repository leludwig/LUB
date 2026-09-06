"""Compile all modules and run behavior tests with an installed Luau CLI."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from build import ROOT, build, source_table


def lua(value):
    if isinstance(value, dict):
        return "{" + ",".join(f"[{json.dumps(k)}]={lua(v)}" for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(map(lua, value)) + "}"
    return json.dumps(value, ensure_ascii=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau-dir", type=Path, default=ROOT / ".tools" / "luau")
    args = parser.parse_args()
    suffix = ".exe" if (args.luau_dir / "luau.exe").exists() else ""
    compiler = args.luau_dir / f"luau-compile{suffix}"
    runtime = args.luau_dir / f"luau{suffix}"
    assert (ROOT / "LUB.lua").read_text(encoding="utf-8") == build(), "Run tools/build.py to update LUB.lua"
    files = sorted((ROOT / "src").rglob("*.lua")) + [ROOT / "LUB.lua"]
    for path in files:
        result = subprocess.run([str(compiler), "--null", str(path)], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(f"{path}: {result.stderr}")
    print(f"Compiled {len(files)} Luau files", flush=True)
    games = json.loads((ROOT / "src/gameslist.json").read_text(encoding="utf-8"))
    runner = "local SOURCES = " + source_table() + "\nlocal GAME_LIST = " + lua(games) + "\n"
    runner += (ROOT / "tests/test_lub.luau").read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="lub-tests-") as directory:
        path = Path(directory) / "run.luau"
        path.write_text(runner, encoding="utf-8", newline="\n")
        subprocess.run([str(runtime), str(path)], check=True)


if __name__ == "__main__":
    main()
