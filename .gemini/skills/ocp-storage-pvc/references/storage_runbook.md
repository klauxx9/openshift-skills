# OpenShift Storage Diagnostic Reference

## Common PVC Issues & Resolutions

### 1. `WaitForFirstConsumer` Behavior
Many modern CSI plugins (e.g. AWS EBS CSI, VMware CSI, Azure Disk) configure StorageClasses with:
```yaml
volumeBindingMode: WaitForFirstConsumer
```
- **Normal state**: PVC remains `Pending` until a Pod using this PVC is deployed.
- **Triage**: Check if the associated Pod exists and why the Pod is not yet scheduled.

---

### 2. CSI Driver Health Checks
If dynamic provisioning fails across the entire cluster, verify the CSI driver operator and daemon pods:

```bash
# AWS EBS CSI Driver
oc get pods -n openshift-cluster-csi-drivers -l app=aws-ebs-csi-driver-controller

# VMware vSphere CSI Driver
oc get pods -n openshift-cluster-csi-drivers -l app=vsphere-csi-controller

# OpenShift Data Foundation (ODF / Ceph)
oc get storagecluster -n openshift-storage
oc get cephcluster -n openshift-storage
```

---

### 3. Terminating PVC Stuck
If a PVC cannot be deleted because it is still in use by an active pod or finalizer:
1. Verify which pod is still holding the volume:
   ```bash
   oc get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.volumes[*].persistentVolumeClaim.claimName}{"\n"}{end}' | grep <pvc-name>
   ```
2. **Caution**: Never remove finalizers from PVCs without confirming backing storage disk state with the storage administrator.

