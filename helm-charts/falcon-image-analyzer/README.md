# CrowdStrike Falcon Helm Chart

[Falcon](https://www.crowdstrike.com/) is the [CrowdStrike](https://www.crowdstrike.com/)
platform purpose-built to stop breaches via a unified set of cloud-delivered
technologies that prevent all types of attacks — including malware and much
more.

# Kubernetes Cluster Compatability

The Falcon Helm chart has been tested to deploy on the following Kubernetes distributions:

* Amazon Elastic Kubernetes Service (EKS)
  * Daemonset (node) sensor support for EKS nodes
  * Container sensor support for EKS Fargate nodes
* Azure Kubernetes Service (AKS)
* Google Kubernetes Engine (GKE)
* Rancher K3s
* OpenShift Kubernetes

# Dependencies

1. Requires a x86_64 Kubernetes cluster
1. Before deploying the Helm chart, you should have a Falcon Linux Sensor and/or Falcon Container sensor in your own container registry or use CrowdStrike's registry before installing the Helm Chart. See the Deployment Considerations for more.
1. Helm 3.x is installed and supported by the Kubernetes vendor.

# Installation

### Add the CrowdStrike Falcon Helm repository

```
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
```

### Update the local Helm repository Cache

```
helm repo update
```

# Falcon Configuration Options

The following tables lists the Falcon Sensor configurable parameters and their default values.

| Parameter                              | Description                                                                                                                                                                     | Default                                                                           |
|:---------------------------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:----------------------------------------------------------------------------------|
| `daemonset.enabled`                    | set to true if running in watcher mode i.e. `crowdstrikeConfig.agentRunmode` is `socket`                                                                                        | false                                                                             |
| `deployment.enabled`                   | set to true if running in watcher mode i.e. `crowdstrikeConfig.agentRunmode` is `watcher`                                                                                       | false                                                                             |
| `image.repo`                           | iar image repo name.                                                                                                                                                            | `registry.crowdstrike.com/falcon-imageanalyzer/us-1/release/falcon-imageanalyzer` |
| `image.tag`                            | image tag version                                                                                                                                                               | None                                                                              |
| `azure.enabled`                        | set to true if cluster is azure aks OR self managed on azure nodes                                                                                                              | false                                                                             |
| `azure.azureConfig`                    | azure  config file path                                                                                                                                                         | `/etc/kubernetes/azure.json`                                                      |
| `gcp.enabled`                          | set to true if cluster is azure aks OR self managed on google cloud gcp nodes                                                                                                   | false                                                                             |
| `crowdstrikeConfig.clusterName`        | cluster name                                                                                                                                                                    | None                                                                              |
| `crowdstrikeConfig.enableDebug`        | set to true for debug level log verbosity                                                                                                                                       | false                                                                             |
| `crowdstrikeConfig.clientID`           | crowdstrike falcon OAuth API Client ID                                                                                                                                          | None                                                                              |
| `crowdstrikeConfig.clientSecret`       | crowdstrike falcon OAuth API Client secret                                                                                                                                      | None                                                                              |
| `crowdstrikeConfig.cid`                | customer ID ( CID )                                                                                                                                                             | None                                                                              |
| `crowdstrikeConfig.dockerAPIToken`     | Crowdstrike Artifactory Image Pull Token for pulling IAR image directly from  `registry.crowdstrike.com`                                                                        | None                                                                              |
| `crowdstrikeConfig.existingSecret`     | existing secret ref name of the customer kubernetes cluster                                                                                                                     | None                                                                              |
| `crowdstrikeConfig.agentRunmode`       | agent run mode `watcher` or `socket` for kubernetes set this along with deployment.enabled and daemonset.enabled respectively                                                   | None                                                                              |
| `crowdstrikeConfig.agentRegion`        | region of the crowdstike api to connect to us-1/us-2/eu-1                                                                                                                       | None                                                                              |
| `crowdstrikeConfig.agentRuntime`       | the underlying runtime of the OS. docker/containerd/podman/crio . ONLY TO BE USED with `crowdstrikeConfig.agentRunmode` = `socket`                                              | None                                                                              |
| `crowdstrikeConfig.agentRuntimeSocket` | the unix socket path for the runtime socket .ef. `unix///var/run/docker.sock` . ONLY TO BE USED with `crowdstrikeConfig.agentRunmode` = `socket`                                | None                                                                              |




## Installing on Kubernetes Cluster Nodes

### Deployment Considerations

To ensure a successful deployment, you will want to ensure that:
1. By default, the Helm Chart installs in the `default` namespace. Best practices for deploying to Kubernetes is to create a new namespace. This can be done by adding `--create-namespace -n falcon-image-analyzer` to your `helm install` command. The namespace can be any name that you wish to use.
1. You must be a cluster administrator to deploy Helm Charts to the cluster.
1. CrowdStrike's Helm Chart is a project, not a product, and released to the community as a way to automate sensor deployment to kubernetes clusters. The upstream repository for this project is [https://github.com/CrowdStrike/falcon-helm](https://github.com/CrowdStrike/falcon-helm).

### Pod Security Standards

Starting with Kubernetes 1.25, Pod Security Standards will be enforced. Setting the appropriate Pod Security Standards policy needs to be performed by adding a label to the namespace. Run the following command replacing `my-existing-namespace` with the namespace that you have installed the falcon sensors e.g. `falcon-system`..
```
kubectl label --overwrite ns my-existing-namespace \
  pod-security.kubernetes.io/enforce=privileged
```

If desired to silence the warning and change the auditing level for the Pod Security Standard, add the following labels
```
kubectl label ns --overwrite my-existing-namespace pod-security.kubernetes.io/audit=privileged
kubectl label ns --overwrite my-existing-namespace pod-security.kubernetes.io/warn=privileged
```

### Install CrowdStrike Falcon Helm Chart on Kubernetes Nodes

Before installing the IAR. please set the values of the helm chart variables and save in some path as yaml file.

```
helm upgrade --install -f path-to-my-values.yaml \ 
      --create-namespace -n falcon-image-analyzer imageanalyzer falcon-helm crowdstrike/falcon-image-analyzer
```


For more details please see the [falcon-helm](https://github.com/CrowdStrike/falcon-helm) repository.

```
helm show values crowdstrike/falcon-sensor
```


### Uninstall Helm Chart
To uninstall, run the following command:
```
helm uninstall imageanalyzer -n falcon-image-analyzer && kubectl delete namespace falcon-image-analyzer
```

