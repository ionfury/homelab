# In-cluster Garage is the hub of the backup chain

CNPG WAL and base backups and Dragonfly snapshots go to in-cluster Garage S3 rather than straight to AWS, and Velero ships the Garage and database namespaces off-site. Garage is therefore a dependency of every database recovery path.
