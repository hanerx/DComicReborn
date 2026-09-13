import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("generate_release_note.py").resolve()


class ReleaseNoteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / "repo"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Release Tester")
        self.git("config", "user.email", "release@example.invalid")
        self.commit("old release content")
        self.git("tag", "1.0.0")

    def git(self, *args):
        return subprocess.run(
            ["git", *args], cwd=self.repo, check=True,
            capture_output=True, text=True, encoding="utf-8",
        ).stdout.strip()

    def commit(self, message):
        self.git("commit", "--allow-empty", "-qm", message)

    def generate(self, notes, tag="2.0.0"):
        (self.repo / "RELEASE_NOTES.md").write_text(notes, encoding="utf-8")
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--tag", tag,
             "--repository", "example/comic"],
            cwd=self.repo, capture_output=True, text=True, encoding="utf-8",
        )
        output = self.repo / "release-note.md"
        return result, output.read_text(encoding="utf-8") if output.exists() else ""

    def test_release_includes_exact_notes_and_entire_tag_interval(self):
        self.commit("feat: first feature")
        self.commit("fix: second fix")
        self.git("tag", "v2.0.0")
        self.commit("not released yet")
        result, body = self.generate(
            "# 2.0.1\nWrong future notes\n# 2.0.0\n"
            "## 亮点\n保留手写的说明。\n## 寄语\n谢谢支持。\n"
            "```markdown\n# 1.0.0\n代码块不是版本边界\n```\n"
            "# 1.0.0\nWrong old notes\n", "v2.0.0",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("## 亮点\n保留手写的说明。", body)
        self.assertIn("## 寄语\n谢谢支持。", body)
        self.assertIn("# 1.0.0\n代码块不是版本边界", body)
        self.assertIn("feat: first feature", body)
        self.assertIn("fix: second fix", body)
        self.assertIn("/compare/1.0.0...v2.0.0", body)
        self.assertIn("/commit/", body)
        for excluded in ["Wrong future notes", "Wrong old notes",
                         "old release content", "not released yet"]:
            self.assertNotIn(excluded, body)

    def test_missing_empty_or_duplicate_version_is_an_error(self):
        self.git("tag", "2.0.0")
        for notes in ["# 2.0.1\nWrong version\n", "# 2.0.0\n\n",
                      "# 2.0.0\nFirst\n# v2.0.0\nDuplicate\n"]:
            with self.subTest(notes=notes):
                result, body = self.generate(notes)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("2.0.0", result.stderr)
                self.assertEqual(body, "")

    def test_first_release_includes_history_without_previous_tag(self):
        result, body = self.generate("# 1.0.0\nInitial highlights\n", "1.0.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Initial highlights", body)
        self.assertIn("old release content", body)
        self.assertIn("/commits/1.0.0", body)
        self.assertNotIn("/compare/", body)

    def test_shallow_checkout_cannot_silently_truncate_release_history(self):
        self.commit("feat: first feature")
        self.commit("fix: second fix")
        self.git("tag", "2.0.0")
        shallow = Path(self.temp.name) / "shallow"
        self.git("clone", "--quiet", "--depth", "1", "--branch", "2.0.0",
                 self.repo.as_uri(), str(shallow))
        self.repo = shallow
        result, body = self.generate("# 2.0.0\nHighlights\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fetch-depth: 0", result.stderr)
        self.assertEqual(body, "")


if __name__ == "__main__":
    unittest.main()
