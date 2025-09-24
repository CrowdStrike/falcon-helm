# CrowdStrike Falcon Platform Helm Chart

A comprehensive Helm chart that deploys the complete CrowdStrike Falcon Kubernetes runtime security platform. This chart manages all individual Falcon components as dependencies, providing a unified deployment and configuration experience.

## Overview

The Falcon Platform Helm chart allows you to deploy and manage the entire CrowdStrike Falcon Kubernetes runtime security stack with a single Helm installation. It coordinates the deployment of multiple security components while providing centralized configuration management and deployment orchestration.

## Components Included

| Component                                                                 | Purpose                                |
|---------------------------------------------------------------------------|----------------------------------------|
| [**Falcon Sensor**](/helm-charts/falcon-sensor/README.md)                 | Runtime node protection and monitoring |
| [**Falcon KAC**](/helm-charts/falcon-kac/README.md)                       | Kubernetes admission controller        |
| [**Falcon Image Analyzer**](/helm-charts/falcon-image-analyzer/README.md) | Container image vulnerability scanning |

## Prerequisites
### Minimum Requirements
- Helm 3.x
- Falcon Customer ID (CID)
- Appropriate cluster permissions (cluster-admin for installation)
- Falcon registry access to pull Falcon component docker images

## Quick Start

**NOTES:**
- The falcon-platform Helm chart uses the latest version of each Falcon component subchart and does not allow version customization for individual subcharts. For granular version control, use the individual Falcon component Helm charts instead.
- The falcon-platform Helm chart creates dedicated namespaces for each Falcon component automatically. For optimal security and resource management, we recommend deploying each component in its own dedicated namespace.
- The falcon-platform Helm chart treats all CrowdStrike components as a single deployment. Running `helm uninstall` will remove all components - follow the [guide here](#uninstall-a-single-component) to uninstall a single component.

### 1. Add the Helm Repository

```bash
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
helm repo update
```

### 2. Minimal Installation

Deploy core security components (Sensor + Admission Controller):

```bash
helm install falcon-platform crowdstrike/falcon-platform --version $FALCON_PLATFROM_VERSION -n falcon-platform \
--create-namespace \
--set global.falcon.cid=$FALCON_CID \
--set global.docker.registryConfigJSON=$DOCKER_CONFIG_ENCODED \
--set falcon-sensor.enabled=true \
--set falcon-sensor.node.image.repository=$SENSOR_DOCKER_REGISTRY \
--set falcon-sensor.node.image.tag=$FALCON_SENSOR_IMAGE_TAG \
--set falcon-kac.enabled=true \
--set falcon-kac.image.repository=$KAC_DOCKER_REGISTRY \
--set falcon-kac.image.tag=$FALCON_KAC_IMAGE_TAG
```

### 3. Comprehensive Installation with Values File and Falcon Secret

Deploy all components:

```bash
# Create a values file with your configuration
cat > falcon-platform-values.yaml << EOF
global:
  # Use external secret for sensitive values
  falconSecret:
    enabled: true
    secretName: falcon-secrets
  docker:
    registryConfigJSON="YOUR_BASE64_ENCODED_DOCKER_CONFIG_JSON"

falcon-sensor:
  enabled: true
  node:
    enabled: true
    image:
      repository: "SENSOR_DOCKER_REGISTRY"
      tag: "FALCON_SENSOR_IMAGE_TAG"

falcon-kac:
  enabled: true
  image:
    repository: "KAC_DOCKER_REGISTRY"
    tag: "FALCON_KAC_IMAGE_TAG"

falcon-image-analyzer:
  enabled: true
  daemonset:
    enabled: true
  image:
    repository: "IMAGE_ANALYZER_DOCKER_REGISTRY"
    tag: "FALCON_IAR_IMAGE_TAG"

  crowdstrikeConfig:
    clusterName: "YOUR_CLUSTER_NAME"
    cid: "YOUR_FALCON_CID"
EOF

# Create the secrets first
kubectl create secret generic $FALCON_SECRET_NAME -n falcon-sensor \
  --from-literal=FALCONCTL_OPT_CID=$FALCON_CID \
  --from-literal=FALCONCTL_OPT_PROVISIONING_TOKEN=$FALCON_PROVISIONING_TOKEN

kubectl create secret generic $FALCON_SECRET_NAME -n falcon-kac \
  --from-literal=FALCONCTL_OPT_CID=$FALCON_CID

kubectl create secret generic $FALCON_SECRET_NAME -n falcon-image-analyzer \
  --from-literal=AGENT_CLIENT_ID=$FALCON_CLIENT_ID \
  --from-literal=AGENT_CLIENT_SECRET=$FALCON_CLIENT_SECRET

helm upgrade --install falcon-platform crowdstrike/falcon-platform --version $FALCON_PLATFROM_VERSION \
  --namespace falcon-platform \
  --create-namespace \
  -f falcon-platform-values.yaml
```

## Configuration

### Component-Specific Requirements

**Falcon Sensor:**
- Falcon CID
- CrowdStrike Docker registry access

**Falcon KAC:**
- Falcon CID
- CrowdStrike Docker registry access

**Falcon Image Analyzer:**
- Falcon CID
- CrowdStrike Docker registry access
- Kubernetes cluster name
- OAuth client credentials (Client ID + Secret)

### Global Configuration
Global settings apply to all components unless overridden by component specific values.

| Parameter                        | Default | Description                                                                                        |
|----------------------------------|---------|----------------------------------------------------------------------------------------------------|
| global.falcon.cid                | null    | Required for all components unless using an existing secret (`falconSecret`) with CID data         |
| global.falconSecret.enabled      | false   | Enable existing secret injection as an alternative to setting plain text values for sensitive data |
| global.falconSecret.secretName   | ""      | Name of existing Kubernetes secret with sensitive data necessary for Falcon component installation |
| global.docker.registryConfigJSON | ""      | Your docker config json as a base64 encoded string                                                 |
| global.docker.pullSecret         | ""      | Name of existing docker registry secret as an alternative to `registryConfigJSON`                  |

**NOTES:**
- Any existing secrets for `falconSecret` or `docker.pullSecret` must exist in the namespace dedicated to the respective Falcon component before installing the Helm chart. For example, you must already have an existing secret matching `global.falconSecret.secretName` in the `falcon-sensor` default namespace, or custom namespace you choose for your `falcon-sensor.namespaceOverride`.

### Component-Specific Configuration
Each Falcon component supports the existing configuration options for each subchart. 

#### Falcon Sensor
Falcon Sensor specific configurations must be prefixed with `falcon-sensor`. For comprehensive configuration options please see the linked documentation below.
- [Falcon Sensor - Falcon Configuration Options](/helm-charts/falcon-sensor/README.md#falcon-configuration-options)
- [Falcon Sensor - Daemonset Configuration Options](/helm-charts/falcon-sensor/README.md#node-configuration)
- [Falcon Sensor - Container Configuration Options](/helm-charts/falcon-sensor/README.md#container-sensor-configuration)

**Required Daemonset Values:**

| Parameter                              | Description                       |
|:---------------------------------------|:----------------------------------|
| `falcon-sensor.node.image.respository` | Falcon Sensor docker registry URL |
| `falcon-sensor.node.image.tag`         | Falcon Sensor docker image tag    |

**Optional Daemonset Values:**

| Parameter                         | Description                                              |
|:----------------------------------|:---------------------------------------------------------|
| `falcon-sensor.node.image.digest` | Falcon Sensor docker image digest (alternative to `tag`) |

**Required Container Values:**

| Parameter                                   | Description                                                        |
|:--------------------------------------------|:-------------------------------------------------------------------|
| `falcon-sensor.node.enabled`                | Enable daemonset installation (must be `false`)                    |
| `falcon-sensor.container.enabled`           | Enable sensor installation as a sidecar container (must be `true`) |
| `falcon-sensor.container.image.respository` | Falcon Container Sensor docker registry URL                        |
| `falcon-sensor.container.image.tag`         | Falcon Container Sensor docker image tag                           |

**Optional Container Values:**

| Parameter                                   | Description                                                        |
|:--------------------------------------------|:-------------------------------------------------------------------|
| `falcon-sensor.container.image.digest`      | Falcon Container Sensor docker image digest (alternative to `tag`) |

#### Falcon KAC
Falcon KAC specific configurations must be prefixed with `falcon-kac`. For comprehensive configuration options please see the linked documentation below.
- [Falcon KAC - Falcon Configuration Options](/helm-charts/falcon-kac/README.md#falcon-configuration-options)

**Required Values:**

| Parameter                      | Description                    |
|:-------------------------------|:-------------------------------|
| `falcon-kac.image.respository` | Falcon KAC docker registry URL |
| `falcon-kac.image.tag`         | Falcon KAC docker image tag    |

**Optional Values:**

| Parameter                 | Description                                              |
|:--------------------------|:---------------------------------------------------------|
| `falcon-kac.image.digest` | Falcon Sensor docker image digest (alternative to `tag`) |

#### Falcon Image Analyzer
- [Falcon Image Analyzer - Configuration Options](/helm-charts/falcon-image-analyzer/README.md#falcon-configuration-options)

**Required Values:**

| Parameter                                              | Description                               |
|:-------------------------------------------------------|:------------------------------------------|
| `falcon-image-analyzer.image.respository`              | Falcon Image Analyzer docker registry URL |
| `falcon-image-analyzer.image.tag`                      | Falcon Image Analyzer docker image tag    |
| `falcon-image-analyzer.crowdstrikeConfig.clusterName`  | Kubernetes cluster name                   |
| `falcon-image-analyzer.crowdstrikeConfig.clientId`     | CrowdStrike Falcon OAuth client ID        |
| `falcon-image-analyzer.crowdstrikeConfig.clientSecret` | CrowdStrike Falcon OAuth client secret    |

**Optional Values:**

| Parameter                            | Description                                                      |
|:-------------------------------------|:-----------------------------------------------------------------|
| `falcon-image-analyzer.image.digest` | Falcon Image Analyzer docker image digest (alternative to `tag`) |


### Using Existing Kubernetes Secrets

Instead of specifying sensitive values directly in Helm values, you can use existing Kubernetes secrets for the following env vars:
- `FALCONCTL_OPT_CID`: Falcon CID - Required for falcon-sensor and falcon-kac
- `FALCONCTL_OPT_PROVISIONING_TOKEN`: Falcon provisioning token - Optional for falcon-sensor and falcon-kac
- `AGENT_CLIENT_ID`: Falcon OAuth client ID - Required for falcon-image-analyzer
- `AGENT_CLIENT_SECRET`: Falcon OAuth client secret - Required for falcon-image-analyzer

When using `falconSecret`, create the secret in each respective namespace beforehand:

```bash
# Create secret with required values for falcon-sensor
kubectl create secret generic $FALCON_SECRET_NAME -n falcon-sensor \
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
helm install falcon-platform crowdstrike/falcon-platform --version $FALCON_PLATFORM_VERSION -n falcon-platform \
--create-namespace \
--set global.falconSecret.enabled=true \
--set global.falconSecret.secretName=$FALCON_SECRET_NAME \
--set global.docker.registryConfigJSON=$DOCKER_CONFIG_ENCODED \
--set falcon-sensor.enabled=true \
--set falcon-sensor.node.image.repository=$SENSOR_DOCKER_REGISTRY \
--set falcon-sensor.node.image.tag=7.28.0-18108-1.falcon-linux.Release.US-2 \
--set falcon-kac.enabled=true \
--set falcon-kac.image.repository=$KAC_DOCKER_REGISTRY \
--set falcon-kac.image.tag=7.27.0-2502.Release.US-2 \
--set falcon-image-analyzer.enabled=true \
--set falcon-image-analyzer.image.repository=$IMAGE_ANALYZER_DOCKER_REGISTRY \
--set falcon-image-analyzer.image.tag=1.0.20 \
--set falcon-image-analyzer.crowdstrikeConfig.clusterName=$CLUSTER_NAME \
--set falcon-image-analyzer.crowdstrikeConfig.cid=$FALCON_CID                   # IAR Falcon CID is not yet supported by existing secrets
```


## Verification

### Check Installation Status

```bash
# Check overall falcon-platform release status
helm status falcon-platform -n falcon-platform

# Check all pods in the falcon namespace
kubectl get pods -l app.kubernetes.io/instance=falcon-platform -A
```

### Verify Individual Component Health

```bash
# Sensor status (should show DaemonSet pods on all nodes)
# Falcon Sensor is deployed to falcon-sensor namespace by default
kubectl get deployments,daemonsets,pods -n falcon-sensor

# KAC webhook registration
# Falcon KAC is deployed to falcon-kac namespace by default
kubectl get deployments,pods -n falcon-kac

# Image analyzer deployment
# Falcon Image Analyzer is deployed to falcon-image-analyzer namespace by default
kubectl get deployments,daemonsets,pods -n falcon-image-analyzer
```

## Troubleshooting

### Falcon Sensor Troubleshooting Guide
- [Falcon Sensor - Troubleshooting](/helm-charts/falcon-sensor/README.md#troubleshooting)

### Falcon Image Analyzer - Pod Eviction
- [Falcon Image Analyzer - Pod Eviction](/helm-charts/falcon-image-analyzer/README.md#pod-eviction)

### Partial Falcon Platform Installation - Release Failure
In some cases you might be missing some permissions or your cluster might not be set up the way you expected. This can lead to a scenario where the Helm release was created, but the release `failed` and it only installed some of the Falcon components.

Once you have diagnosed the root cause of the failure and addressed the issue, you can either:
1. Do a complete uninstall, then reinstall.
2. Run a `helm upgrade` with the necessary Helm values to [install the remaining Falcon components](#installreinstall-a-single-component).

### Component Logs

```bash
# Sensor logs
kubectl logs -n falcon-sensor -l app.kubernetes.io/instance=falcon-platform

# KAC logs  
kubectl logs -n falcon-kac -l app.kubernetes.io/instance=falcon-platform

# Image analyzer logs
kubectl logs -n falcon-image-analyzer -l app.kubernetes.io/instance=falcon-platform
```

## Upgrade Strategy

### Install/Reinstall a single component
```bash
# Upgrade Helm chart with new component enabled and required values - for example to install falcon-kac after initial Helm install
helm upgrade falcon-platform crowdstrike/falcon-platform --version $FALCON_PLATFORM_VERSION -n falcon-platform \
  --reuse-values \
  --set falcon-kac.enabled=true \
  --set falcon-kac.image.repository=$KAC_DOCKER_REGISTRY \
  --set falcon-kac.image.tag=$KAC_IMAGE_TAG
```

### Upgrade the Falcon Platform Helm Chart Version
```bash
# Update Helm repository
helm repo update

# Update dependent subcharts for falcon-platform
helm dependency update falcon-platform crowdstrike/falcon-platform

# Upgrade Helm chart with existing Helm values
helm upgrade falcon-platform crowdstrike/falcon-platform --version $NEW_FALCON_PLATFORM_VERSION -n falcon-platform \
  --reuse-values
```

### Individual Component Updates
```bash
# Upgrade the version of each Falcon component image
helm upgrade falcon-platform jchoi_cs/falcon-platform --version $FALCON_PLATFORM_VERSION -n falcon-platform \
  --reuse-values \
  --set falcon-sensor.node.image.tag=$FALCON_SENSOR_IMAGE_TAG \
  --set falcon-kac.image.tag=$FALCON_KAC_IMAGE_TAG \
  --set falcon-image-analyzer.image.tag=$FALCON_IAR_IMAGE_TAG
```

**IMPORTANT NOTE:** You cannot control exactly which helm chart version is being used for each individual Falcon component subchart.

Component versions are managed through the falcon-platform chart's [dependencies](./Chart.yaml). The dependent subchart versions are locked.
Update the umbrella chart to get the latest Falcon component helm chart versions for each subchart.

## Uninstall

### Uninstall a Single Component
```bash
# Upgrade your helm release with the component disabled - for example to uninstall falcon-image-analyzer only:
helm upgrade falcon-platform crowdstrike/falcon-platform --version $FALCON_PLATFORM_VERSION -n falcon-platform \
  --reuse-values \
  --set falcon-image-analyzer.enabled=false

# Optionally delete the component namespace
kubectl delete namespace $FALCON_IAR_NAMESPACE
```

### Uninstall the Falcon Platform Helm chart
```bash
# Remove Falcon Platform and all components
helm uninstall falcon-platform

# Optionally delete the release namespace, and the namespace for each Falcon component subchart
kubectl delete namespace $FALCON_PLATFORM_NAMESPACE $FALCON_SENSOR_NAMESPACE $FALCON_KAC_NAMESPACE $FALCON_IAR_NAMESPACE
```
