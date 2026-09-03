# OpenShift L1 Operations - Gemini Skills Framework

A structured, enterprise-grade AI Operations (AIOps) skill repository and runbook suite designed for **Level 1 (L1) OpenShift Operations teams**. This repository equips Gemini and Antigravity agents with standardized procedures, cluster inventory mapping by environment, credential guardrails, and runbooks for day-to-day OpenShift triage and incident management.

---

## 🔒 Safety First: Human-in-the-Loop Mutation Policy

> [!CAUTION]
> **Strict Guardrail**: All skills and automated workflows operate in **Read-Only / Diagnostic mode by default**. Mutating operations (e.g. `oc rollout restart`, `oc scale`, `oc delete`, `oc adm drain`) are **STRICTLY PROHIBITED** from running without prior human review and explicit operator approval.

---

## 📁 Repository Layout

```text
openshift-skills/
├── .gitignore                            # Excludes credentials, tokens, local kubeconfigs, temp logs
├── README.md                             # Repository documentation and operations guide
├── GEMINI.md                             # OpenShift Administrator rules, safety policies, and guidelines
├── .agents -> .gemini                    # Symlink for multi-agent framework discovery compatibility
├── doc/                                  # Official Red Hat technical documentation context base
│   ├── README.md                         # Documentation index & topic directory map
│   ├── openshift-docs/                   # OpenShift 4.16 Docs (branch: enterprise-4.16)
│   │   ├── observability/logging/        # Loki Operator, Vector, Cluster Logging
│   │   ├── observability/monitoring/     # Prometheus, Thanos, Alertmanager
│   │   ├── observability/network_.../    # NetObserv (eBPF flow tracking)
│   │   ├── storage/                      # CSI, ODF (Ceph), PVCs, StorageClasses
│   │   ├── networking/                   # OVN-Kubernetes, IngressController, Routes
│   │   └── virt/, cicd/, serverless/     # KubeVirt, GitOps (ArgoCD), Pipelines (Tekton)
│   └── rhacm-docs/                       # Red Hat Advanced Cluster Management (branch: 2.11_stage)
│       ├── clusters/                     # Multi-cluster lifecycle & Klusterlet agents
│       ├── governance/                   # Policy framework & compliance
│       ├── observability/                # Fleet metrics & Grafana dashboards
│       └── business_continuity/          # Submariner cross-cluster networking & DR
└── .gemini/
    ├── config/
    │   ├── clusters.yaml                 # Unified inventory storing API & Console URLs in cluster_aliases
    │   ├── credentials.example.yaml      # Sanitized template for user credentials and tokens
    │   └── credentials.local.yaml        # [GITIGNORED] Actual local user passwords & tokens
    │
    ├── scripts/                          # Core automation scripts
    │   ├── utils.sh                      # Shell utilities (mutation prompt, token masking, colors)
    │   ├── oc-login.sh                   # Multi-cluster authentication helper
    │   ├── oc-health-summary.sh          # Non-destructive cluster health summary
    │   └── sync-docs.sh                  # Synchronizes upstream OCP & RHACM docs
    │
    └── skills/                           # Modular L1 OpenShift Runbooks
        ├── ocp-cluster-health/           # ClusterOperators, node ready state, MCP, upgrade health
        │   ├── SKILL.md
        │   └── references/operators.md
        ├── ocp-pod-diagnostics/          # Pod crash triage (CrashLoopBackOff, OOMKilled, Evicted)
        │   ├── SKILL.md
        │   ├── scripts/triage_pods.sh
        │   └── references/common_pod_errors.md
        ├── ocp-node-triage/              # Node resource pressure, NotReady status, taints
        │   ├── SKILL.md
        │   └── references/node_troubleshooting.md
        ├── ocp-storage-pvc/              # PVC stuck in Pending, StorageClasses, quota limits
        │   ├── SKILL.md
        │   └── references/storage_runbook.md
        ├── ocp-ingress-routes/           # Route triage, HAProxy router health, TLS cert expiry
        │   ├── SKILL.md
        │   └── references/tls_certificate_checks.md
        ├── ocp-workload-ops/             # Safe rollout restarts, rollout status, scaling
        │   ├── SKILL.md
        │   └── references/rollout_procedures.md
        ├── ocp-backup-restore/           # Adhoc ETCD backups & control plane recovery
        │   ├── SKILL.md
        │   ├── scripts/backup_etcd.sh
        │   └── references/etcd_backup_restore.md
        ├── ocp-resource-extractor/       # Extract YAML manifests & CRDs across clusters
        │   ├── SKILL.md
        │   ├── scripts/export_resources.sh
        │   └── references/common_custom_resources.md
        └── ocp-auth-navigator/           # Environment switching and oc context management
            ├── SKILL.md
            └── scripts/switch_cluster.sh
```

