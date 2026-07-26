#!/usr/bin/env bash
# Idempotent media folder setup for sonarr/radarr/sonarr4k/radarr4k instances.
# Creates a temporary pod with media PVCs mounted, creates the folder structure,
# then cleans up. Safe to run multiple times — uses mkdir -p throughout.
#
# Usage:
#   ./setup-media-folders.sh                        # set up library + downloads
#   ./setup-media-folders.sh --library-pvc library2 # set up a second library PVC
#
# Scaling: when adding /media/library2, /media/library3, etc., pass the PVC name:
#   ./setup-media-folders.sh --library-pvc media-library2
# Then add the same subfolder structure under the new mountpoint.
# Sonarr/Radarr/Jellyfin just get additional root folders pointing to the new paths.

set -euo pipefail

CONTEXT="${KUBECONFIG_CONTEXT:-live}"
NAMESPACE="media"
POD_NAME="media-folder-setup-$$"
LIBRARY_PVC="${1:-media-library}"
LIBRARY_MOUNT="/media/library"

# Override library PVC via --library-pvc flag
while [[ $# -gt 0 ]]; do
  case "$1" in
    --library-pvc)
      LIBRARY_PVC="$2"
      # If using a non-default PVC, mount at /media/library2 etc.
      if [[ "$LIBRARY_PVC" != "media-library" ]]; then
        SUFFIX="${LIBRARY_PVC#media-library}"
        LIBRARY_MOUNT="/media/library${SUFFIX}"
      fi
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

echo "==> Context:          ${CONTEXT}"
echo "==> Library PVC:      ${LIBRARY_PVC} → ${LIBRARY_MOUNT}"
echo "==> SABnzbd PVC:      sabnzbd-downloads → /downloads/sabnzbd"
echo "==> qBittorrent PVC:  qbittorrent-downloads → /downloads/qbittorrent"
echo ""

cleanup() {
  echo "==> Cleaning up pod ${POD_NAME}..."
  kubectl --context "${CONTEXT}" delete pod "${POD_NAME}" -n "${NAMESPACE}" --ignore-not-found --wait=false
}
trap cleanup EXIT

echo "==> Launching setup pod..."
kubectl --context "${CONTEXT}" run "${POD_NAME}" \
  --namespace="${NAMESPACE}" \
  --image=busybox:stable \
  --restart=Never \
  --overrides="{
    \"spec\": {
      \"securityContext\": {
        \"runAsUser\": 568,
        \"runAsGroup\": 568,
        \"fsGroup\": 568
      },
      \"containers\": [{
        \"name\": \"setup\",
        \"image\": \"busybox:stable\",
        \"command\": [\"sleep\", \"300\"],
        \"volumeMounts\": [
          {\"name\": \"library\",               \"mountPath\": \"${LIBRARY_MOUNT}\"},
          {\"name\": \"sabnzbd-downloads\",     \"mountPath\": \"/downloads/sabnzbd\"},
          {\"name\": \"qbittorrent-downloads\", \"mountPath\": \"/downloads/qbittorrent\"}
        ]
      }],
      \"volumes\": [
        {\"name\": \"library\",               \"persistentVolumeClaim\": {\"claimName\": \"${LIBRARY_PVC}\"}},
        {\"name\": \"sabnzbd-downloads\",     \"persistentVolumeClaim\": {\"claimName\": \"sabnzbd-downloads\"}},
        {\"name\": \"qbittorrent-downloads\", \"persistentVolumeClaim\": {\"claimName\": \"qbittorrent-downloads\"}}
      ]
    }
  }"

echo "==> Waiting for pod to be ready..."
kubectl --context "${CONTEXT}" wait pod "${POD_NAME}" \
  -n "${NAMESPACE}" \
  --for=condition=Ready \
  --timeout=60s

echo "==> Creating library folder structure under ${LIBRARY_MOUNT}..."
kubectl --context "${CONTEXT}" exec -n "${NAMESPACE}" "${POD_NAME}" -- \
  mkdir -p \
    "${LIBRARY_MOUNT}/tv" \
    "${LIBRARY_MOUNT}/tv-4k" \
    "${LIBRARY_MOUNT}/anime" \
    "${LIBRARY_MOUNT}/movies" \
    "${LIBRARY_MOUNT}/movies-4k" \
    "${LIBRARY_MOUNT}/anime-movies"

echo "==> Creating SABnzbd download folder structure..."
kubectl --context "${CONTEXT}" exec -n "${NAMESPACE}" "${POD_NAME}" -- \
  mkdir -p \
    /downloads/sabnzbd/incomplete \
    /downloads/sabnzbd/complete/sonarr \
    /downloads/sabnzbd/complete/sonarr4k \
    /downloads/sabnzbd/complete/sonarr-anime \
    /downloads/sabnzbd/complete/radarr \
    /downloads/sabnzbd/complete/radarr4k \
    /downloads/sabnzbd/complete/radarr-anime

echo "==> Creating qBittorrent download folder structure..."
kubectl --context "${CONTEXT}" exec -n "${NAMESPACE}" "${POD_NAME}" -- \
  mkdir -p \
    /downloads/qbittorrent/sonarr \
    /downloads/qbittorrent/sonarr4k \
    /downloads/qbittorrent/sonarr-anime \
    /downloads/qbittorrent/radarr \
    /downloads/qbittorrent/radarr4k \
    /downloads/qbittorrent/radarr-anime

echo "==> Verifying..."
kubectl --context "${CONTEXT}" exec -n "${NAMESPACE}" "${POD_NAME}" -- \
  find /downloads "${LIBRARY_MOUNT}" -maxdepth 3 -type d | sort

echo ""
echo "==> Done. Folder structure:"
echo ""
echo "  ${LIBRARY_MOUNT}/"
echo "    tv/           ← Sonarr root folder"
echo "    tv-4k/        ← Sonarr4K root folder"
echo "    anime/        ← Sonarr anime series root folder"
echo "    movies/       ← Radarr root folder"
echo "    movies-4k/    ← Radarr4K root folder"
echo "    anime-movies/ ← Radarr anime movies root folder"
echo ""
echo "  /downloads/sabnzbd/           (sabnzbd-downloads PVC)"
echo "    incomplete/                 ← SABnzbd temp/incomplete downloads"
echo "    complete/{sonarr,sonarr4k,sonarr-anime,radarr,radarr4k,radarr-anime}/"
echo ""
echo "  /downloads/qbittorrent/       (qbittorrent-downloads PVC)"
echo "    {sonarr,sonarr4k,sonarr-anime,radarr,radarr4k,radarr-anime}/"
echo ""
echo "  Next steps:"
echo "    1. SABnzbd: set Temporary Folder to /downloads/sabnzbd/incomplete"
echo "                set Completed Folder to /downloads/sabnzbd/complete"
echo "                set category paths to /downloads/sabnzbd/complete/<category>"
echo "    2. qBittorrent: set Default Save Path to /downloads/qbittorrent"
echo "                    add categories matching the subfolders above"
echo "    3. Each Sonarr/Radarr: point download client remote path at the matching subfolder"
echo "    4. Configure root folders in each app UI"
echo ""
echo "  To add a second library PVC later:"
echo "    ./setup-media-folders.sh --library-pvc media-library2"
