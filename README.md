<br />
<p align="center">
    <img src="assets/logo.png"/>
    <h3 align="center">Juno Bootstrap</h3>
    <p align="center">
        Deployment Bootstrap for Juno Deployments on Kubernetes
    </p>
</p>

<br />

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Introduction](#introduction)
- [Manual Installation](#manual-installation)
  - [Prerequisites](#prerequisites)
  - [Configuration](#configuration)
  - [Installation](#installation)

### Introduction

Juno Bootstrap is a collection of Helm charts that deploys the required services to run Juno on Kubernetes. 
The preferred method of deploying is via the one-click installer which walks you through the installation 
process and allows you to select from predefined Juno deployment configurations.

```shell
curl -s https://raw.githubusercontent.com/juno-fx/Juno-Bootstrap/refs/heads/main/bootstrap.sh | bash -
```

```shell
===============================================
   🚀 Official Juno Innovations One Click Orion Installer
===============================================

❓ Checking available host resources...
✅ Host meets minimum installed Memory
✅ Host meets minimum CPU core count
🏆 All resource requirements met!
🌐 Enter the server's public DNS hostname [aurora]: 
📧 Enter the owner email: blah@email.com
🔑 Enter the temporary password for the owner: 
🔐 Confirm password for the owner: 
👤 Enter the username (letters only): blah
🆔 Enter the UID for that user: 1005

===============================================
   ✅ Collected Installation Information
-----------------------------------------------
Hostname:        aurora
Owner Email:     blah@email.com
Owner Password:  [hidden]
Username:        blah
UID:             1005
===============================================

❓ Is this information correct? [y/N]: y
👍 Proceeding...
📦 Is this an offline installation? [y/N]: n
📝 Writing final .values.yaml...
✅ .values.yaml has been created with your configuration.

===============================================
   🌐 Choose Deployment Target
===============================================
1) Existing Cluster
2) On Prem K3s 
```

1. Selecting "Existing Cluster" will handle the full helm install for you based on the answers you provided.
2. Selecting "On Prem K3s" will install K3s on your machine and then handle the helm install for you based on the answers you provided.

## Manual Installation

Advanced users may choose to bypass the one-click installer and deploy Juno manually using Helm. 
This method requires more familiarity with Kubernetes and Helm, but allows for more customization 
and control over the deployment process.

### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
- A Kubernetes cluster (can be local or cloud-based) with access to the cluster context configured in `kubectl`.

## Configuration

Juno uses Helm to bootstrap an existing cluster with the minimum required services. We ship a default `values.yaml` 
file that contains the required fields that are needed to deploy a Juno ready cluster. All fields are required unless
commented out. We recommend copying the default `values.yaml` file to `.values.yaml` and editing it to set the desired 
configuration for your deployment.

1. Clone the Juno Bootstrap repository:
    ```bash
    git clone https://github.com/juno-fx/Juno-Bootstrap.git
    cd Juno-Bootstrap
    ```
2. Copy the default `values.yaml` file to `.values.yaml`:
    ```bash
    cp values.yaml .values.yaml
    ```
3. Edit the `.values.yaml` file to set the desired configuration for your deployment.
   ```yaml
   genesis:
     url: "https://github.com/juno-fx/Genesis-Deployment.git"
     version: "v3.0.0-beta.1"
     config:
       host: my-genesis.example.com
       env:
          BASIC_AUTH_EMAIL: "your-email@example.com"
          BASIC_AUTH_PASSWORD: "your-password"
       titan:
         owner: my-username
         uid: 1050
         email: your-email@example.com
   ```

## Installation

1. Create the ArgoCD namespace:
    ```bash
    kubectl create namespace argocd
    ```
2. Install ArgoCD:
    ```bash
    kubectl create -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```
3. Install Juno using Helm:
   ```bash
       helm install juno ./chart/ \
        -f ./.values.yaml
   ```
