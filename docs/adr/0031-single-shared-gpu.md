# One GPU is time-sliced across every GPU workload

The cluster has a single Tesla P4 and buying more GPUs is out of scope on cost. Every workload that needs a GPU (Jellyfin transcoding, Tdarr, Ollama) runs on the GPU node and shares the card through time-slicing.
