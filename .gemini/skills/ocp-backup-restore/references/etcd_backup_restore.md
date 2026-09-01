# OpenShift 4.16 ETCD Backup & Recovery Reference

## 1. ETCD Backup Architecture & Concepts

In Red Hat OpenShift Container Platform (OCP) 4.16, `etcd` is the distributed, consistent key-value store holding the complete state of all Kubernetes and OpenShift resources.

### Key Operational Rules:
1. **Single Node Invocation**: Execute `/usr/local/bin/cluster-backup.sh` on **one** control plane host only. Do not invoke it simultaneously on multiple master nodes of the same cluster.
2. **Timing & Upgrades**: Always capture an adhoc etcd snapshot prior to performing any cluster z-stream or minor release upgrade (`oc adm upgrade`).
3. **Certificate Prerequisite**: Do not take etcd backups before the initial 24-hour certificate rotation completes following cluster installation.
4. **I/O Considerations**: Etcd snapshots involve a database sync and high disk I/O; run backups during low-traffic or maintenance windows when possible.

---

## 2. Backup Artifacts Created

The `/usr/local/bin/cluster-backup.sh` script produces two critical artifacts in the target directory:

| Artifact Name | Description | Retention / Security |
| :--- | :--- | :--- |
| `snapshot_<datetimestamp>.db` | Raw etcd database snapshot containing all resource records. | Store in secure, off-cluster storage (e.g. S3, NFS). |
| `static_kuberesources_<datetimestamp>.tar.gz` | Static pod manifests and encryption keys (if etcd encryption is enabled). | Store separately from snapshot if etcd encryption is active. |

---

## 3. Manual Step-by-Step Disaster Recovery Procedure

### Scenario: Complete Control Plane Loss / Quorum Loss

To restore an OpenShift 4.16 cluster using an etcd snapshot:

#### Step 1: Select Non-Degraded Control Plane Node
Pick one healthy master node to act as the primary restoration host.

#### Step 2: Stop Static Control Plane Pods
Move static pod manifests on all other control plane nodes to a temporary location:
```bash
# On non-restoring master nodes
sudo mv /etc/kubernetes/manifests/etcd-pod.yaml /tmp/
sudo mv /etc/kubernetes/manifests/kube-apiserver-pod.yaml /tmp/
sudo crictl stop $(sudo crictl pods -q --name etcd)
```

#### Step 3: Run the Restore Script on Restoration Master
Execute the restore script using the backup files:
```bash
sudo /usr/local/bin/cluster-restore.sh /home/core/assets/backup/backup-<timestamp>
```

#### Step 4: Restart Kubelet and Force Operator Re-sync
```bash
sudo systemctl restart kubelet.service

# Force etcd operator to redeploy and rejoin members
oc patch etcd/cluster --type=merge -p '{"spec": {"forceRedeploymentReason": "recovery-'$(date +%s)'"}}'
```

---

## 4. OADP (OpenShift API for Data Protection) Overview

For application-level workloads (PVCs, namespaces, and application metadata), Red Hat provides **OADP** (Velero + CSI Snapshots):
- **OADP Backup CR**: Creates point-in-time application snapshots to cloud object storage (AWS S3, MinIO, NooBaa).
- **Control Plane vs OADP**: ETCD backup protects the cluster's internal state; OADP protects tenant application volumes and user data.

