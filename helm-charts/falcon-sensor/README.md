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

# Dependencies

1. Requires a x86_64 or ARM64 Kubernetes cluster
1. Must be a CrowdStrike customer with access to the Falcon Linux Sensor (container image) and Falcon Container from the CrowdStrike Container Registry.
1. Kubernetes nodes must be Linux distributions supported by CrowdStrike.
1. Before deploying the Helm chart, you should have a Falcon Linux Sensor and/or Falcon Container sensor in your own container registry or use CrowdStrike's registry before installing the Helm Chart. See the Deployment Considerations for more.
1. Helm 3.x is installed and supported by the Kubernetes vendor.

## Helm Chart Support for Falcon Sensor Versions

| Helm chart Version      | Falcon Sensor Version             |
|:------------------------|:----------------------------------|
| `<= 1.26.x`             | `< 7.05.x`                        |
| `>= 1.27.x`             | `>= 7.06.x`                       |

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

| Parameter                   | Description                                               | Default               |
|:----------------------------|:----------------------------------------------------------|:----------------------|
| `falcon.cid`                | CrowdStrike Customer ID (CID)                             | None       (Required) |
| `falcon.apd`                | App Proxy Disable (APD)                                   | None                  |
| `falcon.aph`                | App Proxy Hostname (APH)                                  | None                  |
| `falcon.app`                | App Proxy Port (APP)                                      | None                  |
| `falcon.trace`              | Set trace level. (`none`,`err`,`warn`,`info`,`debug`)     | `none`                |
| `falcon.feature`            | Sensor Feature options                                    | None                  |
| `falcon.billing`            | Utilize default or metered billing                        | None                  |
| `falcon.tags`               | Comma separated list of tags for sensor grouping          | None                  |
| `falcon.provisioning_token` | Provisioning token value                                  | None                  |


## Installing on Kubernetes Cluster Nodes

### Deployment Considerations

To ensure a successful deployment, you will want to ensure that:
1. By default, the Helm Chart installs in the `default` namespace. Best practices for deploying to Kubernetes is to create a new namespace. This can be done by adding `-n falcon-system --create-namespace` to your `helm install` command. The namespace can be any name that you wish to use.
1. The Falcon Linux Sensor (not the Falcon Container) should be used as the container image to deploy to Kubernetes nodes.
1. You must be a cluster administrator to deploy Helm Charts to the cluster.
1. When deploying the Falcon Linux Sensor (container image) to Kubernetes nodes, it is a requirement that the Falcon Sensor run as a privileged container so that the Sensor can properly work with the kernel. This is a requirement for any kernel module that gets deployed to any container-optimized operating system regardless of whether it is a security sensor, graphics card driver, etc.
1. The Falcon Linux Sensor should be deployed to Kubernetes environments that allow node access or installation via a Kubernetes DaemonSet.
1. The Falcon Linux Sensor will create `/opt/CrowdStrike` on the Kubernetes nodes. DO NOT DELETE this folder.
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

```
helm upgrade --install falcon-helm crowdstrike/falcon-sensor \
    --set falcon.cid="<CrowdStrike_CID>" \
    --set node.image.repository="<Your_Registry>/falcon-node-sensor"
```

Above command will install the CrowdStrike Falcon Helm Chart with the release name `falcon-helm` in the namespace your `kubectl` context is currently set to.
You can install also install into a customized namespace by running the following:

```
helm upgrade --install falcon-helm crowdstrike/falcon-sensor \
    -n falcon-system --create-namespace \
    --set falcon.cid="<CrowdStrike_CID>" \
    --set node.image.repository="<Your_Registry>/falcon-node-sensor"
```