---

## 🔑 Credential & Password Management

### How to Configure Your Local Credentials
1. Copy the example credentials template:
   ```bash
   cp .gemini/config/credentials.example.yaml .gemini/config/credentials.local.yaml
   ```
2. Edit `.gemini/config/credentials.local.yaml` with your credentials or service account tokens.
3. The `.gitignore` is pre-configured to ensure that `credentials.local.yaml` and any `*.local.yaml` files are **never committed to Git**.

Supported authentication methods in `credentials.local.yaml`:
- **`password`**: Username and password for LDAP / HTPasswd / kubeadmin.
- **`token`**: OpenShift ServiceAccount API bearer token (`sha256~...`).
- **`kubeconfig`**: Path to an isolated kubeconfig file per cluster.

### Dynamic Credential Mapping (`<env>-<platform>-<flavour>`)
Credentials are dynamically resolved using the cluster's profile:
1. `clusters.yaml` defines: `env` (`dev|uat|prod`), `platform` (`gcp|on-prem`), `flavour` (`acm-hub|managed-cluster`).
2. The dynamic lookup key is constructed: `<env>-<platform>-<flavour>` (e.g. `dev-gcp-managed-cluster`, `prod-on-prem-acm-hub`).
3. Clusters sharing the same profile automatically inherit the exact same password and username!

---

## 🌐 Cluster Inventory Structure

