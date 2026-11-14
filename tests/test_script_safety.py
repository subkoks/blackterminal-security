"""Harmless script regressions using only Python's standard library and Git."""

import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest


SOURCE = Path(__file__).resolve().parents[1]
NAMES = ["plain.py", "with space.py", "with\ttab.py", 'with"quote.py',
         "with\\slash.py", "with\nnewline.py", "ends-in-newline.py\n"]


class ScriptSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="script-safety-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.home = self.root / "home"
        self.home.mkdir()
        # Child processes see only a disposable home and Git configuration.
        self.environment = dict(os.environ)
        for name in list(self.environment):
            if name.startswith("GIT_"):
                del self.environment[name]
        self.environment.update(HOME=str(self.home), GIT_CONFIG_NOSYSTEM="1",
                                GIT_CONFIG_GLOBAL=os.devnull)
        self.run_command("git", "init", "--quiet")

    def run_command(self, *arguments, expected=0):
        result = subprocess.run(arguments, cwd=self.repo, env=self.environment,
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def copy_script(self, relative):
        destination = self.repo / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SOURCE / relative, destination)
        return destination

    def test_scanner_preserves_directory_filenames(self):
        scanner = self.copy_script("scripts/scan.sh")
        fixtures = self.repo / "fixtures"
        fixtures.mkdir()
        # All contents are harmless. Test each name so a skipped file cannot
        # be hidden by a correct aggregate count from other fixtures.
        for name in NAMES[:-1]:  # Directory scans retain the extension allowlist.
            with self.subTest(name=name):
                fixture = fixtures / name
                fixture.write_text("# harmless fixture\n")
                result = self.run_command("bash", str(scanner), str(fixtures))
                self.assertIn("Files:  1\n", result.stdout)
                self.assertNotIn("No such file", result.stderr)
                fixture.unlink()

    def test_scanner_checks_find_status_before_consuming_output(self):
        scanner = self.copy_script("scripts/scan.sh")
        fixtures = self.repo / "fixtures"
        fixtures.mkdir()
        fixture = fixtures / "with\nnewline.py"
        fixture.write_text("# harmless fixture\n")
        stub_directory = self.root / "bin"
        stub_directory.mkdir()
        find_stub = stub_directory / "find"
        find_stub.write_text('#!/usr/bin/env bash\n'
                             'if [ "$FIND_STUB_OUTPUT" = partial ]; then\n'
                             '  printf "%s\\0unfinished" "$FIND_STUB_PATH"\n'
                             'fi\n'
                             'if [ "$FIND_STUB_STATUS" != 0 ]; then\n'
                             '  echo "synthetic discovery failure" >&2\n'
                             'fi\n'
                             'exit "$FIND_STUB_STATUS"\n')
        find_stub.chmod(0o755)
        self.environment.update(FIND_STUB_PATH=str(fixture), TMPDIR=str(self.root))
        self.environment["PATH"] = str(stub_directory) + os.pathsep + os.environ["PATH"]
        for output, status in (("empty", "23"), ("partial", "23"), ("empty", "0")):
            with self.subTest(output=output, status=status):
                self.environment.update(FIND_STUB_OUTPUT=output, FIND_STUB_STATUS=status)
                expected = 0 if status == "0" else 2
                result = self.run_command("bash", str(scanner), str(fixtures), expected=expected)
                if expected:
                    self.assertIn("synthetic discovery failure", result.stderr)
                    self.assertIn("scan incomplete", result.stderr)
                    self.assertNotIn("Files:", result.stdout)
                    self.assertNotIn("No findings.", result.stdout)
                else:
                    self.assertIn("No scannable files found", result.stdout)
                self.assertEqual(list(self.root.glob("blackterminal-scan.*")), [])

    def test_hook_passes_exact_paths_and_retains_failure(self):
        hook = self.copy_script("hooks/pre-commit")
        scanner = self.repo / "scripts/scan.sh"
        scanner.parent.mkdir()
        scanner.write_text('#!/usr/bin/env bash\n'
                           'printf "%s\\0" "$1" >> "$SCAN_LOG"\n'
                           '[ "${SCAN_FAIL:-0}" = 0 ]\n')
        scanner.chmod(0o755)
        for name in NAMES:
            (self.repo / name).write_text("# harmless fixture\n")
            self.run_command("git", "add", "--", name)
        log = self.root / "scan-log"
        self.environment["SCAN_LOG"] = str(log)
        expected_paths = {os.fsencode(self.repo / name) for name in NAMES}
        for fail in ("0", "1"):
            with self.subTest(failure=fail):
                log.write_bytes(b"")
                self.environment["SCAN_FAIL"] = fail
                self.run_command("bash", str(hook), expected=int(fail))
                paths = log.read_bytes().split(b"\0")[:-1]
                self.assertEqual(set(paths), expected_paths)
                self.assertEqual(len(paths), len(NAMES))

    def test_hook_checks_git_status_before_consuming_output(self):
        hook = self.copy_script("hooks/pre-commit")
        scanner = self.repo / "scripts/scan.sh"
        scanner.parent.mkdir()
        scanner.write_text('#!/usr/bin/env bash\n'
                           'printf "called\\n" >> "$SCAN_LOG"\n')
        scanner.chmod(0o755)
        (self.repo / "plain.py").write_text("# harmless fixture\n")
        stub_directory = self.root / "bin"
        stub_directory.mkdir()
        git_stub = stub_directory / "git"
        git_stub.write_text('#!/usr/bin/env bash\n'
                            'if [ "$1" = diff ]; then\n'
                            '  if [ "$GIT_STUB_OUTPUT" = partial ]; then\n'
                            '    printf "plain.py\\0unfinished"\n'
                            '  fi\n'
                            '  exit "$GIT_STUB_STATUS"\n'
                            'fi\n'
                            'exec "$REAL_GIT" "$@"\n')
        git_stub.chmod(0o755)
        log = self.root / "scan-log"
        self.environment.update(REAL_GIT=shutil.which("git"), SCAN_LOG=str(log),
                                TMPDIR=str(self.root))
        self.environment["PATH"] = str(stub_directory) + os.pathsep + os.environ["PATH"]
        for output, status in (("empty", "23"), ("partial", "23"), ("empty", "0")):
            with self.subTest(output=output, status=status):
                self.environment.update(GIT_STUB_OUTPUT=output, GIT_STUB_STATUS=status)
                expected = 0 if status == "0" else 1
                result = self.run_command("bash", str(hook), expected=expected)
                if expected:
                    self.assertIn("unable to list staged files", result.stderr)
                self.assertFalse(log.exists(), "Git output consumed before status check")
                self.assertEqual(list(self.root.glob("blackterminal-staged.*")), [])

    def test_sigterm_cleans_scanner_and_hook_lists(self):
        scanner = self.copy_script("scripts/scan.sh")
        hook = self.copy_script("hooks/pre-commit")
        stub_directory = self.root / "bin"
        stub_directory.mkdir()
        ready = self.root / "ready"
        self.environment.update(REAL_GIT=shutil.which("git"), READY_FILE=str(ready),
                                TMPDIR=str(self.root))
        self.environment["PATH"] = str(stub_directory) + os.pathsep + os.environ["PATH"]
        # Pause the harmless discovery child until the test releases stdin.
        # Signal only the exact parent process created below, never a group.
        for name in ("find", "git"):
            stub = stub_directory / name
            forwarding = ('if [ "$1" != diff ]; then exec "$REAL_GIT" "$@"; fi\n'
                          if name == "git" else "")
            stub.write_text('#!/usr/bin/env bash\n' + forwarding
                            + 'printf "ready\\n" > "$READY_FILE"\n'
                            + 'IFS= read -r release\n')
            stub.chmod(0o755)
        for script, arguments, prefix in (
                (scanner, [str(self.repo)], "blackterminal-scan."),
                (hook, [], "blackterminal-staged.")):
            with self.subTest(script=script.name):
                process = subprocess.Popen(["bash", str(script), *arguments],
                                           cwd=self.repo, env=self.environment,
                                           stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                           stderr=subprocess.PIPE, text=True)
                try:
                    deadline = time.monotonic() + 5
                    while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertTrue(ready.exists(), "Discovery stub did not become ready")
                    self.assertEqual(len(list(self.root.glob(prefix + "*"))), 1)
                    process.send_signal(signal.SIGTERM)
                    # Bash may defer signal handling until its foreground child
                    # exits. Release that child so the shell can finish cleanup.
                    stdout, stderr = process.communicate(input="release\n", timeout=5)
                    self.assertNotEqual(process.returncode, 0, stdout + stderr)
                    self.assertEqual(list(self.root.glob(prefix + "*")), [])
                    print(f"SIGTERM {script.relative_to(self.repo)}: "
                          f"exit={process.returncode}, temporary list removed")
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.communicate(input="release\n", timeout=5)
                    ready.unlink(missing_ok=True)

    def prepare_installer(self):
        self.copy_script("install.sh")
        self.copy_script("hooks/pre-commit")
        return self.repo / ".git/hooks/pre-commit"

    def test_install_missing_and_identical_hook(self):
        hook = self.prepare_installer()
        self.run_command("bash", "install.sh", "--with-hooks", "--dry-run")
        self.assertFalse(hook.exists())
        self.run_command("bash", "install.sh", "--with-hooks")
        self.assertEqual(hook.read_bytes(), (SOURCE / "hooks/pre-commit").read_bytes())
        self.assertTrue(os.access(hook, os.X_OK))
        before = hook.stat()
        self.run_command("bash", "install.sh", "--with-hooks")
        self.assertEqual(before, hook.stat())

        hook.chmod(0o640)
        before = hook.stat()
        for flags in ((), ("--dry-run",)):
            result = self.run_command("bash", "install.sh", "--with-hooks", *flags, expected=1)
            self.assertIn("is not executable", result.stderr)
        after = hook.stat()
        self.assertEqual((before.st_mode, before.st_mtime_ns, before.st_ino),
                         (after.st_mode, after.st_mtime_ns, after.st_ino))

    def test_install_preserves_conflicting_objects(self):
        hook = self.prepare_installer()
        target = self.root / "existing-hook"
        target.write_text("# existing harmless hook\n")
        for kind in ("file", "symlink", "broken-symlink", "directory"):
            with self.subTest(kind=kind):
                if kind == "file":
                    hook.write_bytes(target.read_bytes())
                    hook.chmod(0o640)
                elif kind == "directory":
                    hook.mkdir()
                else:
                    hook.symlink_to(target if kind == "symlink" else self.root / "missing")
                before = hook.lstat()
                for flags in ((), ("--dry-run",)):
                    self.run_command("bash", "install.sh", "--with-hooks", *flags, expected=1)
                after = hook.lstat()
                self.assertEqual((before.st_mode, before.st_mtime_ns, before.st_ino),
                                 (after.st_mode, after.st_mtime_ns, after.st_ino))
                self.assertEqual(target.read_text(), "# existing harmless hook\n")
                if kind == "file":
                    self.assertEqual(hook.read_bytes(), target.read_bytes())
                elif "symlink" in kind:
                    self.assertTrue(hook.is_symlink())
                if kind == "directory":
                    hook.rmdir()
                else:
                    hook.unlink()


if __name__ == "__main__":
    unittest.main(verbosity=2)
