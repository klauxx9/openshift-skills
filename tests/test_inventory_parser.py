#!/usr/bin/env python3
"""
Unit tests for Pure Bash Inventory and Credentials Parser (parse_inventory.sh).
Validates that all inventory discovery, fuzzy lookup, environment filtering,
and <env>-<platform>-<flavour> composite credential mapping run via pure Bash.
"""

import unittest
import subprocess
import os

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SCRIPTS_DIR = os.path.join(BASE_DIR, '.gemini', 'scripts')
CONFIG_DIR = os.path.join(BASE_DIR, '.gemini', 'config')
PARSER_SH = os.path.join(SCRIPTS_DIR, 'parse_inventory.sh')

def run_parser(*args):
    """Executes parse_inventory.sh and returns (stdout, returncode)."""
    cmd = [PARSER_SH, CONFIG_DIR] + list(args)
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout.strip(), result.returncode

class TestBashInventoryParser(unittest.TestCase):

    def test_no_python_parser_exists(self):
        """Verify that parse_inventory.py is deleted and only parse_inventory.sh is used."""
        py_parser = os.path.join(SCRIPTS_DIR, 'parse_inventory.py')
        self.assertFalse(os.path.exists(py_parser), "parse_inventory.py should no longer exist")
        self.assertTrue(os.path.exists(PARSER_SH), "parse_inventory.sh must exist")
        self.assertTrue(os.access(PARSER_SH, os.X_OK), "parse_inventory.sh must be executable")

    def test_list_all_clusters(self):
        """Test listing all clusters with parse_inventory.sh list."""
        out, code = run_parser('list')
        self.assertEqual(code, 0)
        self.assertIn('ENVIRONMENT', out)
        self.assertIn('ocp-dev-hub', out)
        self.assertIn('ocp-dev-01', out)
        self.assertIn('ocp-dev-02', out)
        self.assertIn('ocp-uat-hub', out)
        self.assertIn('ocp-uat-01', out)
        self.assertIn('ocp-uat-02', out)
        self.assertIn('ocp-prd-hub', out)
        self.assertIn('ocp-prd-01', out)
        self.assertIn('ocp-prd-02', out)

    def test_no_onprem_acm_hubs(self):
        """Verify that NO on-prem ACM Hub clusters exist."""
        out, code = run_parser('list')
        self.assertEqual(code, 0)
        lines = out.splitlines()
        for line in lines[2:]:  # skip header
            parts = [p.strip() for p in line.split('|')]
            if len(parts) >= 4:
                platform = parts[1]
                flavour = parts[2]
                if flavour == 'acm-hub':
                    self.assertEqual(platform, 'gcp', f"ACM Hub must be on GCP: {line}")

    def test_get_env_clusters(self):
        """Test filtering clusters by environment."""
        dev_out, code = run_parser('get-env-clusters', 'dev')
        self.assertEqual(code, 0)
        dev_clusters = dev_out.split()
        self.assertEqual(len(dev_clusters), 3)
        self.assertIn('ocp-dev-hub', dev_clusters)
        self.assertIn('ocp-dev-01', dev_clusters)
        self.assertIn('ocp-dev-02', dev_clusters)

        uat_out, code = run_parser('get-env-clusters', 'uat')
        self.assertEqual(code, 0)
        uat_clusters = uat_out.split()
        self.assertEqual(len(uat_clusters), 3)
        self.assertIn('ocp-uat-hub', uat_clusters)
        self.assertIn('ocp-uat-01', uat_clusters)
        self.assertIn('ocp-uat-02', uat_clusters)

        prod_out, code = run_parser('get-env-clusters', 'prod')
        self.assertEqual(code, 0)
        prod_clusters = prod_out.split()
        self.assertEqual(len(prod_clusters), 3)
        self.assertIn('ocp-prd-hub', prod_clusters)
        self.assertIn('ocp-prd-01', prod_clusters)
        self.assertIn('ocp-prd-02', prod_clusters)

    def test_get_cluster_fuzzy_matching(self):
        """Test fuzzy matching with parse_inventory.sh."""
        # Exact and case insensitivity
        out1, code1 = run_parser('get-cluster', 'OCP-DEV-01')
        self.assertEqual(code1, 0)
        self.assertTrue(out1.startswith('ocp-dev-01|'))

        # Natural language: 'dev 01'
        out2, code2 = run_parser('get-cluster', 'dev 01')
        self.assertEqual(code2, 0)
        self.assertTrue(out2.startswith('ocp-dev-01|'))

        # Natural language: 'prd-02'
        out3, code3 = run_parser('get-cluster', 'prd-02')
        self.assertEqual(code3, 0)
        self.assertTrue(out3.startswith('ocp-prd-02|'))

        # Natural language: 'uat-hub'
        out4, code4 = run_parser('get-cluster', 'uat-hub')
        self.assertEqual(code4, 0)
        self.assertTrue(out4.startswith('ocp-uat-hub|'))

    def test_composite_key_credentials_mapping(self):
        """Verify dynamic <env>-<platform>-<flavour> credential resolution in Bash."""
        # 1. Dev GCP ACM Hub
        c_dev_hub, code = run_parser('get-credentials', 'ocp-dev-hub')
        self.assertEqual(code, 0)
        parts = c_dev_hub.split('|')
        self.assertEqual(parts[1], 'dev_gcp_hub_admin')

        # 2. Dev GCP Managed Cluster
        c_dev_mc, code = run_parser('get-credentials', 'ocp-dev-01')
        self.assertEqual(code, 0)
        parts = c_dev_mc.split('|')
        self.assertEqual(parts[1], 'dev_gcp_operator')

        # 3. Dev On-Prem Managed Cluster
        c_dev_onprem, code = run_parser('get-credentials', 'ocp-dev-02')
        self.assertEqual(code, 0)
        parts = c_dev_onprem.split('|')
        self.assertEqual(parts[1], 'dev_onprem_operator')

        # 4. UAT GCP ACM Hub
        c_uat_hub, code = run_parser('get-credentials', 'ocp-uat-hub')
        self.assertEqual(code, 0)
        parts = c_uat_hub.split('|')
        self.assertEqual(parts[1], 'uat_gcp_hub_admin')

        # 5. UAT GCP Managed Cluster
        c_uat_mc, code = run_parser('get-credentials', 'ocp-uat-01')
        self.assertEqual(code, 0)
        parts = c_uat_mc.split('|')
        self.assertEqual(parts[1], 'uat_gcp_operator')

        # 6. Prod GCP ACM Hub
        c_prd_hub, code = run_parser('get-credentials', 'ocp-prd-hub')
        self.assertEqual(code, 0)
        parts = c_prd_hub.split('|')
        self.assertEqual(parts[1], 'prod_gcp_hub_admin')

        # 7. Prod GCP Managed Cluster
        c_prd_mc, code = run_parser('get-credentials', 'ocp-prd-01')
        self.assertEqual(code, 0)
        parts = c_prd_mc.split('|')
        self.assertEqual(parts[1], 'prod_gcp_operator')

        # 8. Prod On-Prem Managed Cluster
        c_prd_onprem, code = run_parser('get-credentials', 'ocp-prd-02')
        self.assertEqual(code, 0)
        parts = c_prd_onprem.split('|')
        self.assertEqual(parts[1], 'prod_onprem_operator')

if __name__ == '__main__':
    unittest.main()
