# SRE Investigation Reference

## Symptom → First Check → Common Cause

| Symptom | First Check | Common Cause |
|---------|-------------|--------------|
| `ImagePullBackOff` | `describe pod` events | Wrong image/registry auth |
| `Pending` | Events, node capacity | Insufficient resources |
| `CrashLoopBackOff` | `logs --previous` | App error, missing config |
| `OOMKilled` | Memory limits | Memory leak, limits too low |
| `Unhealthy` | Probe config | Slow startup, wrong endpoint |
| Service unreachable | Hubble dropped traffic | Network policy blocking |
| Can't reach database | Hubble + namespace labels | Missing access label |
| Gateway returns 503 | Hubble from istio-gateway | Missing profile label |

## Common Failure Chains

```
Storage:  StorageClass missing → PVC Pending → Pod Pending → Helm timeout
Network:  DNS failure → Service unreachable → Health check fails → Pod restarted
NetPol:   Missing profile label → No ingress → Service unreachable from gateway
          Missing access label → Can't reach database → CrashLoopBackOff
Secret:   ExternalSecret fails → Secret missing → Pod CrashLoopBackOff
```

## Network Policy Issues

| Symptom | Check | Fix |
|---------|-------|-----|
| Service unreachable from gateway | `kubectl get ns <ns> --show-labels` | Add profile label |
| Can't reach database | `access.network-policy.homelab/postgres` label | Add access label |
| Pods can't resolve DNS | Hubble DNS drops (rare — baseline allows) | Check for custom egress blocking |
| Inter-pod communication fails | Hubble intra-namespace drops | Check for overrides; baseline should allow |

## Promotion Pipeline Stage → Failure Mode

| Stage | Symptom | Common Cause |
|-------|---------|--------------|
| Build | Workflow did not trigger | `kubernetes/` not in changed paths |
| Build | Artifact push failed | GHCR auth (`GITHUB_TOKEN` permissions) |
| Build | No GitHub Release created | Release step failed (`contents: write` permission) |
| Live | OCIRepository not updating | Semver constraint mismatch or tag not higher than current |
| Live | Kustomization failed | Actual config error in the merged PR |
| Live | Canary alert firing after deploy | Broken config reached live — consider revert |

## 5 Whys: Red Flags You Haven't Reached Root Cause

- Your "fix" is increasing a timeout or retry count
- Your "fix" addresses the symptom, not what caused it
- You can still ask "but why did THAT happen?"
- Multiple issues share the same underlying cause
