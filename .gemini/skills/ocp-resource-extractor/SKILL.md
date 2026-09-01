---
name: ocp-resource-extractor
description: >-
  Extracts Kubernetes and OpenShift resources or Custom Resource Definitions (CRDs) in YAML
  format from a single cluster or across all clusters in an environment (DEV, STAGING, PROD, DR).
  Outputs YAML manifests to the chat-artifacts directory with the naming convention
  <resource-name>-<cluster-name>.yaml. Use when an operator asks to "get <resource> from all <env> clusters",
  "export CRD from <cluster>", or retrieve configurations across environments.
---

# OpenShift Multi-Cluster Resource & CRD Extractor

This skill allows L1 Operations engineers to query, extract, and export Kubernetes/OpenShift resources and Custom Resources (CRs/CRDs) in clean YAML format into the local `chat-artifacts/` folder across single or multiple clusters.

> [!NOTE]
> **Read-Only Operation**: Extracting resources is completely non-destructive and safe for production environments.
> All exported YAML files are saved to `chat-artifacts/` and named `<resource-name>-<cluster-name>.yaml`.

---

## Conversational Natural Language Triggers

When an operator asks in natural language:
- *"Get clusterlogforwarder from all dev clusters"*
- *"Extract ingresscontroller default from all prod clusters"*
- *"Get CRD lokistacks.loki.grafana.com from staging"*
- *"Export all routes in namespace payment-prod across prod clusters"*

Gemini triggers the automated resource extractor script:
```bash
# Export across an entire environment
./.gemini/skills/ocp-resource-extractor/scripts/export_resources.sh --env <env> <resource_type> [resource_name] [-n namespace]

# Export from a single cluster
./.gemini/skills/ocp-resource-extractor/scripts/export_resources.sh <cluster-id> <resource_type> [resource_name] [-n namespace]
```

---

## Output File Naming Convention

Every exported YAML artifact is saved in `chat-artifacts/` using the format:
```text
chat-artifacts/<resource-name>-<cluster-name>.yaml
```

**Examples**:
- `chat-artifacts/instance-ocp-dev-01.yaml` (ClusterLogForwarder `instance` on `ocp-dev-01`)
- `chat-artifacts/instance-ocp-dev-02.yaml` (ClusterLogForwarder `instance` on `ocp-dev-02`)
- `chat-artifacts/default-ocp-prd-01.yaml` (IngressController `default` on `ocp-prd-01`)
- `chat-artifacts/lokistacks.loki.grafana.com-ocp-stg-01.yaml` (CRD on `ocp-stg-01`)

---

## Step-by-Step Manual Extraction Procedure

### Step 1: Connect to the Target Cluster
```bash
./.gemini/scripts/oc-login.sh <cluster-id>
```

### Step 2: Query Available Instances of the Resource
```bash
# In specific namespace (or cluster-wide)
oc get <resource_type> -n <namespace> -o custom-columns=NAME:.metadata.name --no-headers
```

### Step 3: Export Resource Manifest in YAML Format
```bash
mkdir -p chat-artifacts
oc get <resource_type> <resource_name> -n <namespace> -o yaml > "chat-artifacts/<resource_name>-<cluster_id>.yaml"
```

---

## Common OpenShift 4.16 Custom Resources Reference
For a curated catalog of standard OpenShift 4.16 CRDs (ClusterLogForwarder, LokiStack, NetObserv FlowCollector, IngressController, ODF StorageCluster, RHACM ManagedCluster/Policies), consult:
- [Common Custom Resources Reference Guide](./references/common_custom_resources.md)

