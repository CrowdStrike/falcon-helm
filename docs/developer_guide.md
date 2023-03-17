# Developer Guide

## Requirements

The following need to be installed to develop and test the Helm Operator and the Helm Chart.

* [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
* [Helm 3.x](https://helm.sh/docs/intro/install/)
* [The Operator SDK CLI](https://sdk.operatorframework.io/docs/installation/)
* A working Kubernetes cluster
* Your Kubernetes cluster is either an ARM64 or x86_64 cluster 

  > Note: The Falcon Helm chart does not support multi-architecture clusters.
  
* The [Operator Lifecycle Manager (OLM)](https://olm.operatorframework.io/docs/getting-started/) if using OLM in your cluster.
  **Note:** For OpenShift, this should already be installed.

This project heavily uses the Operator SDK toolkit. Therefore, it is important to understand that part of the Operator SDK's job is to help create and manage operator code.
In many cases, some of the code that gets committed is generated code from the Operator SDK. For example, the `bundle/` directory is completely generated through `make bundle`.
While it might be tempting to review generated code, it is not recommended.
 
## Directory Layout

* See [https://sdk.operatorframework.io/docs/overview/project-layout/#common-base](https://sdk.operatorframework.io/docs/overview/project-layout/#common-base) for base layout of the directory.
* See [https://sdk.operatorframework.io/docs/overview/project-layout/#helm](https://sdk.operatorframework.io/docs/overview/project-layout/#helm) for Helm specific files and directories

# Command Cheat Sheet

See [https://sdk.operatorframework.io/docs/overview/cheat-sheet/](https://sdk.operatorframework.io/docs/overview/cheat-sheet/) for commonly used commands with the Operator SDK.

## Helm Operator

## Helm Charts

### Updating the Chart.yaml
The `Chart.yaml` file requires a version bump for any changes that take place in under `helm-charts/falcon-sensor`.
Both `version` and `appVersion` need to be changed.

* The `PATCH` version field should be changed whenever there is documentation or typo changes made.
* The `MINOR` version field should be changed whenever there are values add/changed, minor functionality changes in the templates, etc.
* The `MAJOR` version field should be changed whenever there is a new sensor or product enhancement.

### Creating a Release
To create a new release, use the `Draft a New Release` and set the `Tag` version to the version listed in `Chart.yaml`.
This will run a release workflow which will create a helm archive and update the helm repo to add the latest release.

### Install using Helm from the Git Repository

To install using Helm, run the following command replacing
`<Your_CrowdStrike_CID>` with your CrowdStrike Customer ID:

```
helm install --set falcon.cid=<Your_CrowdStrike_CID> -n falcon-system --create-namespace falcon-helm ./helm-charts/falcon-sensor
```

You can use multiple `--set` arguments for configuring the Falcon Helm Chart
according to your environment. See the [values yaml file for more configuration options](../helm-charts/falcon-sensor/values.yaml).

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

### Uninstall using Make from the Git Repository

```
make helm-uninstall
```
