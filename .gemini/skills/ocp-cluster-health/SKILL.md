---
name: ocp-cluster-health
description: >-
  Assesses and triages overall OpenShift cluster health, including ClusterOperators,
  ClusterVersion upgrade status, MachineConfigPools, node readiness, core components,
  and cluster-wide warning events. Use when an L1 operator asks for a cluster health check,
  morning shift handover verification, or after a cluster incident/maintenance.
---

# OpenShift Cluster Health Assessment & Triage

This skill provides step-by-step procedures for L1 Operations engineers to audit and diagnose cluster-level health on Red Hat OpenShift 4.x clusters.

> [!CAUTION]
> **Mutation Policy**: This skill is strictly **READ-ONLY**. Do not execute any reboot, node drain, or operator modification commands without explicit human operator authorization.

## Multi-Cluster Environment Health Check (Batch Mode)

When an operator asks in natural language (e.g., *"check all status of dev clusters"*, *"audit health of staging environment"*, *"check all production clusters"*):

Run the automated multi-cluster environment audit:
```bash
./.gemini/skills/ocp-cluster-health/scripts/check_env_health.sh <dev|staging|prod|dr|all>
```
This will:
1. Identify all clusters in the specified environment from the inventory.
2. Log into each cluster sequentially using stored credentials.
3. Assess ClusterVersion, ClusterOperators, Node readiness, MachineConfigPools, and failing core pods.
4. Output a consolidated multi-cluster health dashboard table.

---

## Single Cluster Quick Assessment

Run the single-cluster health diagnostic script on the currently connected cluster:
```bash
./.gemini/scripts/oc-health-summary.sh
```

### Step 1: Verify Connection & Cluster Context
Always verify the active cluster context before starting:
```bash
oc whoami --show-server
oc whoami
```

### Step 2: Check Cluster Version & Update Status
```bash
oc get clusterversion
```
- **Healthy**: `AVAILABLE=True`, `PROGRESSING=False`, `FAILING=False`.
- **Degraded**: If `FAILING=True`, inspect the error message in `.status.conditions`:
  ```bash
  oc describe clusterversion version
  ```

### Step 3: Audit Cluster Operators
OpenShift operators manage critical control plane and networking subsystems:
```bash
oc get co
```
Filter for degraded or progressing operators:
```bash
oc get co --no-headers | awk '$3 != "True" || $4 == "True" || $5 == "True" {print $0}'
```
If an operator is degraded (e.g. `authentication`, `ingress`, `kube-apiserver`, `network`, `storage`):
1. Review operator conditions:
   ```bash
   oc describe co <operator-name>
   ```
2. Check operator pod logs in the associated namespace (refer to [operators.md](./references/operators.md)):
   ```bash
   oc get pods -n openshift-<operator-namespace>
   oc logs -n openshift-<operator-namespace> deployment/<operator-deployment> --tail=100
   ```

### Step 4: Check MachineConfigPools (MCP)
Inspect node configuration and rollout status:
```bash
oc get mcp
```
- Verify that `DEGRADED` is `False` for both `master` and `worker` pools.
- If `DEGRADED=True`:
  ```bash
  oc describe mcp <pool-name>
  ```

### Step 5: Check Node Capacity & Conditions
```bash
oc get nodes -o wide
```
Check for resource pressure conditions across all nodes:
```bash
oc get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[*]}{.type}{"="}{.status}{" "}{end}{"\n"}{end}' | grep -E 'DiskPressure=True|MemoryPressure=True|PIDPressure=True|Ready=False'
```

### Step 6: Scan for Critical Warning Events
```bash
oc get events -A --field-selector type=Warning --sort-by='.lastTimestamp' | tail -n 25
```

---

## Escalation Reference
For detailed operator ownership, namespaces, and troubleshooting procedures, consult:
- [Cluster Operators Reference Guide](./references/operators.md)

