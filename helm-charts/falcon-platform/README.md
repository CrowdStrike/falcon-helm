# CrowdStrike Falcon Platform Helm Chart

> [!IMPORTANT]
> **Announcement:** In January 2027, the Falcon sensor for Linux (DaemonSet), Kubernetes Admission Controller (KAC), and Image Assessment at Runtime (IAR) will be consolidated into Falcon Cluster Guard. Read the [Falcon Cluster Guard Announcement](https://github.com/CrowdStrike/falcon-helm/blob/main/FALCON_CLUSTER_GUARD.md) to prepare your environment.

The Falcon Platform Helm Chart deploys the complete CrowdStrike Falcon Kubernetes runtime security
platform. This umbrella chart manages the individual Falcon component charts as dependencies, providing
unified deployment and configuration.

## Table of Contents
- [Overview](#overview)
  - [Components](#components)
  - [Falcon Platform Support for Falcon Component Subcharts](#falcon-platform-support-for-falcon-component-subcharts)
  - [Namespace Strategy](#namespace-strategy)
  - [Sensor Uninstall and Maintenance Protection](#sensor-uninstall-and-maintenance-protection)
- [Prerequisites](#prerequisites)
  - [Minimum Requirements](#minimum-requirements)
- [Deploy the Falcon Platform](#deploy-the-falcon-platform)
  - [Deploy the Falcon Container Sensor](#deploy-the-falcon-container-sensor)
- [Verify Falcon Platform Deployment](#verify-falcon-platform-deployment)
  - [Check Installation Status](#check-installation-status)
  - [Verify Individual Component Health](#verify-individual-component-health)
- [Configure Falcon Platform](#configure-falcon-platform)
  - [Configuration Priority](#configuration-priority)
  - [Component-Specific Requirements](#component-specific-requirements)
  - [Falcon Platform Configuration](#falcon-platform-configuration)
  - [Global Configuration](#global-configuration)
  - [Component-Specific Configuration](#component-specific-configuration)
  - [Using Existing Kubernetes Secrets](#using-existing-kubernetes-secrets)
  - [Secrets Store CSI Driver Integration](#secrets-store-csi-driver-integration)
- [Upgrade Strategy](#upgrade-strategy)
  - [Install/Reinstall a Single Component](#installreinstall-a-single-component)
  - [Upgrade the Falcon Platform Helm Chart Version](#upgrade-the-falcon-platform-helm-chart-version)
  - [Individual Component Updates](#individual-component-updates)
- [Uninstall](#uninstall)
  - [Uninstall a Single Component](#uninstall-a-single-component)
  - [Uninstall the Falcon Platform Helm Chart](#uninstall-the-falcon-platform-helm-chart)
- [Migrating from Individual Component Helm Charts](#migrating-from-individual-component-helm-charts)
- [Migrating to Falcon Cluster Guard (FCG)](#migrating-to-falcon-cluster-guard-fcg)
  - [What Changed](#what-changed)
  - [Step 1 — Run the migration script](#step-1--run-the-migration-script)
  - [Step 2 — Check for deprecated keys](#step-2--check-for-deprecated-keys)
  - [Step 3 — Confirm the image analyzer settings](#step-3--confirm-the-image-analyzer-settings)
  - [Step 4 — Apply the upgrade](#step-4--apply-the-upgrade)
  - [Step 5 — Clean up deprecated namespaces](#step-5--clean-up-deprecated-namespaces)
  - [Example: before and after values](#example-before-and-after-values)
  - [Container sensor + FCG together](#container-sensor--fcg-together)
- [Troubleshooting](#troubleshooting)
  - [Partial Falcon Platform Installation - Release Failure](#partial-falcon-platform-installation---release-failure)
  - [Upgrade Errors After Migrating to FCG](#upgrade-errors-after-migrating-to-fcg)
  - [Falcon Cluster Guard Troubleshooting Guides](#falcon-cluster-guard-troubleshooting-guides)
  - [Falcon Container Sensor Troubleshooting Guides](#falcon-container-sensor-troubleshooting-guides)
  - [Component Logs](#component-logs)

## Overview

The Falcon Platform Helm chart allows you to deploy and manage the entire CrowdStrike Falcon
Kubernetes runtime security stack with a single Helm installation. It coordinates the deployment
of multiple security components while providing centralized configuration management and deployment
orchestration.

### Components
The platform manages two component charts as dependencies.

| Component                                                                    | Chart                 | Purpose                                                                                                  | Default Status |
|------------------------------------------------------------------------------|-----------------------|----------------------------------------------------------------------------------------------------------|----------------|
| [**Falcon Cluster Guard (FCG)**](/helm-charts/falcon-clusterguard/README.md) | `falcon-clusterguard` | Node sensor DaemonSet, clusterguard controller (cluster visibility and admission control), and optional image analyzer | Enabled        |
| [**Falcon Container Sensor**](/helm-charts/falcon-sensor/README.md)          | `falcon-sensor`       | Sidecar for runtime container protection and monitoring                                                  | Disabled       |

Falcon Cluster Guard runs these workloads from a single container image:

| FCG workload            | Purpose                                                                | Default Status | Values prefix                                  |
|-------------------------|------------------------------------------------------------------------|----------------|------------------------------------------------|
| Node sensor             | DaemonSet for runtime node protection and monitoring                   | Enabled        | `falcon-clusterguard.nodeSensor.*`             |
| Clusterguard controller | Kubernetes metadata service and cluster visibility for node sensors    | Enabled        | `falcon-clusterguard.clusterguardController.*` |
| Admission control       | Validating admission webhook for policy enforcement                    | Disabled       | `falcon-clusterguard.clusterguardController.admissionControl.*` |
| Image analyzer (IAR)    | Container image vulnerability scanning and assessment                  | Disabled       | `falcon-clusterguard.imageAnalyzer.*`          |

> [!NOTE]
> The `falcon-sensor` chart only deploys the Falcon Container sensor (`container.enabled=true`).
> Node mode (`falcon-sensor.node.enabled=true`) is no longer supported; the FCG node sensor replaces it.

### Falcon Platform Support for Falcon Component Subcharts
The Falcon Platform uses Helm's dependency management system to orchestrate multiple subcharts.
Each component is declared as a dependency in the umbrella chart's [Chart.yaml](./Chart.yaml)
file with specific version constraints. Helm automatically downloads and manages the specified
versions of each component chart during installation.

The table below shows the subchart versions bundled with each falcon-platform release.

| falcon-platform    | falcon-clusterguard | falcon-sensor      |
|:-------------------|:--------------------|:-------------------|
| `2.0.0-fcg-beta.0` | `0.1.0-beta.0`      | `2.0.0-fcg-beta.0` |

<details>
<summary><b>falcon-platform 2.0.0-fcg-beta.0</b></summary>

| Component                 | Helm Version       | Sensor Version | Notes                                                                                     |
|:--------------------------|:-------------------|:---------------|:------------------------------------------------------------------------------------------|
| falcon-clusterguard       | `0.1.0-beta.0`     | `>= 8.14`      | Initial beta release of Falcon Cluster Guard. Replaces the node sensor, KAC, and IAR.     |
| falcon-sensor (container) | `2.0.0-fcg-beta.0` | `>= 7.37`      | Node mode is no longer supported. Use `falcon-clusterguard` for node protection.         |

</details>

For falcon-platform `1.x` releases, see the
[falcon-platform 1.5.1 README](https://github.com/CrowdStrike/falcon-helm/blob/falcon-platform-1.5.1/helm-charts/falcon-platform/README.md).

### Namespace Strategy
Both components are deployed to the `falcon-system` namespace by default. Each component uses its own
service accounts and RBAC policies.

| Namespace     | Component                                                                       |
|---------------|---------------------------------------------------------------------------------|
| falcon-system | Falcon Cluster Guard (node sensor, clusterguard controller, image analyzer)     |
| falcon-system | Falcon Sensor for Linux (Container) injector                                    |

To deploy a component to a different namespace, set `falcon-clusterguard.namespaceOverride` or
`falcon-sensor.namespaceOverride`.

### Sensor Uninstall and Maintenance Protection
Important notes for Kubernetes and other container deployments of the Falcon sensor.
- **Falcon Container sensor for Linux:** Deployed as a sidecar container within application pods. This sensor does not support the **Uninstall and maintenance protection** policy setting and automatically ignores it.

## Prerequisites
### Minimum Requirements
- Helm 3.x
- Falcon Customer ID (CID)
- Appropriate cluster permissions (cluster-admin) for installation
- Falcon registry access to pull Falcon component container images
- Falcon OAuth client credentials, only if you enable the FCG image analyzer
  - Required Permissions:
    - Falcon Container CLI: Write
    - Falcon Container Image: Read/Write
    - Falcon Images Download: Read
    - Sensor Download: Read

## Deploy the Falcon Platform

> [!NOTE]
> - The falcon-platform Helm chart uses the latest version of each Falcon component subchart and does not allow version customization for individual subcharts. For granular version control, use the individual Falcon component Helm charts instead.
> - The falcon-platform Helm chart can create the component namespaces for you with `createComponentNamespaces=true`.
> - The falcon-platform Helm chart treats all CrowdStrike components as a single deployment. Running `helm uninstall` will remove all components - follow the [guide here](#uninstall-a-single-component) to uninstall a single component.
> - The FCG node sensor requires the `privileged` Pod Security Standards level on its namespace. See [Pod Security Standards](/helm-charts/falcon-clusterguard/README.md#pod-security-standards).

### 1. Set your environment variables:
```bash
export FALCON_CID=<your-falcon-cid>
export ENCODED_DOCKER_CONFIG=<your-base64-encoded-docker-config>
export PLATFORM_CHART_VERSION=<falcon-platform-chart-version>
export FCG_REGISTRY=<your-falcon-clusterguard-registry>
export FCG_IMAGE_TAG=<your-falcon-clusterguard-image-tag>
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

Deploy Falcon Cluster Guard with the node sensor, clusterguard controller, admission control, and
image analyzer using `--set` arguments to pass configuration values directly. The
`createComponentNamespaces=true` setting automatically creates the `falcon-system` namespace.

```bash
helm install falcon-platform crowdstrike/falcon-platform --version $PLATFORM_CHART_VERSION \
  --namespace falcon-platform \
  --create-namespace \
  --set createComponentNamespaces=true \
  --set global.falcon.cid=$FALCON_CID \
  --set global.containerRegistry.configJSON=$ENCODED_DOCKER_CONFIG \
  --set falcon-clusterguard.image.repository=$FCG_REGISTRY \
  --set falcon-clusterguard.image.tag=$FCG_IMAGE_TAG \
  --set falcon-clusterguard.clusterName=$CLUSTER_NAME \
  --set falcon-clusterguard.clusterguardController.admissionControl.enabled=true \
  --set falcon-clusterguard.imageAnalyzer.enabled=true \
  --set falcon-clusterguard.imageAnalyzer.crowdstrikeConfig.clientID=$FALCON_CLIENT_ID \
  --set falcon-clusterguard.imageAnalyzer.crowdstrikeConfig.clientSecret=$FALCON_CLIENT_SECRET
```

`clusterName` is usually discovered automatically on EKS, GKE, and AKS. Set it for self-hosted clusters.
Omit the `imageAnalyzer` values to deploy without the image analyzer.

### Deploy the Falcon Container Sensor

The Falcon Container sensor is injected as a sidecar into application pods. Use it in managed
environments that don't allow node access or privileged DaemonSets. Enable it with
`falcon-sensor.enabled=true` and `falcon-sensor.container.enabled=true`. Leave
`falcon-sensor.node.enabled` set to `false`.

```bash
export SENSOR_REGISTRY=<your-falcon-container-sensor-registry>
export SENSOR_IMAGE_TAG=<your-falcon-container-sensor-image-tag>

helm install falcon-platform crowdstrike/falcon-platform --version $PLATFORM_CHART_VERSION \
  --namespace falcon-platform \
  --create-namespace \
  --set createComponentNamespaces=true \
  --set global.falcon.cid=$FALCON_CID \
  --set global.containerRegistry.configJSON=$ENCODED_DOCKER_CONFIG \
  --set falcon-clusterguard.image.repository=$FCG_REGISTRY \
  --set falcon-clusterguard.image.tag=$FCG_IMAGE_TAG \
  --set falcon-clusterguard.nodeSensor.enabled=false \
  --set falcon-sensor.enabled=true \
  --set falcon-sensor.container.enabled=true \
  --set falcon-sensor.container.image.repository=$SENSOR_REGISTRY \
  --set falcon-sensor.container.image.tag=$SENSOR_IMAGE_TAG \
  --set falcon-sensor.container.image.pullSecrets.enable=true \
  --set falcon-sensor.container.image.pullSecrets.allNamespaces=true
```

This example keeps the FCG clusterguard controller for cluster visibility and turns off the FCG
node sensor (`falcon-clusterguard.nodeSensor.enabled=false`). To deploy only the container sensor,
set `falcon-clusterguard.enabled=false` instead. The container sensor is injected into pods created
after installation, so restart your application deployments to add the sidecar.

## Verify Falcon Platform Deployment

### Check Installation Status

```bash
# Check overall falcon-platform release status
helm list -n falcon-platform

# Expected Output:
NAME           	NAMESPACE      	REVISION	UPDATED                             	STATUS  	CHART                	APP VERSION
falcon-platform	falcon-platform	1       	2026-11-16 16:54:28.315583 -0500 EST	deployed	falcon-platform-<chart-version>

# Check all pods with the falcon-platform label
kubectl get pods -l app.kubernetes.io/instance=falcon-platform -A

# Expected Output:
NAMESPACE       NAME                                              READY   STATUS    RESTARTS   AGE
falcon-system   falcon-clusterguard-controller-xxxxxxxxx-xxxxx    3/3     Running   0          2m
falcon-system   falcon-clusterguard-iar-xxxxxxxxx-xxxxx           1/1     Running   0          2m
falcon-system   falcon-sensor-xxxxx                               1/1     Running   0          2m
```

### Verify Individual Component Health

```bash
# Falcon Cluster Guard is deployed to the falcon-system namespace by default
kubectl get deployments,daemonsets,pods -n falcon-system

# Expected Output:
NAME                                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/falcon-clusterguard-controller   1/1     1            1           2m
deployment.apps/falcon-clusterguard-iar          1/1     1            1           2m

NAME                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/falcon-sensor   1         1         1       1            1           kubernetes.io/os=linux   2m

NAME                                                  READY   STATUS    RESTARTS   AGE
pod/falcon-clusterguard-controller-xxxxxxxxx-xxxxx    3/3     Running   0          2m
pod/falcon-clusterguard-iar-xxxxxxxxx-xxxxx           1/1     Running   0          2m
pod/falcon-sensor-xxxxx                               1/1     Running   0          2m

# Admission control webhook registration (when admissionControl.enabled=true)
kubectl get validatingwebhookconfiguration validating.falcon-kac.crowdstrike.com
```

When the Falcon Container sensor is enabled, its injector Deployment and webhook are also deployed:

```bash
kubectl get deployment falcon-sensor-injector -n falcon-system
kubectl get mutatingwebhookconfiguration falcon-sensor-injector
```

## Configure Falcon Platform

### Configuration Priority
The umbrella chart implements a hierarchical configuration system with three levels:

- Global configuration: Settings that apply to all components
- Component-specific configuration: Settings that apply to the specific component - overrides globals
- Chart defaults: Default values defined in each component's individual chart

### Component-Specific Requirements

**Falcon Cluster Guard:**
- Falcon CID
- CrowdStrike container registry access
- Kubernetes cluster name, if it can't be discovered automatically (for example, self-hosted clusters)
- Image analyzer only: Falcon OAuth client credentials (Client ID + Secret)
  - Required Permissions:
    - Falcon Container CLI: Write
    - Falcon Container Image: Read/Write
    - Falcon Images Download: Read

**Falcon Container Sensor:**
- Falcon CID
- CrowdStrike container registry access

### Falcon Platform Configuration
Falcon Platform specific configurations apply to top level resources managed by Falcon Platform,
rather than the Falcon component subcharts.

| Parameter                             | Default       | Description                                                                                |
|---------------------------------------|---------------|--------------------------------------------------------------------------------------------|
| createComponentNamespaces             | false         | Create namespaces for each Falcon component. Pre-install only, does not work for upgrades. |
| falcon-clusterguard.namespaceOverride | falcon-system | Name of dedicated namespace for Falcon Cluster Guard.                                      |
| falcon-sensor.namespaceOverride       | falcon-system | Name of dedicated namespace for the Falcon Container sensor injector.                      |

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
| global.containerRegistry.pullSecret | ""      | Name of existing container registry pull secret as an alternative to `configJSON`                  |
| global.openshift.enabled            | false   | Enable OpenShift compatibility mode for all Falcon components                                      |
| global.openshift.createSCC          | true    | Create SecurityContextConstraints resources. Set to `false` to manage SCCs outside of Helm         |
| global.secretsStore.enabled         | false   | Enable Secrets Store CSI Driver as the secret source for all components. See [Secrets Store CSI Driver Integration](#secrets-store-csi-driver-integration). |
| global.secretsStore.provider        | ""      | Secrets Store CSI Driver provider (`azure`)                                                        |
| global.secretsStore.azure.vaultName | ""      | Azure Key Vault name shared across all components                                                  |
| global.secretsStore.azure.tenantID  | ""      | Azure Tenant ID shared across all components                                                       |
| global.secretsStore.azure.clientID  | ""      | Azure Workload Identity client ID (optional; required only when multiple managed identities are assigned) |
| global.secretsStore.secretName      | ""      | Name of the Kubernetes secret created by the CSI driver (overridable per component)               |

> [!NOTE]
> Any existing secrets for `falconSecret` or `containerRegistry.pullSecret` must exist in the namespace of the respective Falcon component before installing the Helm chart. For example, you must already have an existing secret matching `global.falconSecret.secretName` in the `falcon-system` namespace, or the custom namespace you choose for `falcon-clusterguard.namespaceOverride` or `falcon-sensor.namespaceOverride`.

### Component-Specific Configuration
Each Falcon component supports the existing configuration options for each subchart.

#### Falcon Cluster Guard
Falcon Cluster Guard specific configurations must be prefixed with `falcon-clusterguard`. For comprehensive configuration options please see the linked documentation below.
- [Falcon Cluster Guard - Image Configuration](/helm-charts/falcon-clusterguard/README.md#image-configuration)
- [Falcon Cluster Guard - Falcon Configuration Options](/helm-charts/falcon-clusterguard/README.md#falcon-configuration-options)
- [Falcon Cluster Guard - Node Sensor Configuration](/helm-charts/falcon-clusterguard/README.md#node-sensor-configuration)
- [Falcon Cluster Guard - Cluster Guard Controller Configuration](/helm-charts/falcon-clusterguard/README.md#cluster-guard-controller-configuration)
- [Falcon Cluster Guard - Image Analyzer Configuration](/helm-charts/falcon-clusterguard/README.md#image-analyzer-configuration)
- [Falcon Cluster Guard - GKE Autopilot Configuration](/helm-charts/falcon-clusterguard/README.md#gke-autopilot-configuration)

**Common Values:**

| Parameter                                                              | Description                                                                                       |
|:-----------------------------------------------------------------------|:--------------------------------------------------------------------------------------------------|
| `falcon-clusterguard.enabled`                                          | Default: true                                                                                     |
| `falcon-clusterguard.image.repository`                                 | FCG container registry URL. Default: `registry.crowdstrike.com/falcon-clusterguard/release/falcon-clusterguard` |
| `falcon-clusterguard.image.tag`                                        | FCG container image tag                                                                           |
| `falcon-clusterguard.image.digest`                                     | FCG container image digest (alternative to `tag`)                                                 |
| `falcon-clusterguard.image.pullSecret`                                 | Overrides global.containerRegistry.pullSecret                                                     |
| `falcon-clusterguard.image.registryConfigJSON`                         | Overrides global.containerRegistry.configJSON                                                     |
| `falcon-clusterguard.clusterName`                                      | Cluster name reported by every FCG component. Required when it can't be discovered automatically  |
| `falcon-clusterguard.falcon.cid`                                       | Overrides global.falcon.cid                                                                       |
| `falcon-clusterguard.falcon.trace`                                     | Set trace level (`none`,`err`,`warn`,`info`,`debug`); Default: `none`                             |
| `falcon-clusterguard.falconSecret.enabled`                             | Overrides global.falconSecret.enabled                                                             |
| `falcon-clusterguard.falconSecret.secretName`                          | Overrides global.falconSecret.secretName                                                          |
| `falcon-clusterguard.nodeSensor.enabled`                               | Deploy the node sensor DaemonSet. Default: true                                                   |
| `falcon-clusterguard.clusterguardController.admissionControl.enabled`  | Deploy the validating admission webhook. Default: false                                           |
| `falcon-clusterguard.imageAnalyzer.enabled`                            | Deploy the image analyzer. Default: false                                                         |
| `falcon-clusterguard.imageAnalyzer.mode`                               | `deployment` (watcher mode) or `daemonset` (socket mode). Default: `deployment`                   |
| `falcon-clusterguard.imageAnalyzer.crowdstrikeConfig.clientID`         | CrowdStrike Falcon OAuth client ID. Required for the image analyzer unless using `falconSecret` or `secretsStore` |
| `falcon-clusterguard.imageAnalyzer.crowdstrikeConfig.clientSecret`     | CrowdStrike Falcon OAuth client secret. Required for the image analyzer unless using `falconSecret` or `secretsStore` |
| `falcon-clusterguard.imageAnalyzer.crowdstrikeConfig.agentRuntime`     | Node container runtime. Required when `imageAnalyzer.mode=daemonset`                              |
| `falcon-clusterguard.secretsStore.enabled`                             | Overrides global.secretsStore.enabled for this component. See [Secrets Store CSI Driver Integration](#secrets-store-csi-driver-integration). |
| `falcon-clusterguard.secretsStore.provider`                            | Overrides global.secretsStore.provider for this component                                         |
| `falcon-clusterguard.secretsStore.azure.vaultName`                     | Overrides global.secretsStore.azure.vaultName for this component                                  |
| `falcon-clusterguard.secretsStore.azure.tenantID`                      | Overrides global.secretsStore.azure.tenantID for this component                                   |
| `falcon-clusterguard.secretsStore.azure.clientID`                      | Overrides global.secretsStore.azure.clientID for this component                                   |
| `falcon-clusterguard.secretsStore.provisioningTokenSecretName`         | Secrets store secret name for `FALCONCTL_OPT_PROVISIONING_TOKEN` (optional)                       |

#### Falcon Container Sensor
Falcon Container sensor specific configurations must be prefixed with `falcon-sensor`. For comprehensive configuration options please see the linked documentation below.
- [Falcon Sensor - Falcon Configuration Options](/helm-charts/falcon-sensor/README.md#falcon-configuration-options)
- [Falcon Sensor - Container Configuration Options](/helm-charts/falcon-sensor/README.md#container-sensor-configuration)

**Required Values:**

| Parameter                                              | Description                                                                 |
|:-------------------------------------------------------|:----------------------------------------------------------------------------|
| `falcon-sensor.enabled`                                | Enable the falcon-sensor subchart (must be `true`). Default: false          |
| `falcon-sensor.container.enabled`                      | Enable sensor installation as a sidecar container (must be `true`)          |
| `falcon-sensor.container.image.repository`             | Falcon Container Sensor container registry URL                              |
| `falcon-sensor.container.image.tag`                    | Falcon Container Sensor container image tag                                 |
| `falcon-sensor.container.image.pullSecrets.enable`     | Required if connecting to a container registry that requires authentication |
| `falcon-sensor.container.image.pullSecrets.namespaces` | List of allowed namespaces to use given pull secrets                        |

> [!NOTE]
> `falcon-sensor.node.enabled` must remain `false` (the falcon-platform default). Setting it to `true`
> fails the install, because the FCG node sensor replaces the falcon-sensor DaemonSet.

**Optional Values:**

| Parameter                                                      | Description                                                              |
|:---------------------------------------------------------------|:-------------------------------------------------------------------------|
| `falcon-sensor.falcon.trace`                                   | Set trace level (`none`,`err`,`warn`,`info`,`debug`); Default: `none`    |
| `falcon-sensor.container.image.digest`                         | Falcon Container Sensor container image digest (alternative to `tag`)    |
| `falcon-sensor.container.image.pullSecrets.allNamespaces`      | Allow all namespaces to use given pull secrets - Not supported on ArgoCD |
| `falcon-sensor.container.image.pullSecrets.name`               | Overrides global.containerRegistry.pullSecret                            |
| `falcon-sensor.container.image.pullSecrets.registryConfigJSON` | Overrides global.containerRegistry.configJSON                            |
| `falcon-sensor.container.podLabels`                            | Additional labels to add to the injector Deployment pods                 |
| `falcon-sensor.falcon.cid`                                     | Overrides global.falcon.cid                                              |
| `falcon-sensor.falconSecret.enabled`                           | Overrides global.falconSecret.enabled                                    |
| `falcon-sensor.falconSecret.secretName`                        | Overrides global.falconSecret.secretName                                 |
| `falcon-sensor.secretsStore.enabled`                           | Overrides global.secretsStore.enabled for this component. See [Secrets Store CSI Driver Integration](#secrets-store-csi-driver-integration). |
| `falcon-sensor.secretsStore.provider`                          | Overrides global.secretsStore.provider for this component                |
| `falcon-sensor.secretsStore.azure.vaultName`                   | Overrides global.secretsStore.azure.vaultName for this component         |
| `falcon-sensor.secretsStore.azure.tenantID`                    | Overrides global.secretsStore.azure.tenantID for this component          |
| `falcon-sensor.secretsStore.azure.clientID`                    | Overrides global.secretsStore.azure.clientID for this component          |
| `falcon-sensor.secretsStore.provisioningTokenSecretName`       | Secrets store secret name for `FALCONCTL_OPT_PROVISIONING_TOKEN` (optional) |

### Using Existing Kubernetes Secrets

Instead of specifying sensitive values directly in Helm values, you can use existing Kubernetes secrets for the following env vars:
- `FALCONCTL_OPT_CID`: Falcon CID - Required for falcon-clusterguard and falcon-sensor
- `FALCONCTL_OPT_PROVISIONING_TOKEN`: Falcon provisioning token - Optional for falcon-clusterguard and falcon-sensor
- `AGENT_CLIENT_ID`: Falcon OAuth client ID - Required for the falcon-clusterguard image analyzer
- `AGENT_CLIENT_SECRET`: Falcon OAuth client secret - Required for the falcon-clusterguard image analyzer
- `AGENT_CID`: Falcon CID - Required for the falcon-clusterguard image analyzer

When using `falconSecret`, create the secret in the component namespace beforehand. Both components
use `falcon-system` by default, so a single secret serves both:

```bash
# Set additional environment variables
export FALCON_SECRET_NAME=<your-falcon-secret-name>
export FALCON_PROVISIONING_TOKEN=<your-falcon-provisioning-token>

# First create the component namespace
kubectl create namespace falcon-system

# Create secret with required values for falcon-clusterguard and falcon-sensor
kubectl create secret generic $FALCON_SECRET_NAME -n falcon-system \
  --from-literal=FALCONCTL_OPT_CID=$FALCON_CID \
  --from-literal=FALCONCTL_OPT_PROVISIONING_TOKEN=$FALCON_PROVISIONING_TOKEN \
  --from-literal=AGENT_CLIENT_ID=$FALCON_CLIENT_ID \
  --from-literal=AGENT_CLIENT_SECRET=$FALCON_CLIENT_SECRET \
  --from-literal=AGENT_CID=$FALCON_CID
```

The `AGENT_*` keys are only needed when the FCG image analyzer is enabled. With the image analyzer
enabled, don't set `falcon-clusterguard.imageAnalyzer.crowdstrikeConfig.clientID` or `clientSecret`.

Once you have created your Kubernetes secret, you can install the falcon-platform Helm chart with the following global options:

```bash
helm install falcon-platform crowdstrike/falcon-platform --version $PLATFORM_CHART_VERSION -n falcon-platform \
  --create-namespace \
  --set global.falconSecret.enabled=true \
  --set global.falconSecret.secretName=$FALCON_SECRET_NAME \
  --set global.containerRegistry.configJSON=$ENCODED_DOCKER_CONFIG \
  --set falcon-clusterguard.image.repository=$FCG_REGISTRY \
  --set falcon-clusterguard.image.tag=$FCG_IMAGE_TAG \
  --set falcon-clusterguard.clusterName=$CLUSTER_NAME \
  --set falcon-clusterguard.imageAnalyzer.enabled=true
```

### Secrets Store CSI Driver Integration

The Falcon Platform supports sourcing credentials from external secret stores via the [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/). Supported providers include:
- [Azure Key Vault](https://azure.microsoft.com/en-us/products/key-vault) via the [Azure Key Vault provider](https://azure.github.io/secrets-store-csi-driver-provider-azure/)

For Azure Key Vault, the vault name, tenant ID, and optional workload identity client ID can be configured once under `global.secretsStore` and shared across all components. Per-component values override globals when both are set.

> [!NOTE]
> `falcon-clusterguard` uses one `secretsStore` block for the node sensor, clusterguard controller, and image analyzer. When it is enabled, it is mutually exclusive with `falcon.cid`/`global.falcon.cid` and `falconSecret`, so every FCG component (including the image analyzer) reads the CID from `falcon-cid`. The image analyzer also cannot be combined with `imageAnalyzer.crowdstrikeConfig.clientID`/`clientSecret`. In general, the FCG image analyzer's client ID, client secret, and CID must all come from one source: Helm values, the `falconSecret`/`global.falconSecret` secret (keys `AGENT_CLIENT_ID`, `AGENT_CLIENT_SECRET`, `AGENT_CID`), or the secrets store.

#### Prerequisites (all components)

**For Azure Key Vault:**

- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/getting-started/installation)
- [Azure Key Vault Provider for Secrets Store CSI Driver](https://azure.github.io/secrets-store-csi-driver-provider-azure/docs/getting-started/installation/)
- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/docs/installation.html) webhook installed on the cluster
- AKS cluster with OIDC issuer enabled
- A user-assigned managed identity with `Key Vault Secrets User` role on the vault, with federated credentials bound to each component's ServiceAccount in its respective namespace

#### Required secrets per component

**Azure Key Vault** (fixed secret names):

| Component                                        | Secret name (Azure)                                   | Env var mapped                     |
|:-------------------------------------------------|:------------------------------------------------------|:-----------------------------------|
| falcon-clusterguard (node sensor, cg-controller) | `falcon-cid`                                          | `FALCONCTL_OPT_CID`                |
| falcon-clusterguard (node sensor, cg-controller) | `secretsStore.provisioningTokenSecretName` (optional) | `FALCONCTL_OPT_PROVISIONING_TOKEN` |
| falcon-clusterguard (image analyzer)             | `falcon-client-id`                                    | `AGENT_CLIENT_ID`                  |
| falcon-clusterguard (image analyzer)             | `falcon-client-secret`                                | `AGENT_CLIENT_SECRET`              |
| falcon-clusterguard (image analyzer)             | `falcon-cid`                                          | `AGENT_CID`                        |
| falcon-sensor (container)                        | `falcon-cid`                                          | `FALCONCTL_OPT_CID`                |
| falcon-sensor (container)                        | `falcon-provisioning-token` (optional, configurable)  | `FALCONCTL_OPT_PROVISIONING_TOKEN` |

`falcon-clusterguard` creates two SecretProviderClasses in its namespace, `<release>-falcon-clusterguard-csi` for the node sensor and clusterguard controller and `falcon-clusterguard-iar-csi` for the Image Analyzer, so the Image Analyzer's API client credentials are never mounted by the node sensor. If `global.secretsStore.secretName` is set, FCG uses it for the node sensor/controller secret and `<secretName>-iar` for the Image Analyzer secret.

#### Example configuration

**Azure Key Vault:**

Use `global.secretsStore` to configure the shared secrets store once. Secret names are fixed per component (`falcon-cid`, `falcon-client-id`, `falcon-client-secret`) — only the Workload Identity `serviceAccount.annotations` and pod labels must be configured per component.

> [!NOTE]
> The global config populates secrets store connection details in each `SecretProviderClass`. It does **not** automatically set the per-component `serviceAccount.annotations` or pod labels required by Azure Workload Identity — those must still be configured per component as shown below.

```yaml
global:
  secretsStore:
    enabled: true
    provider: azure
    azure:
      vaultName: "my-keyvault"
      tenantID: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      # clientID: ""  # optional: required only when multiple managed identities are assigned

falcon-clusterguard:
  nodeSensor:
    serviceAccount:
      annotations:
        azure.workload.identity/client-id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    podLabels:
      azure.workload.identity/use: "true"
  clusterguardController:
    serviceAccount:
      annotations:
        azure.workload.identity/client-id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    podLabels:
      azure.workload.identity/use: "true"
  imageAnalyzer:          # only when the FCG Image Analyzer is enabled
    serviceAccount:
      annotations:
        azure.workload.identity/client-id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    podLabels:
      azure.workload.identity/use: "true"

falcon-sensor:            # only when the Falcon Container sensor is enabled
  serviceAccount:
    annotations:
      azure.workload.identity/client-id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  container:
    podLabels:
      azure.workload.identity/use: "true"
```

To use a custom provisioning token secret name for `falcon-clusterguard` or `falcon-sensor`, set `secretsStore.provisioningTokenSecretName` in that component's section.

Each component can still override `vaultName`, `tenantID`, or `clientID` individually if needed — per-component values take precedence over globals.

## Upgrade Strategy

### Install/Reinstall a Single Component
When installing a new component for the first time, make sure the component namespace exists.
`createComponentNamespaces` does not support namespace creation for Helm upgrades. Both components
use `falcon-system` by default, so the namespace usually already exists.

```bash
# Create the component namespace if it does not already exist
kubectl create namespace falcon-system

# Upgrade Helm chart with new component enabled and required values - for example to add the Falcon Container sensor after initial Helm install
helm upgrade --install falcon-platform crowdstrike/falcon-platform --version $PLATFORM_CHART_VERSION -n falcon-platform \
  --reuse-values \
  --set falcon-sensor.enabled=true \
  --set falcon-sensor.container.enabled=true \
  --set falcon-sensor.container.image.repository=$SENSOR_REGISTRY \
  --set falcon-sensor.container.image.tag=$SENSOR_IMAGE_TAG
```

FCG workloads are enabled the same way, for example `--set falcon-clusterguard.imageAnalyzer.enabled=true`
together with the image analyzer credentials.

### Upgrade the Falcon Platform Helm Chart Version
```bash
# Update Helm repository
helm repo update

# Upgrade Helm chart with existing Helm values
helm upgrade falcon-platform crowdstrike/falcon-platform --version $PLATFORM_CHART_VERSION -n falcon-platform \
  --reuse-values
```

> [!IMPORTANT]
> If you are upgrading from falcon-platform `1.x`, don't use `--reuse-values`. Follow
> [Migrating to Falcon Cluster Guard (FCG)](#migrating-to-falcon-cluster-guard-fcg) instead.

### Individual Component Updates

```bash
# Upgrade the version of each Falcon component image
helm upgrade falcon-platform crowdstrike/falcon-platform --version $PLATFORM_CHART_VERSION -n falcon-platform \
  --reuse-values \
  --set falcon-clusterguard.image.tag=$FCG_IMAGE_TAG \
  --set falcon-sensor.container.image.tag=$SENSOR_IMAGE_TAG
```

> [!IMPORTANT]
> You cannot customize which helm chart version is being used for each individual Falcon component
> subchart. Component versions are managed through the falcon-platform chart's [dependencies](./Chart.yaml).
> The dependent subchart versions are locked. Update the umbrella chart to get the latest Falcon component
> helm chart versions for each subchart.

## Uninstall

### Uninstall a Single Component

```bash
# Upgrade your helm release with the component disabled - for example to uninstall the Falcon Container sensor only:
helm upgrade falcon-platform crowdstrike/falcon-platform --version $PLATFORM_CHART_VERSION -n falcon-platform \
  --reuse-values \
  --set falcon-sensor.enabled=false
```

To remove a single FCG workload, disable it instead, for example
`--set falcon-clusterguard.imageAnalyzer.enabled=false`. Don't delete the `falcon-system` namespace
while another component still runs in it.

### Uninstall the Falcon Platform Helm Chart

When the FCG node sensor is enabled, `helm uninstall` runs a cleanup DaemonSet that removes the
sensor from every node. See [Uninstall Helm Chart](/helm-charts/falcon-clusterguard/README.md#uninstall-helm-chart).

```bash
# Remove Falcon Platform and all components
helm uninstall falcon-platform -n falcon-platform

# Optionally delete the release namespace and the Falcon component namespace
kubectl delete namespace falcon-platform falcon-system
```

## Migrating from Individual Component Helm Charts
> [!WARNING]
> If you are already using the individual `falcon-clusterguard` or `falcon-sensor` Helm charts,
> we recommend to continue doing so. Migrating to the unified falcon-platform Helm chart requires
> completely uninstalling and reinstalling your Falcon components, which is not recommended.

## Migrating to Falcon Cluster Guard (FCG)

Falcon Cluster Guard (`falcon-clusterguard`) replaces the falcon-platform `1.x` node sensor
(`falcon-sensor` node mode), Kubernetes Admission Controller (`falcon-kac`), and Image Assessment at
Runtime (`falcon-image-analyzer`) with a single unified chart and container image. If you are
upgrading from a `1.x` version of `falcon-platform`, follow the steps below.

> [!IMPORTANT]
> **`falcon-sensor` is NOT fully deprecated.** It still supports the Falcon Container sensor.
> **Container mode** (`container.enabled: true`) — has no FCG equivalent. `falcon-sensor`
> must remain deployed for any cluster running container sensor workloads.
>
> `falcon-kac` and `falcon-image-analyzer` are fully deprecated and equivalent features have been migrated to `falcon-clusterguard`.

> [!NOTE]
> DaemonSet deployments of sensor versions 7.33 and earlier of the Falcon sensor for Linux are blocked from updates and
> uninstallation if their sensor update policy has the **Uninstall and maintenance protection** setting enabled. Before
> migrating these versions of the sensor, move the sensors to a new sensor update policy with this
> policy setting turned off. For more info, see [Sensor update and uninstallation for DaemonSet sensor versions 7.33
> and lower](https://falcon.crowdstrike.com/documentation/anchor/sc632f2e).

### What Changed

| Area             | Before (falcon-platform `1.x`)                              | After                                                                            |
|------------------|-------------------------------------------------------------|----------------------------------------------------------------------------------|
| Node sensor      | `falcon-sensor.node.*`                                      | `falcon-clusterguard.nodeSensor.*` — `falcon-sensor` node mode removed           |
| Container sensor | `falcon-sensor.container.*`                                 | **Unchanged** — `falcon-sensor` subchart retained for container mode             |
| KAC              | `falcon-kac` subchart, `falcon-kac.*`                       | `falcon-clusterguard.clusterguardController.*` — `falcon-kac` subchart removed   |
| Image scanning   | `falcon-image-analyzer` subchart, `falcon-image-analyzer.*` | `falcon-clusterguard.imageAnalyzer.*` — `falcon-image-analyzer` subchart removed |
| IAR mode         | `deployment.enabled` or `daemonset.enabled`                 | `falcon-clusterguard.imageAnalyzer.mode` (`deployment` or `daemonset`)           |
| Container image  | Separate images per component                               | Single unified FCG image                                                         |
| Namespace        | `falcon-system`, `falcon-kac`, `falcon-image-analyzer`      | `falcon-system` for FCG                                                          |

### Step 1 — Run the migration script

The migration script automatically remaps your existing values file to the FCG schema.

If you installed with `--set` flags, or don't have your current values file, export the release's
values first:

```bash
helm get values falcon-platform -n falcon-platform -o yaml > my-values.yaml
```

**Prerequisites:**
```bash
pip3 install ruamel.yaml
```

**Preview the migration (no files written):**
```bash
python3 scripts/migration/migrate-to-fcg.py --platform-values my-values.yaml --fcg-image-repo <fcg-repo> --fcg-image-tag <fcg-tag> --dry-run
```

> [!NOTE]
> The script has no default FCG image repository, tag, or digest yet. Pass `--fcg-image-repo`
> and `--fcg-image-tag` (or `--fcg-image-digest`), or enter them when the script prompts.
> Default values will be added once FCG is generally available.

Review the warnings printed to stderr — they flag deprecated keys and anything that needs
manual attention before proceeding.

**Write the migrated file:**
```bash
python3 scripts/migration/migrate-to-fcg.py --platform-values my-values.yaml --fcg-image-repo <fcg-repo> --fcg-image-tag <fcg-tag> --output my-values-fcg.yaml
```

**Diff the result:**
```bash
diff my-values.yaml my-values-fcg.yaml
```

The script stops with an error if a values file can't be migrated, for example invalid YAML or a
file passed with the wrong flag. Add `--validate` to check that the migrated values render with the
`falcon-clusterguard` chart (requires `helm`).

> [!NOTE]
> See [`scripts/migration/README.md`](../../scripts/migration/README.md) for full script documentation, including
> all key mappings, renamed resource keys, and how deprecated keys are annotated in the output.

### Step 2 — Check for deprecated keys

The script drops keys that have no FCG equivalent and prints a warning for each one. Comments in
your values file move with their keys; comments that couldn't be placed, because their key was
dropped or its value changed, are listed in a warning. Review the warnings, particularly for:

| Deprecated key | Action |
|----------------|--------|
| `falcon-sensor.node.backend` | Removed automatically — FCG auto-selects eBPF/kernel |
| `falcon-sensor.node.image.digest`, `falcon-kac.image.digest` | Removed with a warning — the digest belongs to the old image; set `falcon-clusterguard.image.digest` to the FCG image digest if you pin by digest |
| `falcon-image-analyzer.image.repository` / `tag` / `digest` | Removed automatically — the image analyzer runs from the FCG image |
| `falcon-image-analyzer.crowdstrikeConfig.existingSecret` | Removed with a warning — add `AGENT_CLIENT_ID`, `AGENT_CLIENT_SECRET`, and `AGENT_CID` to `falcon-clusterguard.falconSecret` instead |
| `falcon-image-analyzer.secretsStore.*` | Removed with a warning — configure `falcon-clusterguard.secretsStore`, which covers every FCG component |

### Step 3 — Confirm the image analyzer settings

The image analyzer now runs inside FCG, in the FCG namespace and from the FCG image. The migration
script moves `falcon-image-analyzer.*` values to `falcon-clusterguard.imageAnalyzer.*`:

```yaml
falcon-clusterguard:
  imageAnalyzer:
    enabled: true
    crowdstrikeConfig:
      clientID: "abc123"
      clientSecret: "secret"
```

Some settings move outside `imageAnalyzer` because FCG shares them across components:

| Previous `falcon-image-analyzer` value | FCG value                                                                                                  |
|----------------------------------------|------------------------------------------------------------------------------------------------------------|
| `daemonset.enabled: true`              | `imageAnalyzer.mode: daemonset` (`agentRuntime`, `agentRuntimeSocket`, and `securityContext` move with it) |
| `crowdstrikeConfig.clusterName`        | `clusterName` (top level)                                                                                  |
| `crowdstrikeConfig.cid`                | `falcon.cid`, if no FCG or global CID is set                                                               |
| `azure.*`                              | `azure.*` (top level)                                                                                      |
| `gcp.enabled`                          | `gke.enabled`                                                                                              |
| `openshift.sccName`                    | `openshift.iarSCCName`                                                                                     |

`kac.namespace` and `namespaceOverride` are no longer used. The output has no
`falcon-image-analyzer` block, because `falcon-platform` no longer includes that subchart. See
[`scripts/migration/README.md`](../../scripts/migration/README.md) for the full list of image analyzer mappings.

### Step 4 — Apply the upgrade

```bash
helm upgrade falcon-platform crowdstrike/falcon-platform \
  -n falcon-platform \
  -f my-values-fcg.yaml
```

Don't add `--reuse-values`. The migrated file already contains all of your settings, and
`--reuse-values` would bring back the old `falcon-sensor.node`, `falcon-kac`, and
`falcon-image-analyzer` values. See [Upgrade Errors After Migrating to FCG](#upgrade-errors-after-migrating-to-fcg)
if the upgrade fails.

> [!NOTE]
> `falcon-kac` and `falcon-image-analyzer` are no longer subchart dependencies of `falcon-platform`,
> and `falcon-sensor` no longer deploys node mode. Running `helm upgrade` automatically removes
> their Kubernetes resources (DaemonSet, Deployment, RBAC, etc.) as part of the normal diff — no
> explicit `enabled: false` flag is required, and the `falcon-sensor` cleanup DaemonSet will
> **not** run (that only fires on `helm uninstall`). The FCG image analyzer starts in the FCG
> namespace in the same upgrade.

> [!IMPORTANT]
> If you also run `falcon-sensor` (node mode), `falcon-kac`, or `falcon-image-analyzer` as separate
> Helm releases outside `falcon-platform`, uninstall them before this upgrade. FCG creates some of
> the same objects, such as the ValidatingWebhookConfiguration `validating.falcon-kac.crowdstrike.com`
> and the `falcon-sensor` DaemonSet, and Helm won't take them over from another release. To keep each
> node's agent ID (AID), uninstall `falcon-sensor` with `--no-hooks` so its cleanup doesn't remove the
> AID. See [Migrating from falcon-sensor and falcon-kac](../falcon-clusterguard/README.md#migrating-from-falcon-sensor-and-falcon-kac)
> for the full list.

### Step 5 — Clean up deprecated namespaces

Once the upgrade is confirmed stable:

```bash
kubectl delete ns falcon-kac falcon-image-analyzer
```

### Example: before and after values

**Before:**
```yaml
global:
  falcon:
    cid: YOUR-CID-HERE

falcon-sensor:
  enabled: true
  namespaceOverride: falcon-system
  node:
    clusterName: "my-cluster"
    daemonset:
      tolerations:
        - key: "node-role.kubernetes.io/master"
          operator: "Exists"
          effect: "NoSchedule"

falcon-kac:
  enabled: true
  clusterName: "my-cluster"
  admissionControl:
    enabled: true
  clusterVisibility:
    resourceWatcher:
      enabled: true
  falconClientResources:
    limits:
      memory: 384Mi
    requests:
      cpu: 250m
      memory: 384Mi

falcon-image-analyzer:
  enabled: true
  deployment:
    enabled: true
  crowdstrikeConfig:
    clientID: "abc123"
    clientSecret: "secret"
```

**After (output of migration script):**
```yaml
global:
  falcon:
    cid: YOUR-CID-HERE

# falcon-sensor.node is deprecated — replaced by falcon-clusterguard.nodeSensor.*
# falcon-kac is deprecated — replaced by falcon-clusterguard.clusterguardController.*
# falcon-image-analyzer is deprecated — replaced by falcon-clusterguard.imageAnalyzer.*

falcon-clusterguard:
  enabled: true
  namespaceOverride: falcon-system
  clusterName: "my-cluster"
  image:
    repository: registry.crowdstrike.com/falcon-clusterguard/release/falcon-clusterguard
    tag: <fcg-tag>
  nodeSensor:
    daemonset:
      tolerations:
        - key: "node-role.kubernetes.io/master"
          operator: "Exists"
          effect: "NoSchedule"
    serviceAccount:
      name: crowdstrike-falcon-sa

  clusterguardController:
    admissionControl:
      enabled: true
    resources:
      client:  # was: falconClientResources
        limits:
          memory: 384Mi
        requests:
          cpu: 250m
          memory: 384Mi
    serviceAccount:
      name: falcon-kac-sa
    visibility:
      resourceWatcher:
        enabled: true

  imageAnalyzer:
    enabled: true
    crowdstrikeConfig:
      clientID: "abc123"
      clientSecret: "secret"
```

The script keeps the previous ServiceAccount names so that existing bindings, such as IRSA or
Workload Identity, keep working.

### Container sensor + FCG together

If your cluster uses the container sensor together with KAC and/or IAR, the migrated values file has
**both** `falcon-sensor` and `falcon-clusterguard` enabled. The clusterguard controller and image
analyzer run in FCG:

```yaml
# Container sensor — stays on the falcon-sensor chart
falcon-sensor:
  enabled: true
  container:
    enabled: true         # container mode continues here
    image:
      repository: registry.crowdstrike.com/falcon-container/release/falcon-container
      tag: "<falcon-container-tag>"

# Clusterguard controller + image analyzer — new FCG chart
falcon-clusterguard:
  enabled: true
  image:
    repository: registry.crowdstrike.com/falcon-clusterguard/release/falcon-clusterguard
    tag: "<fcg-tag>"
  nodeSensor:
    enabled: false        # set because falcon-sensor.node.enabled was false
  clusterguardController:
    admissionControl:
      enabled: true       # KAC admission control moved to falcon-clusterguard
  imageAnalyzer:
    enabled: true         # image analyzer moved to falcon-clusterguard
```

The script sets `falcon-clusterguard.nodeSensor.enabled: false` when your previous values didn't
run the node sensor, and prints a warning. Set it to `true` to deploy the FCG node sensor.

## Troubleshooting

### Partial Falcon Platform Installation - Release Failure
In some cases you might be missing some permissions or your cluster might not be set up the way you expected. This can lead to a scenario where the Helm release was created, but the release `failed` and it only installed some of the Falcon components.

Once you have diagnosed the root cause of the failure and addressed the issue, you can either:
1. Do a complete uninstall, then reinstall.
2. Or run a `helm upgrade --install` with the necessary Helm values to [install the remaining Falcon components](#installreinstall-a-single-component).

### Upgrade Errors After Migrating to FCG

#### `node.enabled=true is no longer supported starting with falcon-sensor chart version 2.0.0`

Your values still set `falcon-sensor.node.enabled: true`. This usually comes from `--reuse-values`,
which brings back the values from the previous release, or from a values file that wasn't migrated.
Upgrade with only the migrated values file, as shown in [Step 4](#step-4--apply-the-upgrade). If you
still run the Falcon Container sensor, set `falcon-sensor.node.enabled: false` and
`falcon-sensor.container.enabled: true`.

#### Two node sensor pods on a node during the upgrade

If the old node sensor DaemonSet has a different name from FCG's `falcon-sensor` DaemonSet, for
example the default `falcon-platform-falcon-sensor`, Helm creates the FCG DaemonSet before it deletes
the old one. For a short time, each node runs an old and a new node sensor pod. The old pods stop
when Helm deletes the old DaemonSet later in the same upgrade.

#### Other upgrade errors

For `field is immutable`, `cannot be imported into the current release`, and server-side apply
conflict errors, see [Upgrade Errors](../falcon-clusterguard/README.md#upgrade-errors) in the
`falcon-clusterguard` README.

### Falcon Cluster Guard Troubleshooting Guides
- [Falcon Cluster Guard - Node Sensor Deployment Considerations](/helm-charts/falcon-clusterguard/README.md#deployment-considerations)
- [Falcon Cluster Guard - Pod Security Standards](/helm-charts/falcon-clusterguard/README.md#pod-security-standards)
- [Falcon Cluster Guard - Image Analyzer Configuration](/helm-charts/falcon-clusterguard/README.md#image-analyzer-configuration)
- [Falcon Cluster Guard - More Troubleshooting](/helm-charts/falcon-clusterguard/README.md#troubleshooting)

### Falcon Container Sensor Troubleshooting Guides
- [Falcon Sensor - Container Deployment Considerations](/helm-charts/falcon-sensor/README.md#deployment-considerations-1)
- [Falcon Sensor - More Troubleshooting](/helm-charts/falcon-sensor/README.md#troubleshooting)

### Component Logs
For debugging purposes make sure to enable debug level logging for the relevant Falcon components.

#### Falcon Cluster Guard Logs
```bash
# Enable debug level logs for the FCG node sensor and clusterguard controller
helm upgrade falcon-platform crowdstrike/falcon-platform --version $PLATFORM_CHART_VERSION -n falcon-platform \
  --reuse-values \
  --set falcon-clusterguard.falcon.trace=debug

# Get node sensor logs
kubectl logs -n falcon-system -l app=falcon-sensor

# Get clusterguard controller logs
kubectl logs -n falcon-system -l app=falcon-clusterguard --all-containers
```

To debug only one of them, set `falcon-clusterguard.nodeSensor.falcon.trace` or
`falcon-clusterguard.clusterguardController.falcon.trace` instead.

#### Image Analyzer Logs
```bash
# Enable debug level logs for the FCG image analyzer
helm upgrade falcon-platform crowdstrike/falcon-platform --version $PLATFORM_CHART_VERSION -n falcon-platform \
  --reuse-values \
  --set falcon-clusterguard.imageAnalyzer.log.verbosity=debug

# Get image analyzer logs
kubectl logs -n falcon-system -l app=falcon-image-analyzer
```

#### Container Sensor Logs
```bash
# Enable debug level logs for falcon-sensor
helm upgrade falcon-platform crowdstrike/falcon-platform --version $PLATFORM_CHART_VERSION -n falcon-platform \
  --reuse-values \
  --set falcon-sensor.falcon.trace=debug

# Get container sensor injector logs
kubectl logs -n falcon-system -l app=falcon-sensor-injector
```
