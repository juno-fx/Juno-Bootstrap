# NVIDIA GPU Operator

## Configurations

- **[drivers-preinstalled](drivers-preinstalled.yaml)**: Use this configuration if you have pre-installed NVIDIA drivers on your nodes. This removes the need to provision and install the drivers dynamically via the operator. This does mean you have to keep the drivers up to date manually.
- **[auto-install-drivers](auto-install-drivers.yaml)**: Use this configuration if you want the NVIDIA GPU Operator to automatically install the drivers for you. This is recommended for environments that are dynamically provisioning new Nodes on the fly. Otherwise, pre-installed is usually better. Some distributions may not support this. It is normally recommended to use the pre-installed drivers for these distributions.
- **[k3s](k3s.yaml)**: Use this configuration if you run k3s. You can pass it together with one of the other configs.

## Examples

**Pre-installed Drivers**
```shell
helm install juno ./chart/ \
  -f ./deployments/on-prem-sig/gpu/drivers-preinstalled.yaml \
  ...
  -f ./.values.yaml
```

**Auto Install Drivers**
```shell
helm install juno ./chart/ \
  -f ./deployments/on-prem-sig/gpu/auto-install-drivers.yaml \
  ...
  -f ./.values.yaml
```
