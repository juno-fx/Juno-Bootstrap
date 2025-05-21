# NGINX Ingress Controller

## Configurations

- **[host-port](host-port.yaml)**: Use this configuration if you want to access the node via a direct HostPort. We typically recommend this configuration for on-premise deployments where you have direct access to the nodes and want to avoid the extra network jump from the NodePort proxy. It is recommended that you use an external Load Balancer (i.e. HAProxy) pointing to the Nodes hosting the ingress pods and have the LB perform health checks incase a Node goes down.
- **[node-port](node-port.yaml)**: Use this configuration if you want to use NodePort to access the NGINX Ingress Controller. This is typically used in environments where you don't have a load balancer or want to expose the service on a specific port. It is recommended that you use an external Load Balancer (i.e. HAProxy) pointing to the Nodes on the specified port and have the LB perform health checks incase a Node goes down.

## Examples

**HostPort**
```shell
helm install juno ./chart/ \
  -f ./deployments/on-prem-sig/ingress/host-port.yaml \
  ...
  -f ./.values.yaml
```

**NodePort**
```shell
helm install juno ./chart/ \
  -f ./deployments/on-prem-sig/ingress/node-port.yaml \
  ...
  -f ./.values.yaml
```
