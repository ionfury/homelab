# Operators run in their own namespaces, separate from the data plane

Operators (for example `cnpg-system`, `dragonfly-system`, `garage-system`) run in namespaces separate from the resources they manage (`database`, `cache`, `garage`). Operators need kube-apiserver and webhook access that their data planes do not, and keeping them apart keeps each namespace's network policy to a single concern.
