# Juno Service Configuration

Juno ships preconfigured values files that override the base chart depending on the desired configuration. These are 
organized into special interest groups (SIGs) to allow for easier management of the configuration.

## Prerequisites

- Follow the [installation instructions](../README.md#installation) to install the required services.

## Build Your Deployment

Building your deployment using Juno's preconfigured values files is as simple as running the following command 
from the root of the repository:

```bash
helm install juno ./chart/ -f ./deployments/<sig>/<service>/<configuration>.yaml
```

For example, to deploy Juno on-premise using the ingress preconfigured via hostPort and using the pre-install NVIDIA 
drivers, you would run the following command:

```bash
helm install juno ./chart/ \
  -f ./deployments/on-prem-sig/ingress/host-port.yaml \
  -f ./deployments/on-prem-sig/gpu/drivers-preinstalled.yaml \
  -f ./.values.yaml
```


> [!IMPORTANT]  
> Keep in mind that order matters here. We are adding our `.values.yaml` at the end of the command so we can override 
> with our own settings.


## Special Interests Groups

Each SIG is responsible for a specific set of services and configurations pertaining to a deployment environment. The SIGs are:

- **[On Premise](on-prem-sig/README.md)**: This SIG is responsible for deploying Juno on-premise.
- **Cloud**: This SIG is responsible for deploying Juno on cloud providers. (Coming Soon)
