# DR Exercise Recovery Runbook

When ` task dr:exercise` fails and leaves the dev cluster in a broken state,
this runbook documents verified recovery procedures organized by failure
signature. Commands assume ` --context dev`.

This is an **append-only runbook**: document new failure modes as they are
discovered; only promote procedures to scripts when a pattern recurs
(3+ occurrences) and the procedure is stable.

## Decision tree

Identify which phase of the exercise failed, then jump to the matching section:

| Failure signature | Phase | Section |
|---|---|---|
| ` platform-1-full-recovery-*` pods CrashLooping with ` "no target backup found"` | post-rebuild: CNPG recovery | [CNPG recovery deadlock](#cnpg-recovery-deadlock) |
| ` velero-restore-gate` Job exited 1, Kustomization NotReady | post-rebuild: Velero restore | [Velero restore failure](#velero-restore-failure) |
| Garage pods never come Ready, PVCs empty | post-rebuild: Garage restore | *(undocumented — extend runbook when encountered)* |
| Exercise interrupted mid-flight (CTRL+C, network drop, laptop sleep) | arbitrary | [Mid-exercise interruption](#mid-exercise-interruption) |

Always [capture forensics](#forensics-capture) before taking destructive
action, even if you "know" what's broken.

---

## CNPG recovery deadlock

**Signature**: ` platform-1-full-recovery-*` pods CrashLooping with
` error: "no target backup found"` in the ` full-recovery` container logs.
The Barman object store (` s3://cnpg-platform-backups/` in Garage) has no
base backup for CNPG to recover from, but the dev Cluster CR is pinned to
` bootstrap.recovery` via ` kubernetes/clusters/dev/config/database/recovery-patch.yaml`.

**Root cause**: the exercise that created the backup either ran on a
pre-PR-755 codebase (no ` _create-cnpg-backup` task) or that step failed
silently. PR 755 makes this failure mode impossible from a successful exercise,
so this procedure should only be needed once per "introduce a regression"
event.

**Recovery strategy**: delete the stuck Cluster CR, apply a de-patched
(bootstrap-less → defaults to ` initdb`) copy of the live spec, verify it
comes up empty, leave ` database-config` suspended until the next exercise's
destroy phase replaces the cluster entirely.

### Steps

1. **Capture forensics** — see [Forensics capture](#forensics-capture) below.

2. **Suspend the ` database-config` Flux Kustomization** so it stops
   reapplying the broken recovery patch mid-surgery:

   ```
   flux --context dev suspend kustomization database-config -n flux-system
   ```

3. **Delete the stuck Cluster CR**. Cascade removes PVCs and recovery pods;
   the ` Pooler` CR is separate and remains:

   ```
   kubectl --context dev delete cluster.postgresql.cnpg.io platform -n database --wait=false
   ```

   Verify cleanup:

   ```
   kubectl --context dev get cluster.postgresql.cnpg.io -n database
   kubectl --context dev get pvc -n database
   kubectl --context dev get pods -n database
   ```

   Expected: no cluster, no PVCs, only ` platform-pooler-rw-*` remaining.

   If the Cluster CR hangs with a ` deletionTimestamp`, strip finalizers:

   ```
   kubectl --context dev patch cluster.postgresql.cnpg.io platform -n database \
     --type=merge -p '{"metadata":{"finalizers":null}}'
   ```

4. **Build a de-patched manifest** from the forensics snapshot by stripping
   ` spec.bootstrap`, ` spec.externalClusters`, and all server-side fields.
   CNPG defaults to ` initdb` when ` spec.bootstrap` is absent, giving a
   fresh empty database:

   ```
   FDIR=$(ls -1dt /tmp/cnpg-heal-* | head -1)
   yq 'del(
     .metadata.resourceVersion,
     .metadata.uid,
     .metadata.generation,
     .metadata.creationTimestamp,
     .metadata.managedFields,
     .metadata.finalizers,
     .metadata.ownerReferences,
     .status,
     .spec.bootstrap,
     .spec.externalClusters
   )' "$FDIR/cluster-broken.yaml" > "$FDIR/cluster-heal.yaml"
   ```

   Sanity check that ` bootstrap` and ` externalClusters` are gone:

   ```
   yq '.spec | has("bootstrap"), .spec | has("externalClusters")' "$FDIR/cluster-heal.yaml"
   ```

   Both should print ` false`.

5. **Apply the healed manifest**:

   ```
   kubectl --context dev apply -f "$FDIR/cluster-heal.yaml"
   ```

   CNPG deprecation warnings about ` barmanObjectStore` and ` enablePodMonitor`
   are pre-existing tech debt, not caused by the heal.

6. **Wait for ` platform-1` to reach Ready** (~40s):

   ```
   kubectl --context dev wait --for=condition=Ready pod/platform-1 -n database --timeout=5m
   ```

7. **Sanity check** that postgres is healthy and empty:

   ```
   kubectl --context dev exec -n database platform-1 -c postgres -- \
     psql -U postgres -d app -c "SELECT version();"

   kubectl --context dev get cluster.postgresql.cnpg.io -n database platform \
     -o jsonpath='{.status.phase}{"\n"}'
   ```

   Expected: PostgreSQL version banner, ` Cluster in healthy state`.

8. **Do NOT resume ` database-config`**. Flux must remain suspended until
   the next ` task dr:exercise` destroy phase wipes the cluster entirely.
   If you resume early, Flux will try to re-apply the ` recovery-patch`,
   CNPG will reject the immutable ` spec.bootstrap` change, and the
   Kustomization will go NotReady again.

9. **Run the exercise** to validate end-to-end and return to the git-declared
   state:

   ```
   task dr:exercise
   ```

   The exercise's destroy phase implicitly releases the suspend because
   there's no Flux state to reconcile against on the rebuilt cluster.

### Post-exercise check

After ` task dr:exercise` completes, confirm ` database-config` is Ready
(the rebuild applies a fresh copy with the recovery patch, which now finds
a real base backup in Barman thanks to PR 755's ` _create-cnpg-backup` step):

```
flux --context dev get kustomization database-config -n flux-system
```

---

## Velero restore failure

**Signature**: ` velero-restore-gate` Job in namespace ` velero` exited 1,
` velero-restore` Flux Kustomization NotReady.

PR 754 changed the gate to fail loud on ` Failed` / ` PartiallyFailed` and
self-heal ` FailedValidation` by deleting the Restore CR so Flux recreates
it on the next interval. If the gate is still failing after several
retries, dig into root cause before touching the cluster.

### Diagnostic sequence

1. **Inspect the gate Job logs**:

   ```
   kubectl --context dev logs -n velero job/velero-restore-gate --tail=200
   ```

2. **Inspect the Restore CR phase and errors**:

   ```
   kubectl --context dev get restore -n velero restore-platform -o yaml
   ```

   Look at ` .status.phase`, ` .status.validationErrors`, ` .status.errors`,
   ` .status.warnings`.

3. **Inspect the BackupStorageLocation**:

   ```
   kubectl --context dev get backupstoragelocation -n velero -o yaml
   ```

   Must show ` .status.phase: Available`. If ` Unavailable`, the restore
   can't proceed regardless of gate behavior — investigate Velero's
   connection to Garage / the object store first.

4. **List known backups in the BSL**:

   ```
   kubectl --context dev get backups.velero.io -n velero
   ```

   If empty: the BSL hasn't synced yet (transient) or the object store is
   genuinely empty (no prior exercise ever completed). The
   ` FailedValidation` self-heal path is designed for the transient case.

*(No standard "heal" procedure yet — extend this section the first time a
Velero-side failure is recovered manually.)*

---

## Mid-exercise interruption

**Signature**: exercise task exited abnormally (CTRL+C, network drop, laptop
sleep) partway through. Cluster may be in any state.

### Triage

1. Identify the last completed step from the Taskfile output or shell
   history.

2. If interruption happened **before** ` _destroy-cluster`: the cluster is
   still live. Verify CNPG and Garage are healthy, then re-run
   ` task dr:exercise`. Idempotency is not guaranteed for all steps — if
   ` _create-cnpg-backup` partially ran, clean up orphan ` Backup` CRs in
   the ` database` namespace first.

3. If interruption happened **during or after** ` _destroy-cluster` but
   **before** the rebuild completes: the Talos / Terragrunt state is the
   source of truth. Run ` task tg:apply-dev` to finish the rebuild, then
   ` task dr:exercise` to re-run.

4. If interruption happened **during convergence** (Flux is reconciling
   post-rebuild): wait for Flux to settle (` flux get kustomizations -A`),
   then investigate any NotReady Kustomizations using the sections above.

---

## Forensics capture

**Always run this before destructive recovery actions.** Cheap insurance —
if the heal itself surfaces surprises, you have a reference point for
comparison.

```
FDIR=/tmp/cnpg-heal-$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$FDIR"
echo "Forensics dir: $FDIR"

kubectl --context dev get cluster.postgresql.cnpg.io platform -n database \
  -o yaml > "$FDIR/cluster-broken.yaml"
kubectl --context dev get events -n database --sort-by=.lastTimestamp \
  > "$FDIR/events.txt"
kubectl --context dev get pods -n database -o wide > "$FDIR/pods.txt"
kubectl --context dev get pvc -n database > "$FDIR/pvcs.txt"

# Capture logs from the most recent failing recovery pod, if any
RECOVERY_POD=$(kubectl --context dev get pods -n database \
  -l cnpg.io/jobRole=full-recovery -o name 2>/dev/null | head -1)
if [ -n "$RECOVERY_POD" ]; then
  kubectl --context dev logs -n database "$RECOVERY_POD" \
    --tail=200 > "$FDIR/recovery-logs.txt" 2>&1 || true
fi

ls -la "$FDIR"
```

Retain the forensics directory until the cluster is back to a known-good
state and you've verified the heal worked. Referencing the captured state
in the follow-up PR (if any) helps reviewers understand what the system
looked like at the time of failure.

---

## When to extend this runbook

Add a new section when:

1. You encounter a failure signature not covered above and have to improvise
   a recovery procedure.
2. An existing procedure proves wrong or incomplete when you actually need it.
3. You find a commands-only shortcut that reviewers can validate against
   the narrative.

Add a new task / script under ` .taskfiles/dr/` only when:

1. The same procedure has been executed manually **three or more times**.
2. The procedure is stable (steps haven't changed between occurrences).
3. There's a clear, low-risk automation boundary that doesn't require
   embedding broad recovery heuristics.

Premature automation is how we got the gate.sh bug that started all this.
Documented, repeatable manual procedures are strictly better than fragile
"heal everything" scripts.
