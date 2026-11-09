# App-replicated services still use 3-replica Longhorn volumes

Garage and CNPG, which replicate their own data, run on the normal 3-replica Longhorn class rather than a no-replica class, at the cost of storing Garage data about nine times. No-replica classes were removed after a CNPG failover deadlocked on a faulted single-replica volume.
