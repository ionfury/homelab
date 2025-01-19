locals {
  tld = "tomnowak.work"

  rancher = {
    cluster_name         = "rancher"
    ssh_key_name         = "id-rsa-homelab-ssh-mac"
    rancher_version      = "2.8.4"
    kubernetes_version   = "v1.28.7-rancher1-1"
    cert_manager_version = "1.12.0"

    node_memory = "16Gi"
    node_cpu    = 2
    node_count  = 1
  }

  public_ssh_keys = [
    {
      description = "SSH key from mac laptop"
      name        = "id-rsa-homelab-ssh-mac"
      public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCjzNYlwnjIcr4I8cbQWW5ZZAvPhMklmdAD2sL9Wm5WyAkJ9ui86uZ4KpVG7ymr9/eHkR6VrBuBbAIhKpbnRerhQkbmWuXRj3O6aExFMwZXMi1p+TMtQ/RvO0BqV3EVzFUlE/Ry45oML45gC/E7rvUgbQg5skXzbQYh/TVjIlcPWmLunVgC5+5fO7ByhKrfiqPnEZ4iG1Pnt0BuPIJeEJhbVqmEzikbTtQ5ZhBPAk37s+aHxYg7okOhxW0709ninICHlYc+FicV9sd6jfqaBa31ydolkSpsy8KV8+n1KEkntQD+pFRdjk7Rroab2zDyKhuqO1l/k7BEPzKvuIMIoU07vZ5EKZHIC7Rp/kArOIZ1gmO/nRQvA5R34ovOqJeGR7DFa++PzucuW3Y83hHjg4E82tTtqSgcyjlX9EGjYs0dxQoX5l43IcTxFp0QGS6g7qG8u/PKV/uqS2cEbMCS9YBupvu83H2WBsWL5XEk2iC/q93WZXa2/QGdLwZMv1r6q58= tnowak@TWML-TNOWAK"
    }
  ]
}
