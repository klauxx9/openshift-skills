---
name: ocp-pod-diagnostics
description: >-
  Troubleshoots and triages failing application and system pods on OpenShift. Handles
  CrashLoopBackOff, ImagePullBackOff, ErrImagePull, OOMKilled, Evicted, Pending, and
  failed liveness/readiness probes. Use when an L1 operator asks to investigate why a pod
  is not running, crashing, or restarting.
---

# OpenShift Pod Diagnostic & Triage Runbook

This skill guides L1 operators through diagnosing and isolating pod failures in application or system namespaces.

> [!CAUTION]
> **Hard Constraint**: Do NOT delete pods (`oc delete pod`) or restart deployments (`oc rollout restart`) without explicit human operator confirmation. Pod deletion can cause service downtime or erase crucial container crash state.

---

## Fast Triage Script

Run the automated pod diagnostics script:
```bash
./.gemini/skills/ocp-pod-diagnostics/scripts/triage_pods.sh <namespace> [pod-name]
```

---

## Step-by-Step Triage Procedure

### Step 1: Locate Failing Pods
List all non-running pods in the target namespace (or across all namespaces):
```bash
# In target namespace
oc get pods -n <namespace> --field-selector=status.phase!=Running,status.phase!=Succeeded

# Filter for pods with high restart counts
oc get pods -n <namespace> --sort-by='.status.containerStatuses[0].restartCount'
```

### Step 2: Inspect Pod Status & Recent Events
Run `oc describe` to view the termination reason and lifecycle events:
```bash
oc describe pod <pod-name> -n <namespace>
```
Look closely at:
- **`Last State`**: Reason (`OOMKilled`, `Error`, `Completed`), Exit Code.
- **`Events`** (bottom of describe output): Look for `FailedScheduling`, `FailedMount`, `FailedCreatePodSandBox`, `Unhealthy`, or `BackOff`.

### Step 3: Extract Container Logs
1. **Live Logs** (if container is currently running):
   ```bash
   oc logs <pod-name> -n <namespace> -c <container-name> --tail=150
   ```
2. **Previous Crash Logs** (crucial if pod is in `CrashLoopBackOff` or `Error`):
   ```bash
   oc logs <pod-name> -n <namespace> -c <container-name> --previous --tail=150
   ```

### Step 4: Map Error Pattern to Root Cause
Match the failure pattern against our diagnostic matrix:

| Failure Pattern | Probable Cause | Action / Verification |
| :--- | :--- | :--- |
| `CrashLoopBackOff` (Exit 1/2) | Application bug, missing env var, config syntax error | Inspect `--previous` logs |
| `OOMKilled` (Exit 137) | Memory limit exceeded | Inspect container `limits.memory` vs actual usage |
| `ImagePullBackOff` | Secret missing, wrong image tag, registry auth error | Check `imagePullSecrets` and registry connectivity |
| `Pending` (FailedScheduling) | Insufficient CPU/Memory, node selector/taint mismatch | Check `oc describe pod` Events & Node capacity |
| `Pending` (FailedMount) | PVC not bound, Secret/ConfigMap does not exist | Check PVC status and Secret existence |
| `Unhealthy` (Probe Failed) | Liveness/Readiness HTTP port closed, timeout too low | Check endpoint response and probe timeout settings |

For in-depth analysis of specific exit codes and probe settings, see:
- [Common Pod Errors & Resolution Guide](./references/common_pod_errors.md)

---

## Remediation Workflow (Human Review Required)
If a pod restart or configuration patch is deemed necessary:
1. Formulate the exact command (e.g. `oc rollout restart deployment/<name> -n <namespace>`).
2. Present the target cluster, namespace, deployment, and risk assessment to the human operator.
3. Await explicit approval before executing.

