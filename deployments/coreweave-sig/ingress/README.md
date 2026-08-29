# NVIDIA GPU Operator

## Configurations

- **[load-balancer](load-balancer.yaml)**: Use this configuration if you have pre-installed NVIDIA drivers on your nodes. This removes the need to provision and install the drivers dynamically via the operator. This does mean you have to keep the drivers up to date manually.

## Examples

**Pre-installed Drivers**
```shell
helm install juno ./chart/ \
  -f ./deployments/coreweave-sig/ingress/load-balancer.yaml \
  ...
  -f ./.values.yaml
```