For more details please see the [falcon-helm](https://github.com/CrowdStrike/falcon-helm) repository.

### Node Configuration

The following tables lists the more common configurable parameters of the chart and their default values for installing on a Kubernetes node.

| Parameter                       | Description                                                                                                                                                                                                                                                                                           | Default                                                                                                                    |
|:--------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:---------------------------------------------------------------------------------------------------------------------------|
| `node.enabled`                  | Enable installation on the Kubernetes node                                                                                                                                                                                                                                                            | `true`                                                                                                                     |
| `node.backend`                  | Choose sensor backend (`kernel`,`bpf`).<br><br>**NOTE:** Sensor 6.49+ only                                                                                                                                                                                                                            | bpf                                                                                                                        |
| `node.gke.autopilot`            | Enable if running on GKE Autopilot clusters                                                                                                                                                                                                                                                           | `false`                                                                                                                    |
| `node.image.repository`         | Falcon Sensor Node registry/image name                                                                                                                                                                                                                                                                | `falcon-node-sensor`                                                                                                       |
| `node.image.tag`                | The version of the official image to use                                                                                                                                                                                                                                                              | `latest`   (Use node.image.digest instead for security and production)                                                     |
| `node.image.digest`             | The sha256 digest of the official image to use                                                                                                                                                                                                                                                        | None       (Use instead of the image tag for security and production)                                                      |
| `node.image.pullPolicy`         | Policy for updating images                                                                                                                                                                                                                                                                            | `Always`                                                                                                                   |
| `node.image.pullSecrets`        | Pull secrets for private registry                                                                                                                                                                                                                                                                     | None       (Conflicts with node.image.registryConfigJSON)                                                                  |
| `node.image.registryConfigJSON` | base64 encoded docker config json for the pull secret                                                                                                                                                                                                                                                 | None       (Conflicts with node.image.pullSecrets)                                                                         |
| `node.daemonset.resources`      | Configure Node sensor resource requests and limits (eBPF mode only)<br><br><div class="warning">:warning: **Warning**:<br>If you configure resources, you must configure the CPU and Memory Resource requests and limits correctly for your node instances for the node sensor to run properly!</div> | None       (Minimum setting of 250m CPU and 500Mi memory allowed). Default for GKE Autopilot is 750m CPU and 1.5Gi memory. |
| `node.cleanupOnly`              | Run the cleanup Daemonset only.                                                                                                                                                                                                                                                                       | `false`    Requires `node.hooks.postDelete.enabled: true`                                                                  |
| `falcon.cid`                    | CrowdStrike Customer ID (CID)                                                                                                                                                                                                                                                                         | None       (Required if falconSecret.enabled is false)                                                                     |
| `falcon.cloud`                  | CrowdStrike cloud region (`us-1`, `us-2`, `eu-1`, `us-gov-1`, `us-gov-2`)<br><br>**NOTE:** This option is supported by Falcon sensor version 7.28 and above                                                                                                                                           | None                                                                                                                       |
| `falconSecret.enabled`          | Enable k8s secrets to inject sensitive Falcon values                                                                                                                                                                                                                                                  | false       (Must be true if falcon.cid is not set)                                                                        |
| `falconSecret.secretName`       | Existing k8s secret name to inject sensitive Falcon values.<br> The secret must be under the same namespace as the sensor deployment.                                                                                                                                                                 | None       (Existing secret must include `FALCONCTL_OPT_CID`)                                                              |
| `falcon.cluster_name`                    | When running on an unmanaged K8S cluster, set a cluster name. When running on managed K8S cluster name is resolved cloud-side |  None

`falcon.cid` and `node.image.repository` are required values.

For a complete listing of configurable parameters, run the following command:

```
helm show values crowdstrike/falcon-sensor
```

### GKE Autopilot Configuration
#### Configuring the AllowlistSynchronizer
Running Daemonset Pods with privileged access on GKE Autopilot requires special configurations due to default security restrictions. To enable these privileged Pods, you need to configure an AllowlistSynchronizer. This resource applies CrowdStrike specific WorkloadAllowlists to your cluster, which the GKE Autopilot validating webhook uses to approve Pod deployments based on their manifest spec and image digests. Follow these steps to properly configure the AllowlistSynchronizer:
Comment


1. Create a file named `allowlist-synchronizer.yaml` with the following contents:
```
apiVersion: auto.gke.io/v1
kind: AllowlistSynchronizer
metadata:
  name: crowdstrike-synchronizer
spec:
  allowlistPaths:
  - CrowdStrike/falcon-sensor/*
```
2. Apply the AllowlistSynchronizer to your cluster:
```
kubectl apply -f allowlist-synchronizer.yaml
```

3. Ensure the AllowlistSynchronizer is running:
```
kubectl get allowlistsynchronizers
```

4. Ensure the AllowlistSynchronizer has fetched the WorkloadAllowlist:
```
kubectl get workloadallowlists
```
An example output of the above command is:
```
NAME                                                  AGE
crowdstrike-falconsensor-cleanup-allowlist-v1.0.0     7d
crowdstrike-falconsensor-cleanup-allowlist-v1.0.1     7d
crowdstrike-falconsensor-cleanup-allowlist-v1.0.2     7d
crowdstrike-falconsensor-deploy-allowlist-v1.0.0      7d
crowdstrike-falconsensor-deploy-allowlist-v1.0.1      7d
crowdstrike-falconsensor-deploy-allowlist-v1.0.2      7d
crowdstrike-falconsensor-deploy-allowlist-v1.0.3      6h40m
crowdstrike-falconsensor-falconctl-allowlist-v1.0.0   7d
crowdstrike-falconsensor-falconctl-allowlist-v1.0.1   7d
```
##### WorkloadAllowlist Definitions
The WorkloadAllowlists serve the following purposes:
- crowdstrike-falconsensor-cleanup-allowlist-vX.X.X: Authorizes the Falcon Sensor Cleanup DaemonSet to operate within the cluster.
- crowdstrike-falconsensor-deploy-allowlist-vX.X.X: Permits the deployment and execution of the Falcon Sensor Deploy DaemonSet in the cluster environment.
- crowdstrike-falconsensor-falconctl-allowlist-vX.X.X: Enables the Falconctl job to run, facilitating sensor configuration and management tasks.

> [!NOTE]
> Additional information about AllowlistSynchronizer can be found here: [https://cloud.google.com/kubernetes-engine/docs/reference/crds/allowlistsynchronizer](https://cloud.google.com/kubernetes-engine/docs/reference/crds/allowlistsynchronizer)

#### Obtaining an Authorized Image
WorkloadAllowlists ensure that only authorized container images are deployed to pods by verifying their image digests. To view the list of approved image digests, execute the following command:
```
kubectl get workloadallowlists <crowdstrike-falconsensor-XXXXXXX-allowlist-vX.X.X>  -o=jsonpath='{range .containerImageDigests[*].imageDigests[*]}{@}{"\n"}{end}'
```
To obtain the Falcon Node sensor image, you have two options:

1. Pull directly from the CrowdStrike registry
2. Copy the image from the CrowdStrike registry to your private registry

For option 2, we provide an automation script to simplify the process:
[https://github.com/CrowdStrike/falcon-scripts/tree/main/bash/containers/falcon-container-sensor-pull](https://github.com/CrowdStrike/falcon-scripts/tree/main/bash/containers/falcon-container-sensor-pull)

When copying images to a private registry, it's crucial to preserve the image digest. We recommend using tools like Skopeo for this purpose, as they ensure the digest of the image remains the same after the transfer.

## Installing in Kubernetes Cluster as a Sidecar

### Deployment Considerations

To ensure a successful deployment, you will want to ensure that:
1. You must be a cluster administrator to deploy Helm Charts to the cluster.
1. When deploying the Falcon Container as a sidecar sensor, make sure that there are no firewall rules blocking communication to the Mutating Webhook. This will most likely result in a `context deadline exceeded` error. The default port for the Webhook is `4433`.
1. The Falcon Container as a sidecar sensor should be deployed to Kubernetes managed environments, or environments that do not allow node access or installation via a Kubernetes DaemonSet.
1. CrowdStrike's Helm Chart is a project, not a product, and released to the community as a way to automate sensor deployment to kubernetes clusters. The upstream repository for this project is [https://github.com/CrowdStrike/falcon-helm](https://github.com/CrowdStrike/falcon-helm).
1. Be aware that there is advanced Helm Chart functionality in use and those specific features may not work fully with GitOps tools like ArgoCD. The reason for this is that ArgoCD does not fully support Helm when compared to FluxCD. For features that do not work in this instance, disable those features until ArgoCD supports Helm correctly.

### Install CrowdStrike Falcon Helm Chart in Kubernetes Cluster as a Sidecar

```
helm upgrade --install falcon-helm crowdstrike/falcon-sensor \
    --set node.enabled=false \
    --set container.enabled=true \
    --set falcon.cid="<CrowdStrike_CID>" \
    --set container.image.repository="<Your_Registry>/falcon-sensor"
```

Above command will install the CrowdStrike Falcon Helm Chart with the release name `falcon-helm` in the namespace your `kubectl` context is currently set to.
You can install also install into a customized namespace by running the following:

```
helm upgrade --install falcon-helm crowdstrike/falcon-sensor \
    -n falcon-system --create-namespace \
    --set node.enabled=false \
    --set container.enabled=true \
    --set falcon.cid="<CrowdStrike_CID>" \
    --set container.image.repository="<Your_Registry>/falcon-sensor"
```

#### Note about installation namespace

For Kubernetes clusters <1.22 (or 1.21 where the NamespaceDefaultLabelName feature gate is NOT enabled), be sure to label your namespace for injector exclusion before installing the Container sensor:

```
kubectl create namespace falcon-system
kubectl label namespace falcon-system kubernetes.io/metadata.name=falcon-system
```

### Container Sensor Configuration

The following tables lists the more common configurable parameters of the chart and their default values for installing the Container sensor as a Sidecar.

| Parameter                                        | Description                                                                                                                             | Default                                                                                                                                                                                                                                                   |
|:-------------------------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `container.enabled`                              | Enable installation on the Kubernetes node                                                                                              | `false`                                                                                                                                                                                                                                                   |
| `container.replicas`                             | Configure replica count                                                                                                                 | `2`                                                                                                                                                                                                                                                       |
| `container.topologySpreadConstraints`            | Defines the way pods are spread across nodes                                                                                            | maxSkew: 1<br>topologyKey: kubernetes.io/hostname<br>whenUnsatisfiable: ScheduleAnyway<br>labelSelector:<br>&nbsp;&nbsp;&nbsp;matchLabels:<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;crowdstrike.com/component:&nbsp;crowdstrike-falcon-injector |
| `container.azure.enabled`                        | For AKS without the pulltoken option                                                                                                    | `false`                                                                                                                                                                                                                                                   |
| `container.azure.azureConfig`                    | Path to the Kubernetes Azure config file on worker nodes                                                                                | `/etc/kubernetes/azure.json`                                                                                                                                                                                                                              |
| `container.disableNSInjection`                   | Disable injection for all Namespaces                                                                                                    | `false`                                                                                                                                                                                                                                                   |
| `container.disablePodInjection`                  | Disable injection for all Pods                                                                                                          | `false`                                                                                                                                                                                                                                                   |
| `container.alternateMountPath`                   | Enable volume mounts at /falcon instead of /tmp for NVCF environment                                                                    | `false`                                                                                                                                                                                                                                                   |
| `container.certExpiration`                       | Certificate validity duration in number of days                                                                                         | `3650`                                                                                                                                                                                                                                                    |
| `container.registryCertSecret`                   | Name of generic Secret with additional CAs for external registries                                                                      | None                                                                                                                                                                                                                                                      |
| `container.image.repository`                     | Falcon Sensor Node registry/image name                                                                                                  | `falcon-sensor`                                                                                                                                                                                                                                           |
| `container.image.tag`                            | The version of the official image to use.                                                                                               | `latest` (Use container.image.digest instead for security and production.)                                                                                                                                                                                |
| `container.image.digest`                         | The sha256 digest of the official image to use.                                                                                         | None     (Use instead of image tag for security and production.)                                                                                                                                                                                          |
| `container.image.pullPolicy`                     | Policy for updating images                                                                                                              | `Always`                                                                                                                                                                                                                                                  |
| `container.image.pullSecrets.enable`             | Enable pull secrets for private registry                                                                                                | `false`                                                                                                                                                                                                                                                   |
| `container.image.pullSecrets.namespaces`         | List of Namespaces to pull the Falcon sensor from an authenticated registry                                                             | None                                                                                                                                                                                                                                                      |
| `container.image.pullSecrets.allNamespaces`      | Use Helm's lookup function to deploy the pull secret to all namespaces. Helm chart must be re-run everytime a new namespace is created. | `false`                                                                                                                                                                                                                                                   |
| `container.image.pullSecrets.registryConfigJSON` | base64 encoded docker config json for the pull secret                                                                                   | None                                                                                                                                                                                                                                                      |
| `container.image.sensorResources`                | The requests and limits of the sensor ([see example below](#example-using-containerimagesensorresources))                               | None                                                                                                                                                                                                                                                      |
| `falcon.cid`                                     | CrowdStrike Customer ID (CID)                                                                                                           | None       (Required if falconSecret.enabled is false)                                                                                                                                                                                                    |
| `falconSecret.enabled`                           | Enable k8s secrets to inject sensitive Falcon values                                                                                    | false       (Must be true if falcon.cid is not set)                                                                                                                                                                                                       |
| `falconSecret.secretName`                        | Existing k8s secret name to inject sensitive Falcon values.<br> The secret must be under the same namespace as the sensor deployment.   | None       (Existing secret must include `FALCONCTL_OPT_CID`)                                                                                                                                                                                             |

`falcon.cid` and `container.image.repository` are required values.

For a complete listing of configurable parameters, run the following command:

```
helm show values crowdstrike/falcon-sensor
```

#### Note about using --set with lists

If you need to provide a list of values to a `--set` command, you need to escape the commas between the values e.g. `--set falcon.tags="tag1\,tag2\,tag3"`

#### Example using container.image.sensorResources

When setting `container.image.sensorResources`, the simplest method would be to provide a values file to the `helm install` command.

Example:

```bash
helm upgrade --install falcon-helm crowdstrike/falcon-sensor \
    --set node.enabled=false \
    --set container.enabled=true \
    --set falcon.cid="<CrowdStrike_CID>" \
    --set container.image.repository="<Your_Registry>/falcon-sensor" \
    --values values.yaml
```

Where `values.yaml` is

```yaml
container:
  sensorResources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 10m
      memory: 20Mi
```

Of course, one could specify all options in the `values.yaml` file and skip the `--set` options altogether:

```yaml
node:
  enabled: false
container:
  enabled: true
  image:
    repository: "<Your_Registry>/falcon-sensor"
  sensorResources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 10m
      memory: 20Mi
falcon:
  cid: "<CrowdStrike_CID>"
```

If using a local values file is not an option, you could do this:

```bash
helm upgrade --install falcon-helm crowdstrike/falcon-sensor \
    --set node.enabled=false \
    --set container.enabled=true \
    --set falcon.cid="<CrowdStrike_CID>" \
    --set container.image.repository="<Your_Registry>/falcon-sensor" \
    --set container.sensorResources.limits.memory="128Mi" \
    --set container.sensorResources.limits.cpu="100m" \
    --set container.sensorResources.requests.memory="20Mi" \
    --set container.sensorResources.requests.cpu="10m"
```

### Uninstall Helm Chart
To uninstall, run the following command:
```
helm uninstall falcon-helm
```

To uninstall from a custom namespace, run the following command:
```
helm uninstall falcon-helm -n falcon-system
```

You may need/want to delete the falcon-system as well since helm will not do it for you:
```
kubectl delete ns falcon-system
```

### Troubleshooting
#### Falcon Sensor Cleanup Daemonset Fails
After sensor deletion, it's important to run the cleanup DaemonSet to remove the `/opt/CrowdStrike` directory from all nodes. This cleanup process is automatically executed during a `helm uninstall` by default. However, in large clusters, the cleanup may occasionally encounter issues due to the extended time required for full deployment.

Failing to remove the `/opt/CrowdStrike` directory may lead to these potential problems:

1. Unnecessary disk space consumption by the `/opt/CrowdStrike` directory.
2. Reuse of the previous Agent ID (AID) found in `/opt/CrowdStrike/falconstore` during subsequent sensor reinstallations.

If the automatic cleanup fails, you can manually run the cleanup DaemonSet by running the following:
```bash
helm install falcon-helm crowdstrike/falcon-sensor -n <NAMESPACE>\
  --set node.image.repository="<Your_Registry>/falcon-node-sensor>" \
  --set node.enabled=true \
  --set node.cleanupOnly=true
```
Validate removal of the `/opt/Crowdstrike` directory with the following command:
```bash
for node in $(kubectl get nodes -o name); do
  echo -n "$node: "
  kubectl debug $node -it --image=busybox -- /bin/sh -c 'if test -d /opt/CrowdStrike; then echo "CrowdStrike directory still exists"; else echo "CrowdStrike directory successfully deleted"; fi'
done
```
After validating the removal of the `/opt/Crowdstrike` directory, the cleanup Daemonset should be deleted:
```bash
helm uninstall falcon-helm -n <NAMESPACE>\
```
