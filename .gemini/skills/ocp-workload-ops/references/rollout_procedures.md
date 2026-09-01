# OpenShift Rollout & Workload Operations Reference

## Deployment Rolling Update Strategies

### 1. Zero-Downtime Rolling Update Parameters
Standard OpenShift Deployment configuration ensures continuous availability during restarts:
- `maxSurge: 25%` (Allocates up to 25% extra temporary pods during rollout)
- `maxUnavailable: 25%` (Ensures at least 75% of replica capacity remains serving traffic)

---

## StatefulSet Rolling Updates
- **Partitioned Rollouts**: StatefulSets update in reverse ordinal index (`pod-N` down to `pod-0`).
- Each pod must become `1/1 Ready` before the controller terminates and recreates the next ordinal pod.
- **Rollout Command**:
  ```bash
  oc rollout restart statefulset/<name> -n <namespace>
  ```

---

## DeploymentConfig vs Kubernetes Deployment
In OpenShift 4.x, standard Kubernetes `Deployment` is preferred over legacy `DeploymentConfig`.
If working on a legacy workload:
```bash
# DeploymentConfig rollout trigger
oc rollout latest dc/<name> -n <namespace>
```

