#!/usr/bin/env python3
"""
Unit tests for OpenShift Skills Metadata, Frontmatter, and Structure.
Validates SKILL.md YAML frontmatter, referenced links, and script permissions.
"""

import unittest
import os
import glob
import re

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SKILLS_DIR = os.path.join(BASE_DIR, '.gemini', 'skills')

class TestSkillsMetadata(unittest.TestCase):

    def setUp(self):
        self.skill_folders = [
            f for f in os.listdir(SKILLS_DIR)
            if os.path.isdir(os.path.join(SKILLS_DIR, f))
        ]

    def test_skills_count(self):
        """Verify that all 10 core L1 skills exist."""
        expected_skills = [
            'ocp-cluster-health',
            'ocp-pod-diagnostics',
            'ocp-node-triage',
            'ocp-storage-pvc',
            'ocp-ingress-routes',
            'ocp-workload-ops',
            'ocp-auth-navigator',
            'ocp-backup-restore',
            'ocp-resource-extractor',
            'ocp-etcd-defrag'
        ]
        for skill in expected_skills:
            self.assertIn(skill, self.skill_folders, f"Skill '{skill}' missing from .gemini/skills/")

    def test_skill_md_frontmatter_and_structure(self):
        """Verify that each skill has a valid SKILL.md with frontmatter (name, description)."""
        for folder in self.skill_folders:
            skill_path = os.path.join(SKILLS_DIR, folder, 'SKILL.md')
            self.assertTrue(os.path.isfile(skill_path), f"SKILL.md missing in {folder}")

            with open(skill_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Frontmatter check
            self.assertTrue(content.startswith('---'), f"{folder}/SKILL.md must start with '---'")
            parts = content.split('---', 2)
            self.assertGreaterEqual(len(parts), 3, f"{folder}/SKILL.md must have valid YAML frontmatter delimiters")

            frontmatter = parts[1]
            # Extract name and description
            name_match = re.search(r'name:\s*([^\n]+)', frontmatter)
            desc_match = re.search(r'description:\s*([^\n]+|>-[\s\S]+)', frontmatter)

            self.assertIsNotNone(name_match, f"Missing 'name:' in {folder}/SKILL.md frontmatter")
            self.assertIsNotNone(desc_match, f"Missing 'description:' in {folder}/SKILL.md frontmatter")

            parsed_name = name_match.group(1).strip().strip('"').strip("'")
            self.assertEqual(parsed_name, folder, f"Skill name '{parsed_name}' does not match directory '{folder}'")

    def test_referenced_files_exist(self):
        """Verify that any relative markdown/script references in SKILL.md point to real files."""
        for folder in self.skill_folders:
            skill_dir = os.path.join(SKILLS_DIR, folder)
            skill_path = os.path.join(skill_dir, 'SKILL.md')

            with open(skill_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Find markdown links like [text](./references/foo.md) or `./scripts/bar.sh`
            links = re.findall(r'\[.*?\]\((\.\/[^)]+)\)', content)
            for link in links:
                target_path = os.path.normpath(os.path.join(skill_dir, link))
                self.assertTrue(os.path.exists(target_path), f"Broken link in {folder}/SKILL.md: '{link}' -> {target_path}")

    def test_scripts_are_executable(self):
        """Verify that all bash/python scripts in skills have executable permissions (+x)."""
        scripts = glob.glob(os.path.join(SKILLS_DIR, '**', '*.sh'), recursive=True)
        self.assertGreater(len(scripts), 0, "No shell scripts found in skills")

        for script in scripts:
            is_executable = os.access(script, os.X_OK)
            self.assertTrue(is_executable, f"Script is not executable: {script}")

if __name__ == '__main__':
    unittest.main()

