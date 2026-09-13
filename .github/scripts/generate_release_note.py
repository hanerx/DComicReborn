import argparse
import html
import re
import subprocess
from pathlib import Path
from urllib.parse import quote


def git(*args, required=True):
    result = subprocess.run(
        ["git", *args], capture_output=True, text=True, encoding="utf-8"
    )
    if result.returncode:
        if required:
            raise ValueError(result.stderr.strip())
        return None
    return result.stdout.strip()


def version_notes(markdown, tag):
    sections = []
    current = None
    fence = None
    for line in markdown.splitlines():
        marker = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line)
        if fence is not None:
            if (marker and marker[1][0] == fence[0]
                    and len(marker[1]) >= fence[1] and not marker[2].strip()):
                fence = None
        elif marker:
            fence = (marker[1][0], len(marker[1]))
        else:
            heading = re.match(r"^#\s+(.+?)\s*#*\s*$", line)
            if heading:
                current = []
                sections.append((heading[1].removeprefix("v"), current))
                continue
        if current is not None:
            current.append(line)

    matches = ["\n".join(lines).strip() for version, lines in sections
               if version == tag.removeprefix("v")]
    if len(matches) != 1 or not matches[0]:
        raise ValueError(
            f"Release notes for {tag} must contain exactly one non-empty "
            f"'# {tag.removeprefix('v')}' section."
        )
    return matches[0]


def generate(tag, repository, notes):
    if git("rev-parse", "--is-shallow-repository") == "true":
        raise ValueError("Release history is shallow; use checkout fetch-depth: 0.")
    current_ref = f"refs/tags/{tag}"
    git("rev-parse", "--verify", f"{current_ref}^{{commit}}")
    highlights = version_notes(notes, tag)
    previous = git("describe", "--tags", "--abbrev=0", f"{current_ref}^",
                   required=False)
    revision = f"refs/tags/{previous}..{current_ref}" if previous else current_ref
    history = git("log", "--no-merges", "--encoding=UTF-8",
                  "--format=%H%x00%s%x00%an", revision, "--")
    commits = [line.split("\0") for line in history.splitlines()] if history else []
    repository_url = f"https://github.com/{repository}"
    lines = [highlights, "", "---", "", "## 自动生成的变更记录", ""]
    if previous:
        lines.append(f"从 `{previous}` 到 `{tag}`，共 {len(commits)} 条非合并提交。")
    else:
        lines.append(f"首次发布，共 {len(commits)} 条非合并提交。")
    lines.append("")
    for sha, subject, author in commits:
        lines.append(
            f"- {html.escape(subject, quote=False)} "
            f"([`{sha[:7]}`]({repository_url}/commit/{sha})) "
            f"— {html.escape(author, quote=False)}"
        )
    if not commits:
        lines.append("本版本没有新增的非合并提交。")
    if previous:
        comparison = f"{quote(previous, safe='')}...{quote(tag, safe='')}"
        lines.extend(["", f"[完整版本对比]({repository_url}/compare/{comparison})"])
    else:
        lines.extend(["", f"[完整提交历史]({repository_url}/commits/{quote(tag, safe='')})"])
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(
        description="Combine version highlights with the full tagged commit interval."
    )
    parser.add_argument("--tag", required=True)
    parser.add_argument("--repository", required=True, help="GitHub owner/repository")
    parser.add_argument("--notes", type=Path, default=Path("RELEASE_NOTES.md"))
    parser.add_argument("--output", type=Path, default=Path("release-note.md"))
    args = parser.parse_args()
    try:
        body = generate(args.tag, args.repository, args.notes.read_text(encoding="utf-8"))
        args.output.write_text(body, encoding="utf-8")
    except (OSError, ValueError) as error:
        parser.exit(1, f"Release note generation failed: {error}\n")
    print(f"Generated release notes for {args.tag}: {args.output}")


if __name__ == "__main__":
    main()
