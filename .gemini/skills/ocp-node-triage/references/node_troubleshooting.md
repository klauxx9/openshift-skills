# Node Troubleshooting & Remediation Reference

## 1. NotReady Node Diagnostics
When a node transitions to `NotReady`, investigate:
1. **Network Connectivity**: Can the node communicate with the OpenShift API servers on port `6443`?
2. **Kubelet Status**: Is the `kubelet.service` active and responsive?
   - Look for certificates expiring in `/var/lib/kubelet/pki/`.
3. **CRI-O Runtime**: Is `crio.service` stuck due to deadlocked container shims?
4. **Machine Config Daemon (MCD)**: Is the node in the middle of applying a MachineConfig update or waiting for reboot?

---

## 2. DiskPressure Condition
Occurs when the filesystem holding container images (`/var/lib/containers`) or root filesystem (`/`) crosses the eviction threshold (usually 85%).
- Inspect ephemeral storage consumption:
  ```bash
  oc describe node <node-name> | grep -A 10 "Ephemeral-Storage"
  ```
- Identify large pods producing excessive logs or emptyDir volumes:
  ```bash
  oc get pods -A --field-selector spec.nodeName=<node-name> -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace
  ```

---

## 3. Human-in-the-Loop Node Remediation Steps (Require Approval)

If remediation is needed, present these commands for operator sign-off:

### Safe Cordon (Mark Schedulable Disabled)
```bash
# Prevents new pods from being scheduled onto this node
oc adm cordon <node-name>
```

### Safe Drain (Evict Existing Workloads)
```bash
# Evicts pods respecting PodDisruptionBudgets (PDBs)
oc adm drain <node-name> --ignore-daemonsets --delete-emptydir-data --force
```

### Uncordon (Restore Schedulable State)
```bash
oc adm uncordon <node-name>
```

