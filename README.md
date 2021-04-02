# CrowdStrike Falcon Helm Chart and Helm Operator

[![Artifact HUB](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/falcon-helm)](https://artifacthub.io/packages/search?repo=falcon-helm) [![Docker Repository on Quay](https://quay.io/repository/crowdstrike/falcon-helm-operator/status "Docker Repository on Quay")](https://quay.io/repository/crowdstrike/falcon-helm-operator)

[Falcon](https://www.crowdstrike.com/) is the [CrowdStrike](https://www.crowdstrike.com/)
platform purpose-built to stop breaches via a unified set of cloud-delivered
technologies that prevent all types of attacks — including malware and much
more.

The CrowdStrike Falcon Helm Chart and the Helm Operator are designed to deploy
and manage the Falcon sensor on your Kubernetes cluster of choice.
[Helm Charts](https://helm.sh/docs/topics/charts/Helm) and Helm-based Kubernetes
Operators are packaging methodologies for Kubernetes. Which methodology you use
is dependent on what the Kubernetes vendor and implementation supports.

- [Kubernetes Cluster Compatability](#kubernetes-cluster-compatability)
- [Dependencies](#dependencies)
- [Deployment Considerations](#deployment-considerations)
- [Quick Note Regarding Support](#quick-note-regarding-support)
- [Using Helm Operator](#using-helm-operator)
  * [Deploy using Make from the Git Repository](#deploy-using-make-from-the-git-repository)
  * [Undeploy using Make from the Git Repository](#undeploy-using-make-from-the-git-repository)
- [Using Helm Charts](#using-helm-charts)
  * [Installing from Helm Repository](#installing-from-helm-repository)
    + [Add the CrowdStrike Falcon Helm repository](#add-the-crowdstrike-falcon-helm-repository)
    + [Install CrowdStrike Falcon Helm Chart](#install-crowdstrike-falcon-helm-chart)
  * [Install using Helm from the Git Repository](#install-using-helm-from-the-git-repository)
  * [Install using Make from the Git Repository](#install-using-make-from-the-git-repository)
  * [Uninstalling](#uninstalling)
    + [Uninstall using Helm](#uninstall-using-helm)
    + [Uninstall using Make from the Git Repository](#uninstall-using-make-from-the-git-repository)

# Kubernetes Cluster Compatability

The Falcon Helm chart has been tested to deploy on the following Kubernetes distributions:

* Amazon Elastic Kubernetes Service (EKS)
* Azure Kubernetes Service (AKS) - Linux Nodes Only
* Google Kubernetes Engine (GKE)
* Rancher K3s
  * Nodes must be Linux distributions supported by CrowdStrike. See [https://falcon.crowdstrike.com/support/documentation/20/falcon-sensor-for-linux#operating-systems](https://falcon.crowdstrike.com/support/documentation/20/falcon-sensor-for-linux#operating-systems) for supported Linux distributions and kernels.
* Red Hat OpenShift Container Platform 4.6+

The Falcon Helm Operator has been tested to deploy on the following Kubernetes
distributions:

* Red Hat OpenShift Container Platform 4.6+

# Dependencies

1. Requires a x86_64 Kubernetes cluster
1. Must be a CrowdStrike customer with access to the Falcon Linux Sensor and Falcon Container downloads.
1. Before deploying the Helm chart, you should have a Falcon Linux Sensor in the container registry before installing the Helm Chart. See the Deployment Considerations for more.
1. Helm 3.x is installed and supported by the Kubernetes vendor.

# Deployment Considerations

To ensure a successful deployment, you will want to ensure that:
1. By default when deploying using a Helm Chart, the Helm Chart installs in the `default` namespace. Best
   practices for deploying to Kubernetes is to create a new namespace.
   This can be done by adding `-n falcon-system --create-namespace` to your
   `helm install` command. You do not have to do this when using the Helm Operator.
1. You have access to a containerized falcon sensor image. This is most likely
   through a private image registry on your network or cloud provider. See
   [https://github.com/CrowdStrike/Dockerfiles](https://github.com/CrowdStrike/Dockerfiles)
   as an example of how to build a Falcon sensor for your registry.
1. The Falcon Linux Sensor (not the Falcon Container) should be used in the
   container image to deploy to Kubernetes nodes.
1. When deploying the Falcon Linux Sensor to a node, the container image should
   match the node's operating system. For example, if the node is running Red
   Hat Enterprise Linux 8.2, the container image should be based on Red Hat
   Enterprise Linux 8.2, etc. This is important to ensure sensor and image
   compatibility with the base node operating system.
1. You must have sufficient permissions to deploy Kubernetes DaemonSets. This is
   often received through cluster admin privileges.
1. Only deploying to Kubernetes nodes are supported at this time.
1. When deploying the Falcon Linux Sensor as a container to Kubernetes nodes, it
   is a requirement that the Falcon Sensor run as a privileged container so that
   the Sensor can properly work with the kernel. If this is unacceptable, you can
   install the Falcon Linux Sensor (still runs with privileges) using an RPM or
   DEB package on the nodes themselves. This assumes that you have the capability
   to actually install RPM or DEB packages on the nodes. If you do not have this
   capability and you want to protect the nodes, you have to install using a
   privileged container.

# Quick Note Regarding Support
🔥 🔥 🔥 🚒 🔥 🚒 🔥 🔥 🔥 🚒 🔥 🚒 🔥 🔥 🔥 🔥 🔥 🔥 🚒 🔥 🚒 🔥 🔥 🔥 🚒 🔥 🚒 🔥 🔥 🔥 
 
The Helm chart and operator code is in development, and not (yet) supported!

🔥 🔥 🔥 🚒 🔥 🚒 🔥 🔥 🔥 🚒 🔥 🚒 🔥 🔥 🔥 🔥 🔥 🔥 🚒 🔥 🚒 🔥 🔥 🔥 🚒 🔥 🚒 🔥 🔥 🔥 

On 24-FEB-2021, CrowdStrike announced (via [press release](https://www.crowdstrike.com/press-releases/advanced-threat-protection-for-cloud-and-container-workloads/)) technology previews are available for deploying Falcon into Azure Kubernetes Service (AKS), Google Kubernetes Engine (GKE), Rancher, and Red Hat OpenShift Container Platform (OCP).

This Helm operator and chart are being developed to automate Falcon sensor deployments into Kubernetes environments. As large-scale testing continues, please note that this Helm chart (and more broadly, sensor deployment into AKS, GKE, Rancher, or OCP) is not yet officially supported nor recommended for production workloads. 

* To provide feedback regarding this Helm operator and/or chart, please open a ticket in this repo.
* To provide feedback when containerizing the Linux sensor, please open a ticket/bug report with CrowdStrike Support

# Using Helm Operator

## Deploy using Make from the Git Repository

1. Deploy the Helm operator
   ```
   make deploy IMG=quay.io/crowdstrike/falcon-helm-operator:latest
   ```

2. Customize the Helm operator deployment by adding your CID and configuring the
   registry containing the Falcon sensor in
   `config/samples/crowdstrike_v1alpha1_falconsensor.yaml`.

3. Apply the customized Helm operator resource
   ```
   kubectl apply -f config/samples/crowdstrike_v1alpha1_falconsensor.yaml
   ```

## Undeploy using Make from the Git Repository

3. Delete the customized Helm operator resouce
   ```
   kubectl delete falconsensor.falcon.crowdstrike.com/falcon-helm
   ```

1. Uninstall the Helm operator
   ```
   make undeploy
   ```

# Using Helm Charts
## Installing from Helm Repository
### Add the CrowdStrike Falcon Helm repository

```
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
```

### Install CrowdStrike Falcon Helm Chart

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

### Install using Helm from the Git Repository

To install using Helm, run the following command replacing
`<Your_CrowdStrike_CID>` with your CrowdStrike Customer ID:

```
helm install --set falcon.cid=<Your_CrowdStrike_CID> -n falcon-system --create-namespace falcon-helm ./helm-charts/falcon-sensor
```

You can use multiple `--set` arguments for configuring the Falcon Helm Chart
according to your environment. See the [values yaml file for more configuration options](helm-charts/falcon-sensor/values.yaml).

Alternatively, instead of using multiple `--set` arguments, you can create a
yaml file that customizes the default Helm Chart configurations.

For example, changing the default Kubernetes node image repository using a yaml
customization file called `custom_repo.yaml`:

1. Create `custom_repo.yaml`:
   ```
   falcon:
     cid: <Your_CrowdStrike_CID>
   node:
     image:
       repository: <Your_Registry>/falcon-sensor
   ```

2. Run the `helm install` command specifying using `custom_repo.yaml`:
   ```
   helm install -f custom_repo.yaml -n falcon-system --create-namespace falcon-helm ./helm-charts/falcon-sensor
   ```

### Install using Make from the Git Repository

To install using a Makefile (assumes Helm is installed on your system), run the
following command replacing `<Your_CrowdStrike_CID>` with your CrowdStrike
Customer ID:

```
make helm-install CID=<Your_CrowdStrike_CID>
```

## Uninstalling
### Uninstall using Helm

Assuming the Falcon helm chart is the same and has not been customized, run the
following command:

```
helm uninstall falcon-helm
```

### Uninstall using Make from the Git Repository

```
make helm-uninstall
```
