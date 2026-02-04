# CrowdStrike Falcon Platform Helm Chart
The Falcon Platform Helm Chart deploys the complete CrowdStrike Falcon Kubernetes runtime security
platform. This umbrella chart manages all individual Falcon components as dependencies, providing
unified deployment and configuration.

## Overview

The Falcon Platform Helm chart allows you to deploy and manage the entire CrowdStrike Falcon
Kubernetes runtime security stack with a single Helm installation. It coordinates the deployment
of multiple security components while providing centralized configuration management and deployment
orchestration.

### Components
The platform manages three core security components as dependencies, with the Falcon Sensor
supporting one of two deployment modes.

| Component                                                                 | Purpose                                                 | Default Status |
|---------------------------------------------------------------------------|---------------------------------------------------------|----------------|
| [**Falcon Node Sensor**](/helm-charts/falcon-sensor/README.md)            | Daemonset for runtime node protection and monitoring    | Enabled        |
| [**Falcon Container Sensor**](/helm-charts/falcon-sensor/README.md)       | Sidecar for runtime container protection and monitoring | Disabled       |
| [**Falcon KAC**](/helm-charts/falcon-kac/README.md)                       | Kubernetes admission controller for policy enforcement  | Enabled        |
| [**Falcon Image Analyzer**](/helm-charts/falcon-image-analyzer/README.md) | Container image vulnerability scanning and assessment   | Enabled        |

### Falcon Platform Support for Falcon Component Subcharts
The Falcon Platform uses Helm's dependency management system to orchestrate multiple subcharts.
Each component is declared as a dependency in the umbrella chart's [Chart.yaml](./Chart.yaml)
file with specific version constraints. Helm automatically downloads and manages the specified
versions of each component chart during installation.

Below is a table of subchart versions locked to the latest falcon-platform release.

| Helm Chart Name       | Helm Chart Version |
|:----------------------|:-------------------|
| falcon-platform       | `1.2.0`            |
| falcon-sensor         | `1.34.2`           |
| falcon-kac            | `1.6.0`            |
| falcon-image-analyzer | `1.1.18`           |

### Namespace Isolation Strategy
Each Falcon component operates in its own dedicated namespace.

> [!NOTE]
> Either the Falcon Sensor for Linux (Node) or Falcon Sensor for Linux (Container) is deployed, but not both.

| Namespace             | Component                                      |
|-----------------------|------------------------------------------------|
| falcon-system         | Falcon Sensor for Linux (Node)                 |
| falcon-system         | Falcon Sensor for Linux (Container)            |
| falcon-kac            | Falcon Kubernetes Admission Controller (KAC)   |
| falcon-image-analyzer | Falcon Image Assessment at Runtime agent (IAR) |

This isolation provides security boundaries with individual RBAC policies and service accounts,
independent resource quotas and limits per component, and operational isolation where component
failures don't impact other components.

## Prerequisites
### Minimum Requirements
- Helm 3.x
- Falcon Customer ID (CID)
- Appropriate cluster permissions (cluster-admin) for installation
- Falcon registry access to pull Falcon component container images
- Falcon OAuth client credentials
  - Required Permissions:
    - Falcon Container CLI: Write
    - Falcon Container Image: Read/Write
    - Falcon Images Download: Read

## Deploy the Falcon Platform

