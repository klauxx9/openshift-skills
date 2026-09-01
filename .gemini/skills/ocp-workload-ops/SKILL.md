---
name: ocp-workload-ops
description: >-
  Performs controlled OpenShift workload management, rollout restarts, replica scaling,
  and rollout status monitoring for Deployments, DeploymentConfigs, and StatefulSets.
  Use when an L1 operator asks to restart a service, scale replicas up/down, check rollout
  progress, or safely rollback a bad deployment.
---

# OpenShift Workload Operations & Rollout Management

This skill outlines safe, controlled procedures for restarting workloads, checking rollout status, and managing deployment lifecycle events on OpenShift.

> [!CAUTION]
> **Hard Mutation Guardrail**:
> `oc rollout restart`, `oc scale`, `oc rollout undo`, and `oc patch` are **mutating commands** and **STRICTLY REQUIRE** explicit human confirmation before execution.

---

## Read-Only Pre-flight Checks (Always run first)

### Step 1: Check Current Workload State
```bash
oc get deployment <deployment-name> -n <namespace>
oc get statefulset <statefulset-name> -n <namespace>
```
Verify:
- `READY` replicas vs `UP-TO-DATE` vs `AVAILABLE`.
- PodDisruptionBudget (PDB) constraints:
  ```bash
  oc get pdb -n <namespace>
  ```

### Step 2: Check Resource Quota Headroom Before Scaling
Ensure scaling will not trigger quota exhaustion:
```bash
oc describe resourcequota -n <namespace>
```

---

## Mutating Operational Procedures (Requires Operator Sign-Off)

When requested to perform a mutation, propose the action using this format:

```text
====================================================================
 ⚠️  MUTATION APPROVAL REQUIRED (HUMAN-IN-THE-LOOP SAFETY POLICY)  ⚠️ 
====================================================================
  Action:        Restart deployment pods sequentially
  Cluster:       <cluster-id>
  Namespace:     <namespace>
  Target:        deployment/<deployment-name>
  Command:       oc rollout restart deployment/<deployment-name> -n <namespace>
  Impact:        Rolling update with zero-downtime (maxUnavailable: 25%)
  Rollback:      oc rollout undo deployment/<deployment-name> -n <namespace>
--------------------------------------------------------------------
```

### Procedure 1: Safe Rollout Restart
```bash
# Trigger rolling replacement of pods
oc rollout restart deployment/<deployment-name> -n <namespace>

# Monitor rollout progress until completion
oc rollout status deployment/<deployment-name> -n <namespace> --watch
```

### Procedure 2: Rollback to Previous Revision
If a new rollout fails:
```bash
# View rollout revision history
oc rollout history deployment/<deployment-name> -n <namespace>

# Undo and revert to previous revision
oc rollout undo deployment/<deployment-name> -n <namespace>
```

### Procedure 3: Workload Scaling
```bash
# Scale replica count
oc scale deployment/<deployment-name> -n <namespace> --replicas=<count>
```

---

## Detailed Procedures Reference
Consult [rollout_procedures.md](./references/rollout_procedures.md) for zero-downtime deployment strategies, canary rollouts, and StatefulSet considerations.

