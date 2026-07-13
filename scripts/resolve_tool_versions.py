#!/usr/bin/env python3
"""Resolve the newest release-like tag for each ECP5 toolchain component."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass(frozen=True)
class Tool:
    key: str
    display: str
    repo: str
    prefixes: tuple[str, ...]


TOOLS = (
    Tool("yosys", "Yosys", "https://github.com/YosysHQ/yosys.git", ("v", "yosys-")),
    Tool("prjtrellis", "Project Trellis", "https://github.com/YosysHQ/prjtrellis.git", ("v", "")),
    Tool("nextpnr", "nextpnr", "https://github.com/YosysHQ/nextpnr.git", ("nextpnr-", "v", "")),
    Tool("iverilog", "Icarus Verilog", "https://github.com/steveicarus/iverilog.git", ("v",)),
)


def run_git_ls_remote(repo: str) -> list[tuple[str, str]]:
    result = subprocess.run(
        ["git", "ls-remote", "--tags", repo],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    tags: dict[str, str] = {}
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        commit, ref = line.split(maxsplit=1)
        peeled = ref.endswith("^{}")
        if peeled:
            ref = ref[:-3]
        tag = ref.rsplit("/", 1)[-1]
        if peeled or tag not in tags:
            tags[tag] = commit
    return sorted(tags.items())


def normalize_for_version(tag: str, prefixes: tuple[str, ...]) -> str:
    for prefix in sorted(prefixes, key=len, reverse=True):
        if prefix and tag.startswith(prefix):
            return tag[len(prefix) :]
    return tag


def version_key(tag: str, prefixes: tuple[str, ...]) -> tuple[tuple[int, ...], int, str] | None:
    if "" not in prefixes and not any(tag.startswith(prefix) for prefix in prefixes):
        return None
    normalized = normalize_for_version(tag, prefixes).replace("_", ".")
    match = re.search(r"\d+(?:\.\d+)*", normalized)
    if not match:
        return None
    numbers = tuple(int(part) for part in match.group(0).split("."))
    suffix = normalized[match.end() :].lower()
    is_final = 0 if re.search(r"(alpha|beta|pre|rc|dev)", suffix) else 1
    return numbers, is_final, tag


def select_latest(tool: Tool) -> dict[str, str]:
    candidates = []
    for tag, commit in run_git_ls_remote(tool.repo):
        key = version_key(tag, tool.prefixes)
        if key is not None:
            candidates.append((key, tag, commit))
    if not candidates:
        raise RuntimeError(f"No version-like tags found for {tool.display}: {tool.repo}")
    _key, tag, commit = max(candidates, key=lambda item: item[0])
    return {
        "key": tool.key,
        "display": tool.display,
        "repo": tool.repo,
        "tag": tag,
        "commit": commit,
        "tag_url": tool.repo.removesuffix(".git").replace("https://github.com/", "https://github.com/")
        + f"/releases/tag/{tag}",
    }


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def write_env(path: Path, selected: list[dict[str, str]], release_tag: str, asset_basename: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for item in selected:
            prefix = item["key"].upper()
            handle.write(f"{prefix}_REPO={shell_quote(item['repo'])}\n")
            handle.write(f"{prefix}_TAG={shell_quote(item['tag'])}\n")
            handle.write(f"{prefix}_COMMIT={shell_quote(item['commit'])}\n")
        handle.write(f"RELEASE_TAG={shell_quote(release_tag)}\n")
        handle.write(f"ASSET_BASENAME={shell_quote(asset_basename)}\n")


def write_markdown(path: Path, selected: list[dict[str, str]], generated_at: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write("## Source versions\n\n")
        handle.write(f"Resolved at: `{generated_at}`\n\n")
        for item in selected:
            short_commit = item["commit"][:12]
            handle.write(
                f"- {item['display']}: [`{item['tag']}`]({item['tag_url']}) "
                f"(`{short_commit}`)\n"
            )


def append_github_output(path: str | None, outputs: dict[str, str]) -> None:
    if not path:
        return
    with open(path, "a", encoding="utf-8", newline="\n") as handle:
        for key, value in outputs.items():
            handle.write(f"{key}={value}\n")


def sanitize_tag_part(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", required=True)
    parser.add_argument("--json-file", required=True)
    parser.add_argument("--markdown-file", required=True)
    parser.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"))
    args = parser.parse_args()

    selected = [select_latest(tool) for tool in TOOLS]
    tag_parts = [f"{item['key']}-{sanitize_tag_part(item['tag'])}" for item in selected]
    release_tag = "ecp5-toolchain-" + "-".join(tag_parts)
    asset_basename = "ecp5-toolchain-linux-x86_64"
    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()

    Path(args.json_file).parent.mkdir(parents=True, exist_ok=True)
    with Path(args.json_file).open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(
            {
                "generated_at": generated_at,
                "release_tag": release_tag,
                "asset_basename": asset_basename,
                "tools": selected,
            },
            handle,
            indent=2,
            sort_keys=True,
        )
        handle.write("\n")

    write_env(Path(args.env_file), selected, release_tag, asset_basename)
    write_markdown(Path(args.markdown_file), selected, generated_at)
    append_github_output(
        args.github_output,
        {
            "release_tag": release_tag,
            "release_name": f"ECP5 toolchain {release_tag.removeprefix('ecp5-toolchain-')}",
            "asset_basename": asset_basename,
        },
    )

    for item in selected:
        print(f"{item['display']}: {item['tag']} ({item['commit'][:12]})")
    print(f"Release tag: {release_tag}")


if __name__ == "__main__":
    main()