> [!NOTE]
> - The falcon-platform Helm chart uses the latest version of each Falcon component subchart and does not allow version customization for individual subcharts. For granular version control, use the individual Falcon component Helm charts instead.
> - The falcon-platform Helm chart creates dedicated namespaces for each Falcon component automatically. For optimal security and resource management, we recommend deploying each component in its own dedicated namespace.
> - The falcon-platform Helm chart treats all CrowdStrike components as a single deployment. Running `helm uninstall` will remove all components - follow the [guide here](#uninstall-a-single-component) to uninstall a single component.

### 1. Set your environment variables:
```bash
export FALCON_CID=<your-falcon-cid>
export ENCODED_DOCKER_CONFIG=<your-base64-encoded-docker-config>
export SENSOR_REGISTRY=<your-sensor-registry>
export SENSOR_IMAGE_TAG=<your-falcon-sensor-image-tag>
export KAC_REGISTRY=<your-kac-registry>
export KAC_IMAGE_TAG=<your-falcon-kac-image-tag>
export IAR_REGISTRY=<your-iar-registry>
export IAR_IMAGE_TAG=<your-falcon-iar-image-tag>
export CLUSTER_NAME=<your-cluster-name>
export FALCON_CLIENT_ID=<your-falcon-client-id>
export FALCON_CLIENT_SECRET=<your-falcon-client-secret>
```

### 2. Add the Helm Repository
```bash
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
helm repo update
```

### 3. Deploy the Helm Chart

Deploy all 3 components using `--set` arguments to pass configuration values directly. The
`createComponentNamespaces=true` setting automatically creates the required namespaces for each
component.

```bash
helm install falcon-platform crowdstrike/falcon-platform --version 1.0.0 \
  --namespace falcon-platform \
  --create-namespace \
  --set createComponentNamespaces=true \
  --set global.falcon.cid=$FALCON_CID \
  --set global.containerRegistry.configJSON=$ENCODED_DOCKER_CONFIG \
  --set falcon-sensor.node.image.repository=$SENSOR_REGISTRY \
  --set falcon-sensor.node.image.tag=$SENSOR_IMAGE_TAG \
  --set falcon-kac.image.repository=$KAC_REGISTRY \
  --set falcon-kac.image.tag=$KAC_IMAGE_TAG \
  --set falcon-image-analyzer.deployment.enabled=true \
  --set falcon-image-analyzer.image.repository=$IAR_REGISTRY \
  --set falcon-image-analyzer.image.tag=$IAR_IMAGE_TAG \
  --set falcon-image-analyzer.crowdstrikeConfig.clusterName=$CLUSTER_NAME \
  --set falcon-image-analyzer.crowdstrikeConfig.clientID=$FALCON_CLIENT_ID \
  --set falcon-image-analyzer.crowdstrikeConfig.clientSecret=$FALCON_CLIENT_SECRET
```

## Verify Falcon Platform Deployment

### Check Installation Status

```bash
# Check overall falcon-platform release status
helm list -n falcon-platform

# Expected Output:
NAME           	NAMESPACE      	REVISION	UPDATED                             	STATUS  	CHART                	APP VERSION
falcon-platform	falcon-platform	1       	2025-10-06 16:54:28.315583 -0400 EDT	deployed	falcon-platform-1.0.0

# Check all pods with the falcon-platform label
kubectl get pods -l app.kubernetes.io/instance=falcon-platform -A

# Expected Output:
NAMESPACE               NAME                                          READY   STATUS    RESTARTS   AGE
falcon-image-analyzer   falcon-platform-falcon-image-analyzer-xxxxx   1/1     Running   0          2m
falcon-kac              falcon-kac-xxxxxxxxx-xxxxx                    3/3     Running   0          2m
falcon-system           falcon-platform-falcon-sensor-xxxxx           1/1     Running   0          2m
```

### Verify Individual Component Health

```bash
# Node sensor daemonset
# Falcon Sensor is deployed to falcon-system namespace by default
kubectl get deployments,daemonsets,pods -n falcon-system

# Expected Output:
NAME                                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/falcon-platform-falcon-sensor   1         1         1       1            1           kubernetes.io/os=linux   2m

NAME                                      READY   STATUS    RESTARTS   AGE
pod/falcon-platform-falcon-sensor-xxxxx   1/1     Running   0          2m

# KAC webhook registration
# Falcon KAC is deployed to falcon-kac namespace by default
kubectl get deployments,pods -n falcon-kac

# Expected Output:
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/falcon-kac   1/1     1            1           2m

NAME                              READY   STATUS    RESTARTS   AGE
pod/falcon-kac-xxxxxxxxx-xxxxx   3/3     Running   0          2m

# Image analyzer deployment
# Falcon Image Analyzer is deployed to falcon-image-analyzer namespace by default
kubectl get deployments,daemonsets,pods -n falcon-image-analyzer

# Expected Output:
NAME                                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/falcon-platform-falcon-image-analyzer   1/1     1            1           2m

NAME                                                        READY   STATUS    RESTARTS   AGE
pod/falcon-platform-falcon-image-analyzer-xxxxxxxxx-xxxxx   1/1     Running   0          2m
```

## Configure Falcon Platform

### Configuration Priority
The umbrella chart implements a hierarchical configuration system with three levels:

- Global configuration: Settings that apply to all components
- Component-specific configuration: Settings that apply to the specific component - overrides globals
- Chart defaults: Default values defined in each component's individual chart

### Component-Specific Requirements

**Falcon Sensor:**
- Falcon CID
- CrowdStrike container registry access

**Falcon KAC:**
- Falcon CID
- CrowdStrike container registry access

**Falcon Image Analyzer:**
- Falcon CID
- CrowdStrike container registry access
- Kubernetes cluster name
- Falcon OAuth client credentials (Client ID + Secret)
  - Required Permissions:
    - Falcon Container CLI: Write
    - Falcon Container Image: Read/Write
    - Falcon Images Download: Read

### Falcon Platform Configuration
Falcon Platform specific configurations apply to top level resources managed by Falcon Platform,
rather than the Falcon component subcharts.

| Parameter                               | Default               | Description                                                                                |
|-----------------------------------------|-----------------------|--------------------------------------------------------------------------------------------|
| createComponentNamespaces               | false                 | Create namespaces for each Falcon component. Pre-install only, does not work for upgrades. |
| falcon-sensor.namespaceOverride         | falcon-system         | Name of dedicated namespace for Falcon Linux Node or Container sensor.                     |
| falcon-kac.namespaceOverride            | falcon-kac            | Name of dedicated namespace for Falcon Kubernetes Admission Controller.                    |
| falcon-image-analyzer.namespaceOverride | falcon-image-analyzer | Name of dedicated namespace for Falcon Image Analyzer.                                     |

> [!WARNING]
> `createComponentNamespaces` will fail if the component namespaces already exist.
> Falcon component namespace(s) have to be created manually before upgrades that enable new components.

### Global Configuration
Global settings apply to all components unless component specific values are set as overrides.

| Parameter                           | Default | Description                                                                                        |
|-------------------------------------|---------|----------------------------------------------------------------------------------------------------|
| global.falcon.cid                   | null    | Required for all components unless using an existing secret (`falconSecret`) with CID data         |
| global.falconSecret.enabled         | false   | Enable existing secret injection as an alternative to setting plain text values for sensitive data |
| global.falconSecret.secretName      | ""      | Name of existing Kubernetes secret with sensitive data necessary for Falcon component installation |
| global.containerRegistry.configJSON | ""      | Your container registry config json as a base64 encoded string                                     |
| global.containerRegistry.pullSecret | ""      | Name of existing container registry pull secret as an alternative to `registryConfigJSON`          |

> [!NOTE]
Any existing secrets for `falconSecret` or `containerRegistry.pullSecret` must exist in the namespace dedicated to the respective Falcon component before installing the Helm chart. For example, you must already have an existing secret matching `global.falconSecret.secretName` in the `falcon-sensor` default namespace, or custom namespace you choose for your `falcon-sensor.namespaceOverride`.

### Component-Specific Configuration
Each Falcon component supports the existing configuration options for each subchart. 

#### Falcon Sensor
Falcon Sensor specific configurations must be prefixed with `falcon-sensor`. For comprehensive configuration options please see the linked documentation below.
- [Falcon Sensor - Falcon Configuration Options](/helm-charts/falcon-sensor/README.md#falcon-configuration-options)
- [Falcon Sensor - Daemonset Configuration Options](/helm-charts/falcon-sensor/README.md#node-configuration)
- [Falcon Sensor - Container Configuration Options](/helm-charts/falcon-sensor/README.md#container-sensor-configuration)
- [Falcon Sensor - GKE Autopilot Configuration](/helm-charts/falcon-sensor/README.md#gke-autopilot-configuration)

**Required Daemonset Values:**

| Parameter                              | Description                          |
|:---------------------------------------|:-------------------------------------|
| `falcon-sensor.node.image.repository`  | Falcon Sensor container registry URL |
| `falcon-sensor.node.image.tag`         | Falcon Sensor container image tag    |

**Optional Daemonset Values:**

| Parameter                                     | Description                                                           |
|:----------------------------------------------|:----------------------------------------------------------------------|
| `falcon-sensor.enabled`                       | Default: true                                                         |
| `falcon-sensor.falcon.trace`                  | Set trace level (`none`,`err`,`warn`,`info`,`debug`); Default: `none` |
| `falcon-sensor.node.image.digest`             | Falcon Node Sensor container image digest (alternative to `tag`)      |
| `falcon-sensor.node.image.pullSecrets`        | Overrides global.containerRegistry.pullSecret                         |
| `falcon-sensor.node.image.registryConfigJSON` | Overrides global.containerRegistry.configJSON                         |

**Required Container Values:**

| Parameter                                              | Description                                                                 |
|:-------------------------------------------------------|:----------------------------------------------------------------------------|
| `falcon-sensor.node.enabled`                           | Disable daemonset installation (must be `false`)                            |
| `falcon-sensor.container.enabled`                      | Enable sensor installation as a sidecar container (must be `true`)          |
| `falcon-sensor.container.image.repository`             | Falcon Container Sensor container registry URL                              |
| `falcon-sensor.container.image.tag`                    | Falcon Container Sensor container image tag                                 |
| `falcon-sensor.container.image.pullSecrets.enable`     | Required if connecting to a container registry that requires authentication |
| `falcon-sensor.container.image.pullSecrets.namespaces` | List of allowed namespaces to use given pull secrets                        |

**Optional Container Values:**

| Parameter                                                      | Description                                                              |
|:---------------------------------------------------------------|:-------------------------------------------------------------------------|
| `falcon-sensor.enabled`                                        | Default: true                                                            |
| `falcon-sensor.falcon.trace`                                   | Set trace level (`none`,`err`,`warn`,`info`,`debug`); Default: `none`    |
| `falcon-sensor.container.image.digest`                         | Falcon Container Sensor container image digest (alternative to `tag`)    |
| `falcon-sensor.container.image.pullSecrets.allNamespaces`      | Allow all namespaces to use given pull secrets - Not supported on ArgoCD |
| `falcon-sensor.container.image.pullSecrets.name`               | Overrides global.containerRegistry.pullSecret                            |
| `falcon-sensor.container.image.pullSecrets.registryConfigJSON` | Overrides global.containerRegistry.configJSON                            |


**Shared Global Overrides:**
The following falcon-sensor parameters apply to both Node and Container sensors

| Parameter                               | Description                              |
|:----------------------------------------|:-----------------------------------------|
| `falcon-sensor.falcon.cid`              | Overrides global.falcon.cid              |
| `falcon-sensor.falconSecret.enabled`    | Overrides global.falconSecret.enabled    |
| `falcon-sensor.falconSecret.secretName` | Overrides global.falconSecret.secretName |

#### Falcon KAC
Falcon KAC specific configurations must be prefixed with `falcon-kac`. For comprehensive configuration options please see the linked documentation below.
- [Falcon KAC - Falcon Configuration Options](/helm-charts/falcon-kac/README.md#falcon-configuration-options)

**Required Values:**

| Parameter                      | Description                       |
|:-------------------------------|:----------------------------------|
| `falcon-kac.image.repository`  | Falcon KAC container registry URL |
| `falcon-kac.image.tag`         | Falcon KAC container image tag    |

**Optional Values:**

| Parameter                             | Description                                                           |
|:--------------------------------------|:----------------------------------------------------------------------|
| `falcon-kac.enabled`                  | Default: true                                                         |
| `falcon-kac.falcon.trace`             | Set trace level (`none`,`err`,`warn`,`info`,`debug`); Default: `none` |
| `falcon-kac.image.digest`             | Falcon KAC container image digest (alternative to `tag`)              |
| `falcon-kac.image.pullSecrets`        | Overrides global.containerRegistry.pullSecret                         |
| `falcon-kac.image.registryConfigJSON` | Overrides global.containerRegistry.configJSON                         |
| `falcon-kac.falcon.cid`               | Overrides global.falcon.cid                                           |
| `falcon-kac.falconSecret.enabled`     | Overrides global.falconSecret.enabled                                 |
| `falcon-kac.falconSecret.secretName`  | Overrides global.falconSecret.secretName                              |

#### Falcon Image Analyzer
Falcon Image Analyzer specific configurations must be prefixed with `falcon-image-analyzer`. For comprehensive configuration options please see the linked documentation below.
- [Falcon Image Analyzer - Configuration Options](/helm-charts/falcon-image-analyzer/README.md#falcon-configuration-options)

**Required Values:**

| Parameter                                              | Description                                        |
|:-------------------------------------------------------|:---------------------------------------------------|
| `falcon-image-analyzer.deployment.enabled`             | Enable for watcher mode (cannot enable both modes) |
| `falcon-image-analyzer.daemonset.enabled`              | Enable for socket mode (cannot enable both modes)  |
| `falcon-image-analyzer.image.repository`               | Falcon Image Analyzer container registry URL       |
| `falcon-image-analyzer.image.tag`                      | Falcon Image Analyzer container image tag          |
| `falcon-image-analyzer.crowdstrikeConfig.clusterName`  | Kubernetes cluster name                            |
| `falcon-image-analyzer.crowdstrikeConfig.agentRuntime` | Required if daemonset enabled                      |
| `falcon-image-analyzer.crowdstrikeConfig.clientId`     | CrowdStrike Falcon OAuth client ID                 |
| `falcon-image-analyzer.crowdstrikeConfig.clientSecret` | CrowdStrike Falcon OAuth client secret             |

**Optional Values:**

| Parameter                                                | Description                                                         |
|:---------------------------------------------------------|:--------------------------------------------------------------------|
| `falcon-image-analyzer.enabled`                          | Default: true                                                       |
| `falcon-image-analyzer.enableDebug`                      | Set to `true` for debug level log verbosity                         |
| `falcon-image-analyzer.image.digest`                     | Falcon Image Analyzer container image digest (alternative to `tag`) |
| `falcon-image-analyzer.image.pullSecret`                 | Overrides global.containerRegistry.pullSecret                       |
| `falcon-image-analyzer.image.registryConfigJSON`         | Overrides global.containerRegistry.configJSON                       |
| `falcon-image-analyzer.crowdstrikeConfig.cid`            | Overrides global.falcon.cid                                         |
| `falcon-image-analyzer.crowdstrikeConfig.existingSecret` | Overrides global.falconSecret.secretName                            |


### Using Existing Kubernetes Secrets

Instead of specifying sensitive values directly in Helm values, you can use existing Kubernetes secrets for the following env vars:
- `FALCONCTL_OPT_CID`: Falcon CID - Required for falcon-sensor and falcon-kac
- `FALCONCTL_OPT_PROVISIONING_TOKEN`: Falcon provisioning token - Optional for falcon-sensor and falcon-kac
- `AGENT_CLIENT_ID`: Falcon OAuth client ID - Required for falcon-image-analyzer
- `AGENT_CLIENT_SECRET`: Falcon OAuth client secret - Required for falcon-image-analyzer

When using `falconSecret`, create the secret in each respective namespace beforehand:

```bash
# Set additional environment variables
export FALCON_SECRET_NAME=<your-falcon-secret-name>
export FALCON_PROVISIONING_TOKEN=<your-falcon-provisioning-token>

# First create each component namespace
kubectl create namespace falcon-system
kubectl create namespace falcon-kac
kubectl create namespace falcon-image-analyzer

# Create secret with required values for falcon-sensor
kubectl create secret generic $FALCON_SECRET_NAME -n falcon-system \
  --from-literal=FALCONCTL_OPT_CID=$FALCON_CID \
  --from-literal=FALCONCTL_OPT_PROVISIONING_TOKEN=$FALCON_PROVISIONING_TOKEN
  
# Create secret with required values for falcon-kac
kubectl create secret generic $FALCON_SECRET_NAME -n falcon-kac \
  --from-literal=FALCONCTL_OPT_CID=$FALCON_CID
  
# Create secret with required values for falcon-image-analyzer
kubectl create secret generic $FALCON_SECRET_NAME -n falcon-image-analyzer \
  --from-literal=AGENT_CLIENT_ID=$FALCON_CLIENT_ID \
  --from-literal=AGENT_CLIENT_SECRET=$FALCON_CLIENT_SECRET
```

Once you have created your Kubernetes secrets, you can install the falcon-platform Helm chart with the following global options: 

```bash
helm install falcon-platform crowdstrike/falcon-platform --version 1.0.0 -n falcon-platform \
  --create-namespace \
  --set global.falconSecret.enabled=true \
  --set global.falconSecret.secretName=$FALCON_SECRET_NAME \
  --set global.containerRegistry.configJSON=$ENCODED_DOCKER_CONFIG \
  --set falcon-sensor.node.image.repository=$SENSOR_REGISTRY \
  --set falcon-sensor.node.image.tag=$SENSOR_IMAGE_TAG \
  --set falcon-kac.image.repository=$KAC_REGISTRY \
  --set falcon-kac.image.tag=$KAC_IMAGE_TAG \
  --set falcon-image-analyzer.daemonset.enabled=true \
  --set falcon-image-analyzer.image.repository=$IAR_REGISTRY \
  --set falcon-image-analyzer.image.tag=$IAR_IMAGE_TAG \
  --set falcon-image-analyzer.crowdstrikeConfig.agentRuntime=$IAR_AGENT_RUNTIME \
  --set falcon-image-analyzer.crowdstrikeConfig.clusterName=$CLUSTER_NAME \
  --set falcon-image-analyzer.crowdstrikeConfig.cid=$FALCON_CID                   # IAR Falcon CID is not yet supported by existing secrets
```

## Upgrade Strategy

### Install/Reinstall a Single Component
When installing a new component for the first time, make sure the component namespace exists.
`createComponentNamespaces` does not support namespace creation for Helm upgrades.

```bash
# Create component namespace if it does not already exist
kubectl create namespace falcon-kac

# Upgrade Helm chart with new component enabled and required values - for example to install falcon-kac after initial Helm install
helm upgrade --install falcon-platform crowdstrike/falcon-platform --version 1.0.0 -n falcon-platform \
  --reuse-values \
  --set falcon-kac.enabled=true \
  --set falcon-kac.image.repository=$KAC_REGISTRY \
  --set falcon-kac.image.tag=$KAC_IMAGE_TAG
```

### Upgrade the Falcon Platform Helm Chart Version
```bash
# Update Helm repository
helm repo update

# Upgrade Helm chart with existing Helm values
helm upgrade falcon-platform crowdstrike/falcon-platform --version 1.0.1 -n falcon-platform \
  --reuse-values
```

### Individual Component Updates

> [!NOTE]
> DaemonSet deployments of sensor versions 7.33 and earlier of the Falcon sensor for Linux are blocked from updates and
> uninstallation if their sensor update policy has the **Uninstall and maintenance protection** setting enabled. Before
> upgrading or uninstalling these versions of the sensor, move the sensors to a new sensor update policy with this
> policy setting turned off. For more info, see [Sensor update and uninstallation for DaemonSet sensor versions 7.33
> and lower](https://falcon.crowdstrike.com/documentation/anchor/sc632f2e).

```bash
# Upgrade the version of each Falcon component image
helm upgrade falcon-platform crowdstrike/falcon-platform --version 1.0.0 -n falcon-platform \
  --reuse-values \
  --set falcon-sensor.node.image.tag=$SENSOR_IMAGE_TAG \
  --set falcon-kac.image.tag=$KAC_IMAGE_TAG \
  --set falcon-image-analyzer.image.tag=$IAR_IMAGE_TAG
```

> [!IMPORTANT]
> You cannot customize which helm chart version is being used for each individual Falcon component
> subchart. Component versions are managed through the falcon-platform chart's [dependencies](./Chart.yaml).
> The dependent subchart versions are locked. Update the umbrella chart to get the latest Falcon component
> helm chart versions for each subchart.

## Uninstall

### Uninstall a Single Component

> [!NOTE]
> DaemonSet deployments of sensor versions 7.33 and earlier of the Falcon sensor for Linux are blocked from updates and
> uninstallation if their sensor update policy has the **Uninstall and maintenance protection** setting enabled. Before
> upgrading or uninstalling these versions of the sensor, move the sensors to a new sensor update policy with this
> policy setting turned off. For more info, see [Sensor update and uninstallation for DaemonSet sensor versions 7.33
> and lower](https://falcon.crowdstrike.com/documentation/anchor/sc632f2e).

```bash
# Upgrade your helm release with the component disabled - for example to uninstall falcon-image-analyzer only:
helm upgrade falcon-platform crowdstrike/falcon-platform --version 1.0.0 -n falcon-platform \
  --reuse-values \
  --set falcon-image-analyzer.enabled=false

# Optionally delete the component namespace
kubectl delete namespace falcon-image-analyzer
```

### Uninstall the Falcon Platform Helm Chart
```bash
# Remove Falcon Platform and all components
helm uninstall falcon-platform -n falcon-platform

# Optionally delete the release namespace, and the namespace for each Falcon component subchart
kubectl delete namespace falcon-platform falcon-system falcon-kac falcon-image-analyzer
```

## Migrating from Individual Component Helm Charts
> [!WARNING]
> If you are already using the individual Falcon component Helm charts,
> we recommend to continue doing so. We do not have any plans to stop supporting the
> component Helm charts. We will continue supporting each Falcon component chart
> to make updates to the unified falcon-platform Helm chart. Migrating to the unified
> falcon-platform Helm chart requires completely uninstalling and reinstalling your
> Falcon components, which is not recommended.

## Troubleshooting

### Partial Falcon Platform Installation - Release Failure
In some cases you might be missing some permissions or your cluster might not be set up the way you expected. This can lead to a scenario where the Helm release was created, but the release `failed` and it only installed some of the Falcon components.

Once you have diagnosed the root cause of the failure and addressed the issue, you can either:
1. Do a complete uninstall, then reinstall.
2. Or run a `helm upgrade --install` with the necessary Helm values to [install the remaining Falcon components](#installreinstall-a-single-component).

### Falcon Sensor Troubleshooting Guides
- [Falcon Sensor - Node Deployment Considerations](/helm-charts/falcon-sensor/README.md#deployment-considerations)
- [Falcon Sensor - Container Deployment Considerations](/helm-charts/falcon-sensor/README.md#deployment-considerations-1)
- [Falcon Sensor - Pod Security Standards](/helm-charts/falcon-sensor/README.md#pod-security-standards)
- [Falcon Sensor - More Troubleshooting](/helm-charts/falcon-sensor/README.md#troubleshooting)

### Falcon Image Analyzer Troubleshooting Guides
- [Falcon Image Analyzer - Deployment Considerations](/helm-charts/falcon-image-analyzer/README.md#deployment-considerations)
- [Falcon Image Analyzer - Allow traffic to CrowdStrike servers](/helm-charts/falcon-image-analyzer/README.md#allow-traffic-to-crowdstrike-servers)
- [Falcon Image Analyzer - Pod Security Standards](/helm-charts/falcon-image-analyzer/README.md#pod-security-standards)
- [Falcon Image Analyzer - Pod Eviction](/helm-charts/falcon-image-analyzer/README.md#pod-eviction)
- [Falcon Image Analyzer - Exclusions](/helm-charts/falcon-image-analyzer/README.md#exclusions)

### Component Logs
For debugging purposes make sure to enable debug level logging for the relevant Falcon components.

#### Sensor Logs
```bash
# Enable debug level logs for falcon-sensor
helm upgrade falcon-platform crowdstrike/falcon-platform --version 1.0.0 -n falcon-platform \
  --reuse-values \
  --set falcon-sensor.falcon.trace=debug

# Get all falcon-sensor logs
kubectl logs -n falcon-system -l app.kubernetes.io/instance=falcon-platform
```

#### KAC Logs
```bash
# Enable debug level logs for falcon-kac
helm upgrade falcon-platform crowdstrike/falcon-platform --version 1.0.0 -n falcon-platform \
  --reuse-values \
  --set falcon-kac.falcon.trace=debug

# Get all falcon-kac logs
kubectl logs -n falcon-kac -l app.kubernetes.io/instance=falcon-platform
```

### Image Analyzer Logs

```bash
# Enable debug level logs for falcon-image-analyzer
helm upgrade falcon-platform crowdstrike/falcon-platform --version 1.0.0 -n falcon-platform \
  --reuse-values \
  --set falcon-image-analyzer.crowdstrikeConfig.enableDebug=true

# Get all falcon-image-analyzer logs
kubectl logs -n falcon-image-analyzer -l app.kubernetes.io/instance=falcon-platform
```
