# Common OpenShift Pod Failure Scenarios & Troubleshooting

## 1. CrashLoopBackOff
**Definition**: The container starts, crashes or exits with a non-zero code, and OpenShift repeatedly attempts to restart it with exponential backoff delay.

### Exit Code Reference
- **Exit Code 0**: Container completed normally (e.g. Job container), but pod spec had `restartPolicy: Always`.
- **Exit Code 1**: Application exception, uncaught error, or configuration failure.
- **Exit Code 126**: Command found in container image cannot be invoked (permissions issue / missing `+x`).
- **Exit Code 127**: Command or binary specified in `entrypoint` / `args` not found in `$PATH`.
- **Exit Code 137 (SIGKILL / OOM)**: Killed by kernel due to Out-Of-Memory (`OOMKilled`) or terminated by OpenShift after failing `terminationGracePeriodSeconds`.
- **Exit Code 143 (SIGTERM)**: Graceful shutdown initiated by OpenShift (e.g. eviction or rolling update).

---

## 2. ImagePullBackOff / ErrImagePull
**Common Causes**:
1. **Typo in image repository or tag**: Check `oc describe pod <name>` for image path.
2. **Missing `imagePullSecrets`**: Image is hosted in a private registry (Quay, Artifactory, AWS ECR) and the pod's service account lacks a secret with `kubernetes.io/dockerconfigjson`.
3. **Registry rate limiting / network firewall**: Inability to resolve external registry DNS or egress blocked.

---

## 3. Pending Pod (FailedScheduling)
**Common Causes**:
1. **Resource Starvation**: Node capacity insufficient for requested CPU or Memory (`0/6 nodes are available: 6 Insufficient memory`).
2. **Taints and Tolerations**: Worker nodes have special taints (e.g. `node.kubernetes.io/unreachable`) that the pod does not tolerate.
3. **NodeSelector / Affinity Mismatch**: Pod requires labels (e.g. `node-role.kubernetes.io/worker=`, `topology.kubernetes.io/zone=ap-southeast-1a`) that match no available nodes.

---

## 4. Pending Pod (FailedMount)
**Common Causes**:
1. **PVC Binding**: PersistentVolumeClaim referenced in `spec.volumes` is in `Pending` or `Lost` state.
2. **Multi-Attach Error (`VolumeAttachment`)**: ReadWriteOnce (RWO) PVC is still attached to an older node where the previous pod was running.
3. **Missing Secret or ConfigMap**: Volume mounts a Secret/ConfigMap that was not created in the namespace.

---

## 5. Probe Failures (`Unhealthy` Liveness / Readiness)
**Common Causes**:
1. **Readiness Probe Failure**: Pod is healthy, but warmup takes longer than `initialDelaySeconds`. Pod remains `0/1 Ready` and does not receive service traffic.
2. **Liveness Probe Failure**: Probe fails `failureThreshold` times, triggering a container restart.
3. **Diagnosis**: Check probe path and port in `oc describe pod <pod>`, then check application logs to see why the HTTP endpoint returned 5xx or timed out.

