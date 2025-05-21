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
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Installation](#installation)

### Introduction

Juno Bootstrap is a collection of Helm charts that deploys the required services to run Juno on Kubernetes. 


### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)

## Configuration

Juno uses Helm to bootstrap an existing cluster with the minimum required services. We ship a default `values.yaml` 
file that contains the required fields that are needed to deploy a Juno ready cluster. All fields are required unless
commented out. We recommend copying the default `values.yaml` file to `.values.yaml` and editing it to set the desired 
configuration for your deployment.

1. Copy the default `values.yaml` file to `.values.yaml`:
    ```bash
    cp values.yaml .values.yaml
    ```
2. Edit the `.values.yaml` file to set the desired configuration for your deployment. All fields that are required are commented with `(REQUIRED)`.

## Installation

1. Create the ArgoCD namespace:
    ```bash
    kubectl create namespace argocd
    ```
2. Install ArgoCD:
    ```bash
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```
3. Configure your deployment using the predefined [Juno Deployment Configurations](/deployments/README.md) (optional, but recommended).
4. Install Juno:
   1. If you are using the predefined Juno deployment configurations, run the following command (replace the `<predefined deployment>` with the path to the predefined Juno deployment configuration):
       ```bash
          helm install juno ./chart/ \
           -f <predefined deployment> \
           -f <predefined deployment> \
           -f ./.values.yaml
       ```
    2. If you are using your own configuration, run the following command:
         ```bash
             helm install juno ./chart/ \
              -f ./.values.yaml
         ```
