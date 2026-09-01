---
name: ocp-storage-pvc
description: >-
  Triages OpenShift storage and PersistentVolumeClaim (PVC) issues, including PVCs stuck
  in Pending, StorageClass misconfigurations, VolumeAttachment multi-attach errors,
  and namespace storage quota limits. Use when an L1 operator asks to investigate why a
  PVC is not binding or why a pod fails to mount a volume.
---

# OpenShift Storage & PVC Triage Runbook

This skill assists L1 operators in diagnosing PersistentVolumeClaim (PVC), PersistentVolume (PV), and CSI driver storage issues across OpenShift clusters.

> [!CAUTION]
> **Hard Mutation Guardrail**:
> Never execute `oc delete pvc` or `oc delete pv` without explicit operator review and verified data backup. Storage deletion is irreversible and can result in catastrophic data loss.

---

## Diagnostic Workflow

### Step 1: Check PVC Status in Namespace
```bash
oc get pvc -n <namespace>
```
Identify claims in `Pending`, `Lost`, or `Terminating` states.

### Step 2: Describe Pending PVC
```bash
oc describe pvc <pvc-name> -n <namespace>
```
Inspect the **`Events:`** section at the bottom:
- `ProvisioningFailed`: Cloud provider CSI driver failed to allocate disk (e.g. AWS EBS quota exceeded, VMware vCenter authentication failure).
- `WaitForFirstConsumer`: StorageClass uses `volumeBindingMode: WaitForFirstConsumer`. The PVC will NOT bind until a pod requesting it is scheduled on a node.
- `StorageClassNotDefined`: PVC requests a `storageClassName` that does not exist in the cluster.

### Step 3: Verify Available StorageClasses
```bash
oc get storageclass
```
- Verify default StorageClass exists (`(default)` flag).
- Check `PROVISIONER` and `VOLUME-BINDING-MODE` (`Immediate` vs `WaitForFirstConsumer`).

### Step 4: Check Namespace Storage Quotas & Limits
```bash
oc get resourcequota -n <namespace>
oc describe resourcequota -n <namespace>
```
Look for `requests.storage` or `persistentvolumeclaims` limits being hit.

### Step 5: Check VolumeAttachment Multi-Attach Errors
If a pod fails with `Multi-Attach error for volume ... Volume is already exclusively attached to one node and can't be attached to another`:
1. Check existing volume attachments:
   ```bash
   oc get volumeattachment | grep <pv-name>
   ```
2. Verify if the previous pod on another node is stuck in `Terminating` state.

---

## Detailed Runbook
For storage class configurations, CSI driver debugging, and Ceph/ODF storage checks, see:
- [Storage & PVC Runbook](./references/storage_runbook.md)

