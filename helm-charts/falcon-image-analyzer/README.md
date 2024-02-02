# CrowdStrike Falcon Image Analyzer Helm Chart

[Falcon](https://www.crowdstrike.com/) is the [CrowdStrike](https://www.crowdstrike.com/)
platform purpose-built to stop breaches via a unified set of cloud-delivered
technologies that prevent all types of attacks — including malware and much
more.

## Kubernetes cluster compatability

The Falcon Image Analyzer Helm chart has been tested to deploy on the following Kubernetes distributions:

* Amazon Elastic Kubernetes Service (EKS) - EKS and EKS Fargate
* Azure Kubernetes Service (AKS)
* Google Kubernetes Engine (GKE)
* SUSE Rancher K3s
* Red Hat OpenShift Kubernetes

## Dependencies

1. Requires a x86_64 Kubernetes cluster
1. Before deploying the Helm chart, you should have the `falcon-imageanalyzer` container image in your own container registry, or use CrowdStrike's registry before installing the Helm chart. See the [Deployment Considerations](#deployment-considerations) for more.
1. Helm 3.x is installed and supported by the Kubernetes vendor.

## Installation

### Add the CrowdStrike Falcon Helm repository

```
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
```

### Update the local Helm repository cache

```
helm repo update
```

## Falcon configuration options

The following tables list the Falcon sensor configurable parameters and their default values.

| Parameter                              | Description                                                                                                                                              | Default                                                                           |
|:---------------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------|:----------------------------------------------------------------------------------|
| `image.repo`                           | IAR image repo name                                                                                                                                      | `registry.crowdstrike.com/falcon-imageanalyzer/us-1/release/falcon-imageanalyzer` |
| `image.tag`                            | Image tag version                                                                                                                                        | None                                                                              |
| `azure.enabled`                        | Set to `true` if cluster is Azure AKS or self-managed on Azure nodes.                                                                                    | false                                                                             |
| `azure.azureConfig`                    | Azure  config file path                                                                                                                                  | `/etc/kubernetes/azure.json`                                                      |
| `gcp.enabled`                          | Set to `true` if cluster is Gogle GKE or self-managed on Google Cloud GCP nodes.                                                                         | false                                                                             |
| `crowdstrikeConfig.clusterName`        | Cluster name                                                                                                                                             | None                                                                              |
| `crowdstrikeConfig.enableDebug`        | Set to `true` for debug level log verbosity.                                                                                                             | false                                                                             |
| `crowdstrikeConfig.clientID`           | CrowdStrike Falcon OAuth API Client ID                                                                                                                   | None                                                                              |
| `crowdstrikeConfig.clientSecret`       | CrowdStrike Falcon OAuth API Client secret                                                                                                               | None                                                                              |
| `crowdstrikeConfig.cid`                | Customer ID (CID)                                                                                                                                        | None                                                                              |
| `crowdstrikeConfig.dockerAPIToken`     | Crowdstrike Artifactory Image Pull Token for pulling IAR image directly from  `registry.crowdstrike.com`                                                 | None                                                                              |
| `crowdstrikeConfig.existingSecret`     | Existing secret ref name of the customer Kubernetes cluster                                                                                              | None                                                                              |
| `crowdstrikeConfig.agentRunmode`       | Agent run mode `watcher` or `socket` for Kubernetes.                                                                                                     | None                                                                              |
| `crowdstrikeConfig.agentRegion`        | Region of the CrowdStrike API to connect to us-1/us-2/eu-1                                                                                               | None                                                                              |
| `crowdstrikeConfig.agentRuntime`       | The underlying runtime of the OS. docker/containerd/podman/crio. ONLY TO BE USED with `crowdstrikeConfig.agentRunmode` = `socket`                        | None                                                                              |
| `crowdstrikeConfig.agentRuntimeSocket` | The unix socket path for the runtime socket. For example: `unix///var/run/docker.sock`. ONLY TO BE USED with `crowdstrikeConfig.agentRunmode` = `socket` | None                                                                              |

## Installing on Kubernetes cluster nodes

### Deployment considerations

For a successful deployment, you will want to ensure that:
1. By default, the Helm chart installs in the `default` namespace. Best practices for deploying to Kubernetes is to create a new namespace. This can be done by adding `--create-namespace -n falcon-image-analyzer` to your `helm install` command. The namespace can be any name that you wish to use.
1. You must be a cluster administrator to deploy Helm charts to the cluster.
1. CrowdStrike's Helm chart is a project, not a product, and released to the community as a way to automate sensor deployment to Kubernetes clusters. The upstream repository for this project is [https://github.com/CrowdStrike/falcon-helm](https://github.com/CrowdStrike/falcon-helm).

### Pod Security Standards

Starting with Kubernetes 1.25, Pod Security Standards will be enforced. Setting the appropriate Pod Security Standards policy needs to be performed by adding a label to the namespace. Run the following command, and replace `my-existing-namespace` with the namespace that you have installed the falcon sensors, for example: `falcon-image-analyzer`.
```
kubectl label --overwrite ns my-existing-namespace \
  pod-security.kubernetes.io/enforce=privileged
```

If you want to silence the warning and change the auditing level for the Pod Security Standard, add the following labels:
```
kubectl label ns --overwrite my-existing-namespace pod-security.kubernetes.io/audit=privileged
kubectl label ns --overwrite my-existing-namespace pod-security.kubernetes.io/warn=privileged
```

### Install CrowdStrike Falcon Helm chart on Kubernetes nodes

Before you install IAR, set the Helm chart variables and add them to the `values.yaml` file. Then, run the following to install IAR:

```
helm upgrade --install -f path-to-my-values.yaml \ 
      --create-namespace -n falcon-image-analyzer imageanalyzer falcon-helm crowdstrike/falcon-image-analyzer
```


For more details, see the [falcon-helm](https://github.com/CrowdStrike/falcon-helm) repository.

```
helm show values crowdstrike/falcon-sensor
```

## Uninstall Helm chart

To uninstall, run the following command:
```
helm uninstall imageanalyzer -n falcon-image-analyzer && kubectl delete namespace falcon-image-analyzer
```
