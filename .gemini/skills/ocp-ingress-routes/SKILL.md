---
name: ocp-ingress-routes
description: >-
  Troubleshoots OpenShift Ingress, Routes, HAProxy router pods, TLS/SSL certificate
  expiry, and external traffic routing issues (502 Bad Gateway, 503 Service Unavailable).
  Use when an L1 operator asks to investigate why an application URL is unreachable,
  checking route status, or validating TLS certificates.
---

# OpenShift Ingress & Route Triage Runbook

This skill guides L1 operators in diagnosing application accessibility issues, HTTP 502/503 errors, and TLS certificate validation through the OpenShift Router (HAProxy).

> [!CAUTION]
> **Hard Mutation Guardrail**:
> Modifying IngressControllers, updating TLS route certificates, or changing router shard configurations requires **explicit human operator review and authorization**.

---

## Diagnostic Workflow

### Step 1: Inspect the Target Route
```bash
oc get route <route-name> -n <namespace> -o wide
```
Verify:
- **`HOST/PORT`**: Ensure DNS matches the configured ingress domain.
- **`PATH`**: Sub-path routing correctness.
- **`SERVICES`**: Backend Service name and target port.
- **`TERMINATION`**: Edge, Re-encrypt, Passthrough, or None.

### Step 2: Verify Backend Service & Endpoints
HTTP 503 Service Unavailable usually means the Route cannot locate healthy backend Pod endpoints:
```bash
# Check if service exists
oc get svc <service-name> -n <namespace>

# Check if active pod endpoints are registered
oc get endpoints <service-name> -n <namespace>
```
- If `ENDPOINTS` is empty (`<none>`), verify that the target Pods are in `Running` and `Ready (1/1)` state.
- Check service label selector matches pod labels:
  ```bash
  oc get svc <service-name> -n <namespace> -o jsonpath='{.spec.selector}'
  ```

### Step 3: Check IngressController & Router Pod Health
```bash
# Check IngressController status
oc get ingresscontroller default -n openshift-ingress-operator

# Check HAProxy router pods
oc get pods -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default
```

### Step 4: Validate TLS Certificate Expiration
For Edge and Re-encrypt routes, inspect certificate expiry:
```bash
# Extract and parse route certificate expiry date
oc get route <route-name> -n <namespace> -o jsonpath='{.spec.tls.certificate}' | openssl x509 -noout -enddate -subject
```

---

## Deep Dive Reference
For 502 vs 503 error matrices and TLS certificate analysis, see:
- [TLS & Route Diagnostic Reference](./references/tls_certificate_checks.md)

