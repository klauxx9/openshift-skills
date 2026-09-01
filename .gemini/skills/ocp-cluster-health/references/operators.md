# OpenShift Core Cluster Operators Reference

A quick-lookup table for L1 Operations to map Degraded Cluster Operators to their corresponding namespaces and primary daemon sets/deployments.

| Operator Name | Namespace | Key Resource to Check | Common Failure Cause |
| :--- | :--- | :--- | :--- |
| `authentication` | `openshift-authentication` | `deployment/oauth-openshift` | OAuth cert expiration, LDAP provider unreachable |
| `console` | `openshift-console` | `deployment/console` | Route failure, authentication dependency down |
| `dns` | `openshift-dns` | `daemonset/dns-default` | Node networking issues, CoreDNS crashes |
| `etcd` | `openshift-etcd` | `pod -l app=etcd` | Disk I/O latency on control plane, quorum loss |
| `ingress` | `openshift-ingress` | `deployment/router-default` | Node selector issues, port conflict (80/443), cert error |
| `kube-apiserver` | `openshift-kube-apiserver` | `pod -l app=kube-apiserver` | Etcd unreachable, cert rotation issue |
| `kube-controller-manager` | `openshift-kube-controller-manager` | `pod -l app=kube-controller-manager` | APIServer latency, lease lock contention |
| `kube-scheduler` | `openshift-kube-scheduler` | `pod -l app=kube-scheduler` | APIServer connectivity |
| `machine-config` | `openshift-machine-config-operator` | `deployment/machine-config-operator` | Ignition failure, invalid MachineConfig syntax, reboot hang |
| `monitoring` | `openshift-monitoring` | `statefulset/prometheus-k8s` | PVC full for Prometheus, Thanos querier crash |
| `network` | `openshift-network-operator` | `daemonset/ovn-kubernetes-node` | OVN/OVS flow failures, geneve tunnel block, MTU mismatch |
| `node-tuning` | `openshift-cluster-node-tuning-operator` | `daemonset/tuned` | Sysctl conflict, kernel mismatch |
| `storage` | `openshift-cluster-storage-operator` | `deployment/aws-ebs-csi-driver-operator` | Cloud IAM permission error, CSI driver pod crash |

## Operator Log Retrieval Commands

```bash
# Get events for specific operator namespace
oc get events -n openshift-<subsystem> --sort-by='.lastTimestamp'

# Tail logs of operator controller pod
oc logs -n openshift-<subsystem> -l app=<subsystem> --tail=100
```

