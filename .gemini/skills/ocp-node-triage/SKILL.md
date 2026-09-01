---
name: ocp-node-triage
description: >-
  Investigates OpenShift worker and control plane node issues, including NotReady states,
  DiskPressure, MemoryPressure, PIDPressure, SchedulingDisabled, taints, and Kubelet/CRI-O errors.
  Use when an L1 operator asks to diagnose an unhealthy node, check node resource utilization,
  or investigate why pods on a node are being evicted.
---

# OpenShift Node Triage & Diagnostic Runbook

This skill guides L1 operators in investigating node degradation, readiness problems, and pressure conditions across master and worker nodes.

> [!CAUTION]
> **Hard Mutation Guardrail**:
> Commands that modify node state (`oc adm cordon`, `oc adm uncordon`, `oc adm drain`, `oc adm node-logs`, or editing node taints/labels) require **explicit human operator authorization** before execution.

---

## Diagnostic Workflow

### Step 1: List Node States and Roles
```bash
oc get nodes -o wide
```
Look for:
- Status != `Ready` (e.g. `NotReady`, `Ready,SchedulingDisabled`, `Unknown`)
- Roles: `master`, `control-plane`, `worker`, `infra`
- Kernel version, OS image, and CRI-O version

### Step 2: Check Node Resource Metrics (CPU & Memory)
```bash
oc adm top nodes
```
Sort by Memory or CPU consumption to spot overloaded nodes:
```bash
# Check node capacity vs allocatable
oc describe node <node-name> | grep -A 8 "Allocated resources:"
```

### Step 3: Inspect Node Conditions
```bash
oc describe node <node-name>
```
Review the `Conditions:` section:
- `MemoryPressure`: Is memory exhaustion triggering evictions?
- `DiskPressure`: Is root partition or container runtime storage full?
- `PIDPressure`: Has the process ID limit been reached on the OS?
- `Ready`: True or False. If False, check `Message:` for Kubelet connection errors.

### Step 4: Inspect Node Taints & Cordon State
Check if a node has been cordoned or tainted by the system:
```bash
oc get node <node-name> -o jsonpath='{.spec.taints}'
```
Common automatic taints:
- `node.kubernetes.io/not-ready:NoExecute`
- `node.kubernetes.io/unreachable:NoExecute`
- `node.kubernetes.io/disk-pressure:NoSchedule`

### Step 5: Check Pods Running on Degraded Node
```bash
oc get pods -A --field-selector spec.nodeName=<node-name> -o wide
```

### Step 6: Review Node System Logs (Requires Cluster Admin)
```bash
# Inspect Kubelet journal logs
oc adm node-logs <node-name> --unit=kubelet --tail=100

# Inspect CRI-O container runtime journal logs
oc adm node-logs <node-name> --unit=crio --tail=100
```

---

## Escalation & Reference
Consult [node_troubleshooting.md](./references/node_troubleshooting.md) for remediation guidance, cordon/drain safety procedures, and node reboot prerequisites.

