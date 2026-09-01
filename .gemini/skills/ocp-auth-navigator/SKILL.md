---
name: ocp-auth-navigator
description: >-
  Manages OpenShift cluster authentication, environment switching, context selection,
  and credential retrieval using the cluster inventory and local credential store. Use when
  an L1 operator asks to connect to a specific cluster (e.g. dev, staging, prod, dr), switch
  contexts, or check authentication status.
---

# OpenShift Authentication & Environment Navigator

This skill manages cluster connection profiles, context switching, and authentication credentials across multi-environment OpenShift topologies.

> [!CAUTION]
> **Credential Security**: Never print or display plaintext passwords or full bearer tokens. Always mask tokens when presenting context information.

## Natural Language Access Management Workflow

When an operator asks in natural language (e.g., *"login to dev cluster 1"*, *"connect to prod cluster 02"*, *"switch to staging"*, *"access ocp-dr-01"*):

1. **Resolve Cluster Alias**:
   - Parse the target environment and name from the user request.
   - Use fuzzy matching to resolve the cluster ID (e.g. "dev cluster 1" -> `ocp-dev-01`, "prod baremetal" -> `ocp-prd-02`).
   ```bash
   python3 ./.gemini/scripts/parse_inventory.py .gemini/config get-cluster "<name_or_alias>"
   ```
2. **Execute Authentication via Helper**:
   - Run the non-interactive login command:
   ```bash
   ./.gemini/scripts/oc-login.sh <resolved-cluster-id>
   ```
3. **Report Connection State to Operator**:
   - Display the connected server API, user identity, and default project (with credentials masked).

---

## Interactive Cluster Switcher

Run the cluster switcher script:
```bash
./.gemini/skills/ocp-auth-navigator/scripts/switch_cluster.sh [cluster-id-or-env]
```

---

## Manual Authentication Workflow

### Step 1: List Managed Clusters
View all available environments and clusters in `.gemini/config/clusters.yaml`:
```bash
./.gemini/scripts/oc-login.sh --list
```

### Step 2: Authenticate to Target Cluster
Log into a specific cluster by alias (e.g., `ocp-dev-01`, `ocp-prd-01`):
```bash
./.gemini/scripts/oc-login.sh <cluster-id>
```

### Step 3: Verify Context & User Roles
```bash
# Check current API server
oc whoami --show-server

# Check authenticated username
oc whoami

# Check active project / namespace
oc project
```

### Step 4: Verify Cluster Permissions / RBAC
Check if your authenticated user has sufficient permissions in a namespace:
```bash
oc auth can-i get pods -n <namespace>
oc auth can-i create deployments -n <namespace>
```

