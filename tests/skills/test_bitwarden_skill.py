"""Tests for the optional-skills/security/bitwarden skill.

Covers skill structure (frontmatter, file layout, script validity) without
any live `bw` calls or network access.
"""
import re
from pathlib import Path

import pytest
import hermes_yaml as yaml

REPO = Path(__file__).resolve().parents[2]
SKILL_DIR = REPO / "optional-skills" / "security" / "bitwarden"
SKILL_MD = SKILL_DIR / "SKILL.md"
SCRIPT = SKILL_DIR / "scripts" / "bw-unlock.sh"


def _frontmatter():
    content = SKILL_MD.read_text(encoding="utf-8")
    assert content.startswith("---"), "SKILL.md must start with ---"
    m = re.search(r"\n---\s*\n", content[3:])
    assert m, "unclosed frontmatter"
    fm = yaml.safe_load(content[3 : m.start() + 3])
    return fm, content


def test_skill_file_exists():
    assert SKILL_MD.is_file(), "SKILL.md must exist"


def test_frontmatter_required_fields():
    fm, _ = _frontmatter()
    for field in ("name", "description", "version", "author", "license", "platforms"):
        assert field in fm, f"missing frontmatter field: {field}"
    assert fm["name"] == "bitwarden"
    assert fm["platforms"] == ["linux", "macos", "windows"]


def test_description_hardline():
    fm, _ = _frontmatter()
    desc = str(fm.get("description") or "")
    assert len(desc) <= 60, f"description {len(desc)} chars (hardline 60)"
    assert desc.rstrip().endswith("."), "description must end with period"
    assert not re.search(
        r"\b(powerful|comprehensive|seamless|revolutionary|cutting-edge)\b",
        desc,
        re.IGNORECASE,
    ), "description contains marketing word"


def test_prerequisites_command():
    fm, _ = _frontmatter()
    prereqs = fm.get("prerequisites") or {}
    assert "bw" in (prereqs.get("commands") or []), "bw CLI must be a prerequisite"


def test_related_skills_resolve():
    fm, _ = _frontmatter()
    hermes = (fm.get("metadata") or {}).get("hermes") or {}
    for rs in hermes.get("related_skills") or []:
        related = REPO / "optional-skills" / "security" / rs / "SKILL.md"
        assert related.exists(), f"related_skills entry does not resolve in-repo: {rs}"


def test_no_machine_local_paths():
    _, content = _frontmatter()
    assert not re.search(r"/home/(?!runner\b)[a-z0-9_-]+/", content), "machine-local path found"
    assert not re.search(r"[A-Z]:\\\\+Users\\+", content), "machine-local Windows path found"


def test_references_exist():
    _, content = _frontmatter()
    refs = re.findall(r"references/([A-Za-z0-9_-]+)\.md", content)
    for ref in refs:
        path = SKILL_DIR / "references" / f"{ref}.md"
        assert path.is_file(), f"referenced file missing: references/{ref}.md"


def test_script_exists_and_is_bash():
    assert SCRIPT.is_file(), "bw-unlock.sh helper must exist"
    text = SCRIPT.read_text(encoding="utf-8")
    assert text.startswith("#!/usr/bin/env bash"), "script must be a bash script"
    # bash syntax check (no network, no execution)
    import subprocess
    import sys
    result = subprocess.run(
        [sys.executable, "-c", "import shutil; print(shutil.which('bash'))"],
        capture_output=True, text=True, check=True,
    )
    bash = result.stdout.strip()
    if bash:
        check = subprocess.run([bash, "-n", str(SCRIPT)], check=False, capture_output=True, text=True)
        assert check.returncode == 0, f"bash syntax error in bw-unlock.sh:\n{check.stderr}"


def test_unlock_pattern_documented():
    """The non-interactive unlock pattern must be present in the skill body."""
    _, content = _frontmatter()
    assert "BW_SESSION" in content, "BW_SESSION must be documented"
    assert "--passwordenv" in content, "non-interactive unlock via --passwordenv must be documented"
