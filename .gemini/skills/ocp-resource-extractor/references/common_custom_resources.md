# OpenShift 4.16 Common Custom Resource Definitions (CRDs)

A quick-reference catalog of key Custom Resources (CRs) in OpenShift 4.16 and their corresponding API groups, namespaces, and standard instance names.

## 1. Observability & Logging
| Kind | API Version | Namespace | Standard Instance Name | Description |
| :--- | :--- | :--- | :--- | :--- |
| `ClusterLogForwarder` | `observability.openshift.io/v1` | `openshift-logging` | `instance` | Defines log inputs, pipelines, and outputs to Loki/Kafka/Elasticsearch. |
| `LokiStack` | `loki.grafana.com/v1` | `openshift-logging` | `logging-loki` | Manages Loki storage cluster, object store S3 configuration, and retention. |
| `FlowCollector` | `flows.netobserv.io/v1beta2` | `netobserv` | `cluster` | Configures eBPF network flow collection, sampling, and enrichments. |
| `Prometheus` | `monitoring.coreos.com/v1` | `openshift-monitoring` | `k8s` | Core Prometheus monitoring engine instance. |

## 2. Ingress & Traffic Management
| Kind | API Version | Namespace | Standard Instance Name | Description |
| :--- | :--- | :--- | :--- | :--- |
| `IngressController` | `operator.openshift.io/v1` | `openshift-ingress-operator` | `default` | Configures HAProxy router replicas, certificate secrets, and shard selectors. |
| `Route` | `route.openshift.io/v1` | *Any namespace* | `<route-name>` | Exposes services externally with TLS termination. |

## 3. Storage & Infrastructure
| Kind | API Version | Namespace | Standard Instance Name | Description |
| :--- | :--- | :--- | :--- | :--- |
| `StorageCluster` | `ocs.openshift.io/v1` | `openshift-storage` | `ocs-storagecluster` | OpenShift Data Foundation (ODF) Ceph storage cluster. |
| `MachineConfigPool` | `machineconfiguration.openshift.io/v1` | Cluster-scoped | `master`, `worker` | Node configuration rollout pools. |

## 4. Red Hat Advanced Cluster Management (RHACM)
| Kind | API Version | Namespace | Standard Instance Name | Description |
| :--- | :--- | :--- | :--- | :--- |
| `ManagedCluster` | `cluster.open-cluster-management.io/v1` | Cluster-scoped | `<cluster-id>` | Represents a spoke/managed cluster enrolled into ACM Hub. |
| `Policy` | `policy.open-cluster-management.io/v1` | `<cluster-namespace>` | `<policy-name>` | Governance & compliance policy applied across fleet. |
| `MultiClusterHub` | `operator.open-cluster-management.io/v1` | `open-cluster-management` | `multiclusterhub` | Core ACM Hub configuration resource. |

## 5. GitOps & Pipelines
| Kind | API Version | Namespace | Standard Instance Name | Description |
| :--- | :--- | :--- | :--- | :--- |
| `ArgoCD` | `argoproj.io/v1alpha1` | `openshift-gitops` | `openshift-gitops` | Argo CD central control plane instance. |
| `TektonConfig` | `operator.tekton.dev/v1alpha1` | `openshift-pipelines` | `config` | OpenShift Pipelines operator configuration. |

---

## Example Extraction Commands

```bash
# Extract ClusterLogForwarder from all DEV clusters
./.gemini/skills/ocp-resource-extractor/scripts/export_resources.sh --env dev clusterlogforwarder -n openshift-logging

# Extract IngressController from all PROD clusters
./.gemini/skills/ocp-resource-extractor/scripts/export_resources.sh --env prod ingresscontroller default -n openshift-ingress-operator

# Extract a specific CRD
./.gemini/skills/ocp-resource-extractor/scripts/export_resources.sh ocp-prd-01 crd lokistacks.loki.grafana.com
```

