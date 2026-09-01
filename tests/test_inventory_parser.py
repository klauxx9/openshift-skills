#!/usr/bin/env python3
"""
Unit tests for Inventory and Credentials Parsing (parse_inventory.py).
Tests cluster discovery, environment filtering, fuzzy matching, and credential mapping.
"""

import unittest
import os
import sys

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SCRIPTS_DIR = os.path.join(BASE_DIR, '.gemini', 'scripts')
CONFIG_DIR = os.path.join(BASE_DIR, '.gemini', 'config')

sys.path.insert(0, SCRIPTS_DIR)
import parse_inventory

class TestInventoryParser(unittest.TestCase):

    def test_list_all_clusters(self):
        """Test listing all clusters across all environments."""
        clusters = parse_inventory.list_all_clusters(CONFIG_DIR)
        self.assertGreaterEqual(len(clusters), 7, "Should discover at least 7 clusters")
        
        cluster_ids = [c['id'] for c in clusters]
        self.assertIn('ocp-dev-01', cluster_ids)
        self.assertIn('ocp-dev-02', cluster_ids)
        self.assertIn('ocp-stg-01', cluster_ids)
        self.assertIn('ocp-stg-02', cluster_ids)
        self.assertIn('ocp-prd-01', cluster_ids)
        self.assertIn('ocp-prd-02', cluster_ids)
        self.assertIn('ocp-dr-01', cluster_ids)

        for c in clusters:
            self.assertTrue(c['api_url'].startswith('https://api.'), f"Invalid API URL: {c['api_url']}")
            self.assertIn(c['env'], ['dev', 'staging', 'prod', 'dr'])
            self.assertTrue(len(c['region']) > 0, "Region should not be empty")

    def test_get_env_clusters(self):
        """Test filtering clusters by environment."""
        dev_clusters = parse_inventory.get_env_clusters(CONFIG_DIR, 'dev')
        self.assertEqual(len(dev_clusters), 2)
        self.assertIn('ocp-dev-01', dev_clusters)
        self.assertIn('ocp-dev-02', dev_clusters)

        prod_clusters = parse_inventory.get_env_clusters(CONFIG_DIR, 'prod')
        self.assertEqual(len(prod_clusters), 2)
        self.assertIn('ocp-prd-01', prod_clusters)
        self.assertIn('ocp-prd-02', prod_clusters)

        all_clusters = parse_inventory.get_env_clusters(CONFIG_DIR, 'all')
        self.assertGreaterEqual(len(all_clusters), 7)

    def test_get_cluster_exact_match(self):
        """Test exact cluster lookups."""
        c = parse_inventory.get_cluster(CONFIG_DIR, 'ocp-dev-01')
        self.assertIsNotNone(c)
        self.assertEqual(c['id'], 'ocp-dev-01')
        self.assertEqual(c['env'], 'dev')
        self.assertIn('6443', c['api_url'])

    def test_get_cluster_fuzzy_matching(self):
        """Test fuzzy matching for natural language requests."""
        # Case insensitivity
        c1 = parse_inventory.get_cluster(CONFIG_DIR, 'OCP-DEV-01')
        self.assertIsNotNone(c1)
        self.assertEqual(c1['id'], 'ocp-dev-01')

        # Natural language with spaces: 'dev 01'
        c2 = parse_inventory.get_cluster(CONFIG_DIR, 'dev 01')
        self.assertIsNotNone(c2)
        self.assertEqual(c2['id'], 'ocp-dev-01')

        # Natural language: 'prd-02'
        c3 = parse_inventory.get_cluster(CONFIG_DIR, 'prd-02')
        self.assertIsNotNone(c3)
        self.assertEqual(c3['id'], 'ocp-prd-02')

        # Natural language: 'dr'
        c4 = parse_inventory.get_cluster(CONFIG_DIR, 'dr')
        self.assertIsNotNone(c4)
        self.assertEqual(c4['id'], 'ocp-dr-01')

    def test_get_credentials(self):
        """Test credentials parsing from credentials.example.yaml / local."""
        creds = parse_inventory.get_credentials(CONFIG_DIR, 'ocp-dev-01')
        self.assertIn('auth_type', creds)
        self.assertIn(creds['auth_type'], ['password', 'token', 'kubeconfig'])
        self.assertIn('username', creds)
        self.assertIn('password', creds)
        self.assertIn('token', creds)

if __name__ == '__main__':
    unittest.main()

