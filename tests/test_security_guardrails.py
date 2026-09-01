#!/usr/bin/env python3
"""
Unit tests for Security Guardrails and Git Protection.
Verifies gitignore exclusions, credential isolation, and GEMINI.md hard constraints.
"""

import unittest
import os
import subprocess

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

class TestSecurityGuardrails(unittest.TestCase):

    def test_gitignore_protects_credentials(self):
        """Verify that credentials.local.yaml is ignored by git."""
        creds_path = os.path.join('.gemini', 'config', 'credentials.local.yaml')
        res = subprocess.run(
            ['git', 'check-ignore', '-v', creds_path],
            cwd=BASE_DIR,
            capture_output=True,
            text=True
        )
        self.assertEqual(res.returncode, 0, f"{creds_path} must be ignored by git!")
        self.assertIn('.gitignore', res.stdout)

    def test_gitignore_protects_chat_artifacts(self):
        """Verify that chat-artifacts directory and backup snapshots are ignored by git."""
        sample_snap = os.path.join('chat-artifacts', 'ocp-dev-01_snapshot_20260901.db')
        res = subprocess.run(
            ['git', 'check-ignore', '-v', sample_snap],
            cwd=BASE_DIR,
            capture_output=True,
            text=True
        )
        self.assertEqual(res.returncode, 0, f"{sample_snap} must be ignored by git!")

    def test_gemini_md_mutation_policy(self):
        """Verify that GEMINI.md contains the mandatory Human-in-the-Loop Mutation Policy."""
        gemini_md_path = os.path.join(BASE_DIR, 'GEMINI.md')
        self.assertTrue(os.path.isfile(gemini_md_path), "GEMINI.md must exist at repository root")
        
        with open(gemini_md_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Check required security rules
        self.assertIn("CRITICAL HARD CONSTRAINTS", content)
        self.assertIn("Human-in-the-Loop Mutation Policy", content)
        self.assertIn("READ-ONLY DEFAULT", content)
        self.assertIn("NO UNAUTHORIZED MUTATIONS", content)
        self.assertIn("MUTATION PROPOSAL FORMAT", content)
        self.assertIn("Credential Security & Masking", content)

    def test_credentials_example_template_is_safe(self):
        """Verify that credentials.example.yaml does not contain real secret tokens."""
        example_path = os.path.join(BASE_DIR, '.gemini', 'config', 'credentials.example.yaml')
        self.assertTrue(os.path.isfile(example_path), "credentials.example.yaml must exist")
        
        with open(example_path, 'r', encoding='utf-8') as f:
            content = f.read()

        self.assertNotIn("real_password", content.lower())
        self.assertIn("EXAMPLE_", content)

if __name__ == '__main__':
    unittest.main()

