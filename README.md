# CrowdStrike Falcon Helm Chart and Helm Operator

[Falcon](https://www.crowdstrike.com/) is the [CrowdStrike](https://www.crowdstrike.com/)
platform purpose-built to stop breaches via a unified set of cloud-delivered
technologies that prevent all types of attacks — including malware and much
more.

The CrowdStrike Falcon Helm Chart and the Helm Operator are designed to deploy
and manage the Falcon sensor on your Kubernetes cluster of choice.
[Helm Charts](https://helm.sh/docs/topics/charts/Helm) and Helm-based Kubernetes
Operators are packaging methodologies for Kubernetes. Which methodology you use
is dependent on what the Kubernetes vendor and implementation supports.

# Deployment Considerations

To ensure a successful deployment, you will want to ensure that:
1. You have access to a containerized falcon sensor image. This is most likely
   through a private image registry on your network or cloud provider. See
   https://github.com/CrowdStrike/Dockerfiles as an example of how to build a
   Falcon sensor for your registry.
1. The Falcon Linux Sensor RPM (not the Falcon Container) should be used in the
   container image to deploy to Kubernetes nodes.
1. You must have sufficient permissions to deploy Kubernetes DaemonSets. This is
   often received through cluster admin privileges.
1. Only deploying to Kubernetes nodes are supported at this time.
1. You need to have cluster admin privileges and be able to deploy daemonsets to
   nodes
1. When deploying the Falcon Linux Sensor as a container to Kubernetes nodes, it
   is a requirement that the Falcon Sensor run as a privileged container so that
   the Sensor can properly work with the kernel. If this is unacceptable, you can
   install the Falcon Linux Sensor (still runs with privileges) using an RPM or
   DEB package on the nodes themselves. This assumes that you have the capability
   to actually install RPM or DEB packages on the nodes. If you do not have this
   capability and you want to protect the nodes, you have to install using a
   privileged container.
1. CrowdStrike's Helm Operator is a project, not a product, and released to the
   community as a way to automate sensor deployment to kubernetes clusters. The
   upstream repository for this project is
   https://github.com/CrowdStrike/falcon-helm.
1. The Helm Operator is IN DEVELOPMENT AND NOT PRODUCTION READY, so do not use
   it! Use Helm Charts instead.

# Installation

## Using the Helm Operator

IN DEVELOPMENT! NOT PRODUCTION READY!

## Using Helm Charts

### Using Helm from the Git Repository:

To install using Helm, run the following command replacing
`<Your_CrowdStrike_CID>` with your CrowdStrike Customer ID:

```
helm install --set falcon.cid=<Your_CrowdStrike_CID> falcon-helm ./helm-charts/falcon-sensor
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
   helm install -f `custom_repo.yaml` falcon-helm ./helm-charts/falcon-sensor
   ```

### Using Make from the Git Repository:

To install using a Makefile (assumes Helm is installed on your system), run the
following command replacing `<Your_CrowdStrike_CID>` with your CrowdStrike
Customer ID:

```
make helm-install CID=<Your_CrowdStrike_CID>
```

# Uninstalling

## Using Helm Charts

### Uninstalling with Helm

Assuming the Falcon helm chart is the same and has not been customized, run the
following command:

```
helm uninstall falcon-helm
```

### Uninstalling with Make from the Git Repository:

```
make helm-uninstall
```
