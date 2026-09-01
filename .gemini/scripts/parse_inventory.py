#!/usr/bin/env python3
"""
Zero-dependency cluster inventory and credentials parser for OpenShift L1 tools.
Uses Python standard library only (no PyYAML required).
"""

import os
import sys
import glob
import re

def parse_yaml_file(filepath):
    """Parses standard key-values, lists of dictionaries, and nested dicts."""
    if not os.path.isfile(filepath):
        return {}
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    data = {}
    current_cluster = None
    clusters_list = []
    default_creds = {}
    cluster_creds = {}
    section = None
    curr_dict = None

    lines = content.splitlines()
    for line in lines:
        raw_line = line
        line = line.split('#')[0].rstrip()
        if not line.strip():
            continue

        indent = len(line) - len(line.lstrip())
        stripped = line.strip()

        # Top-level simple keys
        if indent == 0 and ':' in stripped and not stripped.startswith('-'):
            k, v = stripped.split(':', 1)
            k, v = k.strip(), v.strip().strip('"').strip("'")
            data[k] = v
            section = k
            curr_dict = None
            continue

        # Environment clusters list
        if section == 'clusters' and stripped.startswith('- id:'):
            if current_cluster:
                clusters_list.append(current_cluster)
            current_cluster = {}
            parts = stripped[2:].split(':', 1)
            current_cluster['id'] = parts[1].strip().strip('"').strip("'")
            continue
        elif section == 'clusters' and current_cluster is not None and ':' in stripped and not stripped.startswith('-'):
            parts = stripped.split(':', 1)
            k, v = parts[0].strip(), parts[1].strip().strip('"').strip("'")
            current_cluster[k] = v
            continue

        # Credentials structure
        if section == 'default_credentials':
            if ':' in stripped:
                k, v = stripped.split(':', 1)
                k, v = k.strip(), v.strip().strip('"').strip("'")
                default_creds[k] = v
        elif section == 'clusters' and indent == 2 and stripped.endswith(':'):
            # In credentials.yaml, clusters is a dict of cluster_id: ...
            c_name = stripped[:-1].strip()
            curr_dict = {}
            cluster_creds[c_name] = curr_dict
        elif section == 'clusters' and indent >= 4 and curr_dict is not None and ':' in stripped:
            k, v = stripped.split(':', 1)
            k, v = k.strip(), v.strip().strip('"').strip("'")
            curr_dict[k] = v

    if current_cluster:
        clusters_list.append(current_cluster)

    data['clusters'] = clusters_list if clusters_list else cluster_creds
    data['default_credentials'] = default_creds
    data['cluster_creds'] = cluster_creds
    return data

def list_all_clusters(config_dir):
    clusters_file = os.path.join(config_dir, 'clusters.yaml')
    if not os.path.isfile(clusters_file):
        return []
    
    with open(clusters_file, 'r', encoding='utf-8') as f:
        content = f.read()

    results = []
    current_cluster = None
    in_aliases = False

    for line in content.splitlines():
        line = line.split('#')[0].rstrip()
        if not line.strip():
            continue

        indent = len(line) - len(line.lstrip())
        stripped = line.strip()

        if indent == 0 and stripped.startswith('cluster_aliases:'):
            in_aliases = True
            continue
        elif indent == 0 and ':' in stripped:
            in_aliases = False
            continue

        if in_aliases:
            if indent == 2 and stripped.endswith(':'):
                if current_cluster and 'id' in current_cluster:
                    results.append(current_cluster)
                cluster_id = stripped[:-1].strip().strip('"').strip("'")
                current_cluster = {'id': cluster_id}
            elif indent >= 4 and current_cluster is not None and ':' in stripped:
                k, v = stripped.split(':', 1)
                k, v = k.strip(), v.strip().strip('"').strip("'")
                current_cluster[k] = v

    if current_cluster and 'id' in current_cluster:
        results.append(current_cluster)

    return results

def get_cluster(config_dir, target):
    clusters = list_all_clusters(config_dir)
    target_clean = re.sub(r'[^a-zA-Z0-9]', '', target.lower())
    
    # 1. Exact match by ID or env
    for c in clusters:
        if c['id'].lower() == target.lower() or c['env'].lower() == target.lower():
            return c
            
    # 2. Match without hyphens / spaces (e.g. "dev01", "ocpdev1", "devcluster01")
    for c in clusters:
        c_clean = re.sub(r'[^a-zA-Z0-9]', '', c['id'].lower())
        if target_clean in c_clean or c_clean in target_clean:
            return c

    # 3. Match by environment prefix if specified (e.g. target "dev" -> first dev cluster)
    for c in clusters:
        if target.lower() in c['id'].lower():
            return c

    return None

def get_env_clusters(config_dir, env_target):
    clusters = list_all_clusters(config_dir)
    env_clean = env_target.lower().strip()
    if env_clean in ['all', 'everything']:
        return [c['id'] for c in clusters]
    return [c['id'] for c in clusters if c['env'].lower() == env_clean or env_clean in c['id'].lower()]

def get_credentials(config_dir, cluster_id):
    creds_file = os.path.join(config_dir, 'credentials.local.yaml')
    if not os.path.isfile(creds_file):
        creds_file = os.path.join(config_dir, 'credentials.example.yaml')
    
    parsed = parse_yaml_file(creds_file)
    c_creds = parsed.get('cluster_creds', {}).get(cluster_id, {})
    d_creds = parsed.get('default_credentials', {})

    auth_type = c_creds.get('auth_type') or d_creds.get('auth_type', 'password')
    username = c_creds.get('username') or d_creds.get('username', '')
    password = c_creds.get('password') or d_creds.get('password', '')
    token = c_creds.get('token') or d_creds.get('token', '')
    insecure = c_creds.get('insecure_skip_tls_verify') or d_creds.get('insecure_skip_tls_verify', 'false')

    return {
        'auth_type': auth_type,
        'username': username,
        'password': password,
        'token': token,
        'insecure_skip_tls_verify': insecure
    }

def main():
    if len(sys.argv) < 3:
        print("Usage: parse_inventory.py <config_dir> <command> [args...]")
        sys.exit(1)

    config_dir = sys.argv[1]
    cmd = sys.argv[2]

    if cmd == 'list':
        clusters = list_all_clusters(config_dir)
        print(f"{'ENVIRONMENT':<12} | {'CLUSTER ID':<12} | {'REGION':<16} | API URL")
        print("-" * 85)
        for c in clusters:
            print(f"{c['env']:<12} | {c['id']:<12} | {c['region']:<16} | {c['api_url']}")
    
    elif cmd == 'get-cluster':
        if len(sys.argv) < 4:
            sys.exit(1)
        target = sys.argv[3]
        c = get_cluster(config_dir, target)
        if not c:
            sys.exit(1)
        print(f"{c['id']}|{c['api_url']}|{c['auth_method']}|{c['env']}")

    elif cmd == 'get-env-clusters':
        if len(sys.argv) < 4:
            sys.exit(1)
        target_env = sys.argv[3]
        cluster_ids = get_env_clusters(config_dir, target_env)
        print(" ".join(cluster_ids))

    elif cmd == 'get-credentials':
        if len(sys.argv) < 4:
            sys.exit(1)
        c_id = sys.argv[3]
        creds = get_credentials(config_dir, c_id)
        print(f"{creds['auth_type']}|{creds['username']}|{creds['password']}|{creds['token']}|{creds['insecure_skip_tls_verify']}")

if __name__ == '__main__':
    main()

