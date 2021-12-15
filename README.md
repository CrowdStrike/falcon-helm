# CrowdStrike Falcon Helm Chart and Helm Operator

[![Artifact HUB](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/falcon-helm)](https://artifacthub.io/packages/search?repo=falcon-helm) [![Helm Operator on Quay](https://quay.io/repository/crowdstrike/falcon-helm-operator/status "Helm Operator on Quay")](https://quay.io/repository/crowdstrike/falcon-helm-operator) [![Helm Operator Lifecycle Manager (OLM) Bundle on Quay](https://quay.io/repository/crowdstrike/falcon-helm-operator-bundle/status "Helm Operator Lifecycle Manager OLM Bundle on Quay")](https://quay.io/repository/crowdstrike/falcon-helm-operator-bundle)

[Falcon](https://www.crowdstrike.com/) is the [CrowdStrike](https://www.crowdstrike.com/)
platform purpose-built to stop breaches via a unified set of cloud-delivered
technologies that prevent all types of attacks — including malware and much
more.

The CrowdStrike Falcon Helm Chart and the Helm Operator are designed to deploy
and manage the Falcon sensor on your Kubernetes cluster of choice.
[Helm Charts](https://helm.sh/docs/topics/charts) and Helm-based Kubernetes
Operators are packaging methodologies for Kubernetes. Which methodology you use
is dependent on what the Kubernetes vendor and implementation supports.

## Quick Note Regarding Support

The Falcon Helm is an open source project, not a CrowdStrike product. As such, it carries no formal support, expressed or implied.

On 24-FEB-2021, CrowdStrike announced (via [press release](https://www.crowdstrike.com/press-releases/advanced-threat-protection-for-cloud-and-container-workloads/)) technology previews are available for deploying Falcon into Azure Kubernetes Service (AKS), Google Kubernetes Engine (GKE), Rancher, and Red Hat OpenShift Container Platform (OCP).

* To provide feedback regarding this Helm operator and/or chart, please open a ticket in this repo.
* To provide feedback when containerizing the Linux sensor, please open a ticket/bug report with CrowdStrike Support

## Helm Chart
If you only use Helm Charts for Kubernetes installation, please read our [Falcon Helm Chart readme](helm-charts/falcon-sensor/README.md).

## Developer Guide
If you are a developer, please read our [Developer's Guide](docs/developer_guide.md).

# Helm Operator
## Kubernetes Cluster Compatability

The Falcon Helm Operator has been tested to deploy on the following Kubernetes
distributions:

* Red Hat OpenShift Container Platform 4.6+

## Dependencies

1. Requires a `x86_64` Kubernetes cluster
1. Must be a CrowdStrike customer with access to the Falcon Linux Sensor and Falcon Container downloads.
1. Before deploying the Helm chart, you should have a Falcon Linux Sensor in the container registry before installing the Helm Chart. See the Deployment Considerations for more.
1. Helm 3.x is installed and supported by the Kubernetes vendor.

## Deployment Considerations

To ensure a successful deployment, you will want to ensure that:
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
1. You must have sufficient permissions to deploy Kubernetes Operators to the cluster. This is
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



## Using Helm Operator

## Deploy using the Operator Lifecycle Manager (OLM) deployment

1. Install the Operator SDK CLI tool. See [https://sdk.operatorframework.io/docs/installation/](https://sdk.operatorframework.io/docs/installation/) for installation guide.

2. Run the bundle
   ```
   operator-sdk run bundle quay.io/crowdstrike/falcon-helm-operator-bundle:latest
   ```

3. Customize the Helm operator deployment by adding your Crowdstrike Customer ID (CID), configuring the
   registry containing the Falcon sensor, and any other sensor configurations in
   `config/samples/crowdstrike_v1alpha1_falconsensor.yaml`.

4. Apply the customized Helm operator resource:
   ```
   kubectl apply -f config/samples/crowdstrike_v1alpha1_falconsensor.yaml
   ```

## Uninstall using the Operator Lifecycle Manager (OLM)

1. Uninstall the operator
   ```
   operator-sdk cleanup falcon-helm
   ```

## Deploy using Make from the Git Repository

1. Deploy the Helm operator
   ```
   make deploy IMG=quay.io/crowdstrike/falcon-helm-operator:latest
   ```

2. Customize the Helm operator deployment by adding your Crowdstrike Customer ID (CID), configuring the
   registry containing the Falcon sensor, and any other sensor configurations in
   `config/samples/crowdstrike_v1alpha1_falconsensor.yaml`.

3. Apply the customized Helm operator resource
   ```
   kubectl apply -f config/samples/crowdstrike_v1alpha1_falconsensor.yaml
   ```

### Undeploy using Make from the Git Repository

3. Delete the customized Helm operator resouce
   ```
   kubectl delete falconsensor.falcon.crowdstrike.com/falcon-helm
   ```

1. Uninstall the Helm operator
   ```
   make undeploy
   ```
