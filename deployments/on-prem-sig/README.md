# On Prem SIG

This directory contains the deployment configurations for the on-premise special interest group (SIG) of Juno.

Please note this is intended to help custom/advanced deployments.
For most, if not all cases, you can simply follow our convenient [OneClick Installation](https://juno-fx.github.io/Orion-Documentation/installation/cluster/oneclick/)

## Services

The following services are included in the on-premise SIG:

- **[GPU](gpu/README.md)**: This service is responsible for configuring NVIDIA GPU support in Juno via the NVIDIA GPU Operator.
  
  Depending on your runtime, there might be extra configurations.
  To find out more about those, see: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html#specifying-configuration-options-for-containerd
  Note the defaults provided by Nvidia do not work with K3s, but rather a plain containerd setup. K3s customizes it, making the conf we list under gpu/k3s necessary.
