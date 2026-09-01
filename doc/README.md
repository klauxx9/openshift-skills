# OpenShift 4.16 & Ecosystem Documentation Library

This directory contains upstream Red Hat technical documentation repositories used as a local reference and context base by Gemini, Antigravity skills, and L1 Operations engineers.

---

## 📚 Cloned Documentation Repositories

### 1. `doc/openshift-docs` (Branch: `enterprise-4.16`)
**Upstream Repository**: [openshift/openshift-docs](https://github.com/openshift/openshift-docs)  
**Version**: OpenShift Container Platform 4.16

#### Key Component Subsystems & Directories:
- **Logging & Loki**: [`doc/openshift-docs/observability/logging/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/observability/logging)
  - Loki Operator deployment & object storage configuration (`log_storage/`)
  - Log forwarder & Vector collectors (`log_collection_forwarding/`)
  - Cluster Logging Operator troubleshooting (`troubleshooting/`)
- **Monitoring & Alerting**: [`doc/openshift-docs/observability/monitoring/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/observability/monitoring)
  - Prometheus, Alertmanager, Thanos Querier, user-workload monitoring
- **Network Observability**: [`doc/openshift-docs/observability/network_observability/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/observability/network_observability)
  - FlowCollector, eBPF agent, NetObserv dashboards
- **Distributed Tracing & OpenTelemetry**: [`doc/openshift-docs/observability/distr_tracing/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/observability/distr_tracing) & [`doc/openshift-docs/observability/otel/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/observability/otel)
  - Tempo Operator, Jaeger, OpenTelemetry Collector
- **Networking & Ingress**: [`doc/openshift-docs/networking/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/networking)
  - OVN-Kubernetes, IngressController (HAProxy router), Routes, MetalLB, NetworkPolicies
- **Nodes & Machine Management**: [`doc/openshift-docs/nodes/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/nodes) & [`doc/openshift-docs/machine_configuration/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/machine_configuration)
  - MachineConfigPools, Kubelet tuning, CRI-O runtime, node eviction & pressure
- **Storage & OpenShift Data Foundation (ODF)**: [`doc/openshift-docs/storage/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/storage)
  - Dynamic provisioning, CSI drivers, PersistentVolumeClaims, Ceph storage
- **Security & Authentication**: [`doc/openshift-docs/authentication/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/authentication) & [`doc/openshift-docs/security/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/security)
  - OAuth identity providers, RBAC, Security Context Constraints (SCC), Compliance Operator
- **CI/CD, GitOps & Pipelines**: [`doc/openshift-docs/cicd/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/cicd)
  - OpenShift GitOps (Argo CD), OpenShift Pipelines (Tekton)
- **Virtualization & Service Mesh**: [`doc/openshift-docs/virt/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/virt) & [`doc/openshift-docs/service_mesh/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/service_mesh)
  - OpenShift Virtualization (KubeVirt), Service Mesh (Istio / Kiali)
- **Support & Troubleshooting**: [`doc/openshift-docs/support/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/openshift-docs/support)
  - `must-gather`, SOS reports, troubleshooting cluster operators and pods

---

### 2. `doc/rhacm-docs` (Branch: `2.11_stage`)
**Upstream Repository**: [stolostron/rhacm-docs](https://github.com/stolostron/rhacm-docs)  
**Version**: Red Hat Advanced Cluster Management for Kubernetes 2.11 (Compatible with OCP 4.16)

#### Key Subsystems & Directories:
- **Cluster Lifecycle**: [`doc/rhacm-docs/clusters/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/rhacm-docs/clusters)
  - Importing clusters, managed clusters, ClusterCurator, Klusterlet agents
- **Governance, Risk & Compliance (GRC)**: [`doc/rhacm-docs/governance/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/rhacm-docs/governance)
  - Policy framework, configuration policies, certificate policies, compliance automation
- **Multi-Cluster Applications & GitOps**: [`doc/rhacm-docs/applications/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/rhacm-docs/applications) & [`doc/rhacm-docs/gitops/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/rhacm-docs/gitops)
  - Application subscriptions, PlacementRules, Argo CD multi-cluster sets
- **Multi-Cluster Observability**: [`doc/rhacm-docs/observability/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/rhacm-docs/observability)
  - Multi-cluster metrics aggregation, Thanos store, Grafana fleet dashboards
- **Business Continuity & Disaster Recovery**: [`doc/rhacm-docs/business_continuity/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/rhacm-docs/business_continuity)
  - Submariner cross-cluster networking, Regional-DR and Metro-DR with ODF
- **Troubleshooting**: [`doc/rhacm-docs/troubleshooting/`](file:///Users/khairihabidin/GitRepository/openshift-skills/doc/rhacm-docs/troubleshooting)
  - Klusterlet connection issues, Hub API latency, policy evaluation errors

---

## 🔄 Keeping Documentation Synchronized
To update or refresh the local documentation repositories to the latest release commits:
```bash
./.gemini/scripts/sync-docs.sh
```

