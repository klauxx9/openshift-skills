#!/usr/bin/env python3
"""
Unit tests for Shell Script Syntax and CLI execution.
Runs bash syntax checks and tests non-destructive CLI command responses.
"""

import unittest
import os
import glob
import subprocess

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

class TestScriptsSyntax(unittest.TestCase):

    def test_bash_syntax(self):
        """Verify that all .sh scripts have valid Bash syntax (bash -n)."""
        scripts = glob.glob(os.path.join(BASE_DIR, '.gemini', '**', '*.sh'), recursive=True)
        self.assertGreater(len(scripts), 0, "No shell scripts found to validate")

        for script in scripts:
            res = subprocess.run(['bash', '-n', script], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"Syntax error in {script}:\n{res.stderr}")

    def test_oc_login_list_command(self):
        """Test './.gemini/scripts/oc-login.sh --list' execution and output."""
        script_path = os.path.join(BASE_DIR, '.gemini', 'scripts', 'oc-login.sh')
        res = subprocess.run([script_path, '--list'], cwd=BASE_DIR, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"oc-login.sh --list failed:\n{res.stderr}")
        self.assertIn("Available OpenShift Clusters by Environment", res.stdout)
        self.assertIn("ocp-dev-01", res.stdout)
        self.assertIn("ocp-prd-01", res.stdout)

    def test_agents_symlink_validity(self):
        """Verify that .agents is a valid symlink pointing to .gemini."""
        agents_path = os.path.join(BASE_DIR, '.agents')
        self.assertTrue(os.path.islink(agents_path), ".agents should be a symlink")
        target = os.readlink(agents_path)
        self.assertEqual(target, '.gemini')
        self.assertTrue(os.path.isdir(agents_path), ".agents symlink must resolve to a valid directory")

if __name__ == '__main__':
    unittest.main()

