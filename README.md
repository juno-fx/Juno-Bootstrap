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
- [Installation](#installation)

### Introduction

Juno Bootstrap is a collection of Helm charts that deploys the required services to run Juno on Kubernetes. 


### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)


## Installation

1. Create the ArgoCD namespace:
    ```bash
    kubectl create namespace argocd
    ```
2. Install ArgoCD:
    ```bash
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```
