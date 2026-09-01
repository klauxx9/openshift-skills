---
name: ocp-etcd-defrag
description: >-
  Assesses etcd database fragmentation, checks endpoint status, and executes controlled,
  safe etcd defragmentation on OpenShift 4.16 clusters. Defragments non-leader members first
  and the Raft leader last with member cooldown intervals. Use when an L1 operator asks to
  "defrag etcd on <cluster>", "check etcd fragmentation on <env>", or "perform etcd defragmentation on all <env> clusters".
---

# OpenShift ETCD Defragmentation & Health Runbook

This skill allows L1 Operations engineers to inspect etcd database size, calculate fragmentation ratios, and execute safe, sequential **etcd defragmentation** across single or multi-cluster environments in OpenShift 4.16.

> [!IMPORTANT]
> **Red Hat 4.16 Safety Rules for ETCD Defragmentation**:
> 1. **Sequential Execution**: Defragmenting an etcd member is a **blocking operation**; that member will temporarily stop responding to requests while rewriting its database. Members must be defragmented one by one.
> 2. **Leader Defragmented Last**: Non-leader / follower members MUST be defragmented first. The active Raft leader must **always be defragmented last** to avoid unnecessary leader elections during the process.
> 3. **Recovery Cooldown**: Allow a cooldown interval between members (at least 30-60s) to allow etcd synchronization.
> 4. **Alarms**: If etcd raised a `NOSPACE` alarm due to exceeding quota, disarm the alarm with `etcdctl alarm disarm` after defragmentation.

---

## Conversational Natural Language Triggers

When an operator asks in natural language:
- *"Check etcd fragmentation on dev clusters"*
- *"Defrag etcd on ocp-prd-01"*
- *"Perform etcd defragmentation on all prod clusters"*
- *"Check etcd database size and alarms on staging"*

Gemini triggers the automated defragmentation tool:
```bash
# Check fragmentation status across an environment (Read-Only)
./.gemini/skills/ocp-etcd-defrag/scripts/defrag_etcd.sh --env <env> --check-only

# Execute defragmentation across an environment (Human Confirmation Prompted)
./.gemini/skills/ocp-etcd-defrag/scripts/defrag_etcd.sh --env <env>

# Single cluster defragmentation
./.gemini/skills/ocp-etcd-defrag/scripts/defrag_etcd.sh <cluster-id>
```

---

## Step-by-Step Manual ETCD Defragmentation Procedure

### Step 1: Query ETCD Member Pods
```bash
oc -n openshift-etcd get pods -l k8s-app=etcd -o wide
```

### Step 2: Determine Endpoint Status & Identify Leader
```bash
FIRST_POD=$(oc -n openshift-etcd get pods -l k8s-app=etcd --no-headers | awk '{print $1; exit}')
oc rsh -n openshift-etcd "$FIRST_POD" etcdctl endpoint status --cluster -w table
```
*Note the endpoint where `IS LEADER` is `true`.*

### Step 3: Defragment Non-Leader Members First
For each pod that is **NOT** the leader:
```bash
oc rsh -n openshift-etcd <follower-pod> etcdctl --command-timeout=60s --endpoints=https://localhost:2379 defrag
```
*Wait 30-60 seconds between each member.*

### Step 4: Defragment the Leader Member Last
```bash
oc rsh -n openshift-etcd <leader-pod> etcdctl --command-timeout=60s --endpoints=https://localhost:2379 defrag
```

### Step 5: Check and Clear Any Alarms
```bash
oc rsh -n openshift-etcd "$FIRST_POD" etcdctl alarm list
oc rsh -n openshift-etcd "$FIRST_POD" etcdctl alarm disarm
```

### Step 6: Verify Final DB Sizes
```bash
oc rsh -n openshift-etcd "$FIRST_POD" etcdctl endpoint status --cluster -w table
```

---

## Reference Guide
For deep details on etcd storage mechanics, compaction, metrics, and alarm handling:
- [ETCD Defragmentation & Quota Reference Guide](./references/etcd_defrag_guide.md)

