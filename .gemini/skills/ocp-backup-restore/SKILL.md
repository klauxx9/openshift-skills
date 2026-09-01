---
name: ocp-backup-restore
description: >-
  Executes adhoc and automated etcd control-plane backups and disaster recovery procedures
  on OpenShift 4.16 clusters. Supports single-cluster and multi-cluster environment-wide
  etcd snapshots. Use when an L1 operator asks to "perform etcd backup on all <env> clusters",
  "take etcd backup on <cluster>", or prepare for a cluster upgrade/maintenance.
---

# OpenShift ETCD Backup & Control Plane Recovery Runbook

This skill allows L1 Operations engineers to trigger adhoc and batch **etcd snapshots** across OpenShift 4.16 clusters, verify backup integrity, and prepare for cluster upgrades or maintenance windows.

> [!IMPORTANT]
> **Red Hat 4.16 Operational Rule**:
> - An etcd backup is taken by executing a single invocation of `/usr/local/bin/cluster-backup.sh` on **one** control plane host. Do not take simultaneous backups on all master nodes of the same cluster.
> - An etcd backup produces two critical files:
>   1. `snapshot_<datetimestamp>.db`: The etcd database snapshot.
>   2. `static_kuberesources_<datetimestamp>.tar.gz`: Static pod manifests and encryption keys.
> - Etcd backups must always be taken **prior to cluster z-stream updates** or major infrastructure maintenance.

---

## Conversational Natural Language Triggers

When an operator asks in natural language:
- *"Perform etcd backup on all dev clusters"*
- *"Run etcd snapshot on all prod clusters"*
- *"Take etcd backup on staging"*
- *"Backup control plane for ocp-dev-01"*

Gemini triggers the automated backup script:
```bash
# Multi-cluster environment backup
./.gemini/skills/ocp-backup-restore/scripts/backup_etcd.sh --env <dev|staging|prod|dr|all>

# Single cluster backup
./.gemini/skills/ocp-backup-restore/scripts/backup_etcd.sh <cluster-id>
```

---

## Step-by-Step Manual ETCD Backup Workflow

### Step 1: Verify ETCD Operator & Node Health
Before triggering a backup, verify that the `etcd` cluster operator is healthy and has quorum:
```bash
oc get co etcd
oc get pods -n openshift-etcd -l app=etcd
```

### Step 2: Select a Healthy Control Plane / Master Node
```bash
MASTER_NODE=$(oc get nodes -l node-role.kubernetes.io/master --no-headers 2>/dev/null | awk '$2 ~ /Ready/ {print $1; exit}')
if [ -z "$MASTER_NODE" ]; then
    MASTER_NODE=$(oc get nodes -l node-role.kubernetes.io/control-plane --no-headers 2>/dev/null | awk '$2 ~ /Ready/ {print $1; exit}')
fi
echo "Selected Master Node: $MASTER_NODE"
```

### Step 3: Trigger the ETCD Cluster Backup Script
Execute the backup inside a debug pod on the selected control plane host:
```bash
BACKUP_DIR="/home/core/assets/backup/backup-$(date +%Y%m%d-%H%M%S)"

oc debug --as-root node/"$MASTER_NODE" -- chroot /host /usr/local/bin/cluster-backup.sh "$BACKUP_DIR"
```

### Step 4: Verify Backup Artifacts & File Sizes
Verify that both the database snapshot and static kuberesources archive were successfully created:
```bash
oc debug --as-root node/"$MASTER_NODE" -- chroot /host ls -lh "$BACKUP_DIR"
```

---

## Disaster Recovery & Restore Reference
For etcd restore steps, quorum loss recovery, and single-member replacement, consult:
- [ETCD Backup & Disaster Recovery Reference Guide](./references/etcd_backup_restore.md)

