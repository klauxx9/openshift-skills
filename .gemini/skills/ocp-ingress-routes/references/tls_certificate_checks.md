# OpenShift Ingress & Route Diagnostics Reference

## 1. Route Error Code Breakdown

| HTTP Code | Error Message | Root Cause | Triage Steps |
| :--- | :--- | :--- | :--- |
| **503** | `Application is not available` | Router has no active backend endpoints for the route. | 1. `oc get endpoints <svc>`<br>2. Verify backend pods are `Ready (1/1)`<br>3. Check Service selector. |
| **502** | `Bad Gateway` | Router connected to pod, but backend crashed or terminated connection prematurely. | 1. Check pod container logs.<br>2. Check if port in Route definition matches the container listening port. |
| **504** | `Gateway Timeout` | Backend pod took longer than `haproxy.router.openshift.io/timeout` (default 30s) to respond. | Check backend database locks, slow queries, or adjust route timeout annotation. |
| **SSL Error** | `SEC_ERROR_EXPIRED_CERTIFICATE` | Route or Ingress TLS certificate is expired. | Verify cert dates using `openssl x509 -enddate`. |

---

## 2. Ingress Router Log Inspection
To view router logs for specific request paths:
```bash
oc logs -n openshift-ingress deployment/router-default -c router --tail=100 | grep "<route-host>"
```

---

## 3. Increasing Route Timeout Annotation (Requires Review)
```bash
# Example annotation to increase timeout to 60s
oc annotate route <route-name> -n <namespace> --overwrite haproxy.router.openshift.io/timeout=60s
```

