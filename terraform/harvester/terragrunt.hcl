dependencies {
  paths = ["../network"]
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  harvester_node_count = 1
}
