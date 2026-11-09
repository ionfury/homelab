# Velero is the only off-site backup path

Off-site backups come only from Velero (CSI snapshots with data movement to AWS S3, selected by namespace and an exclusion label). Longhorn's native S3 backups and backup-encoded StorageClasses were removed after silently failing twice, so backup selection lives in one place, separate from provisioning.
