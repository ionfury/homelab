# The media library is one RWX volume outside the backup system

Bulk media is a single 10 TiB RWX Longhorn volume on a dedicated `slow-media` class and is excluded from backups. It is too large to back up and can be rebuilt from the *arr applications' metadata.
