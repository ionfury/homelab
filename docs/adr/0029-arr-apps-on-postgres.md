# *arr applications store state in the shared CNPG Postgres

Sonarr, Radarr, Prowlarr, Bazarr and Jellyseerr use the shared CNPG Postgres cluster instead of their default SQLite, so their state gets database replication and WAL-based backups.