All clusters are defined in [`.gemini/config/clusters.yaml`](file:///Users/khairihabidin/GitRepository/openshift-skills/.gemini/config/clusters.yaml) with strictly the essential operational keys:

| Environment | Cluster Alias | Platform | Flavour | API URL |
| :--- | :--- | :--- | :--- | :--- |
| **DEV** | `ocp-dev-hub` | `gcp` | `acm-hub` | `https://api.ocp-dev-hub.gcp.dev...:6443` |
| **DEV** | `ocp-dev-01` | `gcp` | `managed-cluster` | `https://api.ocp-dev-01.gcp.dev...:6443` |
| **DEV** | `ocp-dev-02` | `on-prem` | `managed-cluster` | `https://api.ocp-dev-02.onprem.dev...:6443` |
| **UAT** | `ocp-uat-hub` | `gcp` | `acm-hub` | `https://api.ocp-uat-hub.gcp.uat...:6443` |
| **UAT** | `ocp-uat-01` | `gcp` | `managed-cluster` | `https://api.ocp-uat-01.gcp.uat...:6443` |
| **UAT** | `ocp-uat-02` | `on-prem` | `managed-cluster` | `https://api.ocp-uat-02.onprem.uat...:6443` |
| **PROD** | `ocp-prd-hub` | `gcp` | `acm-hub` | `https://api.ocp-prd-hub.gcp.prod...:6443` |
| **PROD** | `ocp-prd-01` | `gcp` | `managed-cluster` | `https://api.ocp-prd-01.gcp.prod...:6443` |
| **PROD** | `ocp-prd-02` | `on-prem` | `managed-cluster` | `https://api.ocp-prd-02.onprem.prod...:6443` |

---

## 🚀 Quickstart for L1 Operators

### 1. List All Available Clusters
```bash
./.gemini/scripts/oc-login.sh --list
```

### 2. Natural Language Cluster Login
You can ask Gemini in natural language:
- *"Login to dev cluster 1"*
- *"Connect to ocp-prd-01"*
- *"Switch to disaster recovery cluster"*

Under the hood, Gemini runs:
```bash
./.gemini/scripts/oc-login.sh <resolved-cluster-id>
```

### 3. Natural Language Multi-Cluster Health Checks
You can ask Gemini to audit an entire environment:
- *"Check all status of dev clusters"*
- *"Run a health check across all production clusters"*
- *"Audit the health of all staging clusters"*

Under the hood, Gemini executes:
```bash
./.gemini/skills/ocp-cluster-health/scripts/check_env_health.sh dev
./.gemini/skills/ocp-cluster-health/scripts/check_env_health.sh prod
```

### 4. Natural Language Adhoc ETCD Backups
You can prompt Gemini in natural language:
- *"Perform etcd backup on all dev clusters"*
- *"Take etcd backup on staging"*
- *"Run etcd snapshot on ocp-prd-01"*

Under the hood, Gemini executes:
```bash
./.gemini/skills/ocp-backup-restore/scripts/backup_etcd.sh --env dev
./.gemini/skills/ocp-backup-restore/scripts/backup_etcd.sh ocp-prd-01
```

### 5. Natural Language Resource & CRD Extraction
You can ask Gemini to extract resources across clusters:
- *"Get clusterlogforwarder from all dev clusters"*
- *"Extract ingresscontroller default from all prod clusters"*
- *"Export all routes in payment-prod across prod clusters"*

Under the hood, Gemini executes:
```bash
./.gemini/skills/ocp-resource-extractor/scripts/export_resources.sh --env dev clusterlogforwarder
```
*All manifests are exported in YAML format to `chat-artifacts/<resource-name>-<cluster-name>.yaml`.*

### 6. Single Cluster Rapid Health Check
```bash
./.gemini/scripts/oc-health-summary.sh
```

### 7. Triage Pods in a Namespace
```bash
./.gemini/skills/ocp-pod-diagnostics/scripts/triage_pods.sh <namespace> [pod-name]
```

---

## 🛠️ Summary of Built-in L1 Skills

1. **`ocp-cluster-health`**: Checks `ClusterVersion`, `ClusterOperators` status, `MachineConfigPools`, and recent cluster warnings.
2. **`ocp-backup-restore`**: Executes single and multi-cluster adhoc etcd snapshots and disaster recovery control plane verification.
3. **`ocp-resource-extractor`**: Extracts Kubernetes/OpenShift resources and CRDs in YAML format to `chat-artifacts/<resource-name>-<cluster-name>.yaml`.
4. **`ocp-pod-diagnostics`**: Automates troubleshooting for `CrashLoopBackOff`, `OOMKilled` (Exit 137), `ImagePullBackOff`, and probe failures.
5. **`ocp-node-triage`**: Investigates node pressure (`DiskPressure`, `MemoryPressure`, `PIDPressure`), `NotReady` states, and Kubelet logs.
6. **`ocp-storage-pvc`**: Triages `Pending` PVCs, `WaitForFirstConsumer` binding, StorageClasses, and quota ceilings.
7. **`ocp-ingress-routes`**: Inspects OpenShift Routes, backend Service endpoints, HTTP 502/503 errors, and TLS certificate expiration.
8. **`ocp-workload-ops`**: Controlled workload rollouts, rollout history inspection, rollbacks, and replica scaling with human confirmation.
9. **`ocp-auth-navigator`**: Seamless switching between environments (`dev`, `staging`, `prod`, `dr`) and `oc` context inspection.

---

## 🧪 Running Automated Unit Tests

The repository includes an automated test suite verifying inventory schemas, git protection rules, frontmatter validity, and script syntax:

```bash
./run_tests.sh
```

### Test Modules Tested:
- **`tests/test_inventory_parser.py`**: Validates cluster catalogs, environment filters, fuzzy matching, and credential lookups.
- **`tests/test_security_guardrails.py`**: Verifies `.gitignore` exclusions for `credentials.local.yaml` and `chat-artifacts/`, and checks `GEMINI.md` hard constraints.
- **`tests/test_skills_metadata.py`**: Validates YAML frontmatter, 3rd-person description phrasing, and internal link integrity across all `SKILL.md` files.
- **`tests/test_scripts_syntax.py`**: Runs `bash -n` syntax checks on all shell scripts and verifies symlinks.

---

## ➕ Adding a New Skill
To add a new skill to this repository:
1. Create a new directory under `.gemini/skills/<skill-name>/`.
2. Add a `SKILL.md` with required YAML frontmatter:
   ```markdown
   ---
   name: ocp-my-new-skill
   description: >-
     Describe what the skill does and when the agent should trigger it.
   ---
   # My New Skill Runbook
   ...
   ```
3. Add any helper scripts to `<skill-name>/scripts/` and reference guides to `<skill-name>/references/`.
4. Run `./run_tests.sh` to verify your new skill's metadata and structure!

