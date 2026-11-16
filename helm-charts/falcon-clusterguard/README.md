# CrowdStrike Falcon Cluster Guard Helm Chart

[Falcon](https://www.crowdstrike.com/) is the [CrowdStrike](https://www.crowdstrike.com/)
platform purpose-built to stop breaches via a unified set of cloud-delivered technologies
that prevent all types of attacks — including malware and much more.

Falcon Cluster Guard (FCG) is a unified Kubernetes security service that replaces the
separate `falcon-sensor` (node mode), `falcon-kac`, and `falcon-image-analyzer` charts with a
single deployment built around a single container image.

## Table of Contents

- [What is FCG?](#what-is-fcg)
- [Migrating from falcon-sensor and falcon-kac](#migrating-from-falcon-sensor-and-falcon-kac)
- [Kubernetes Cluster Compatibility](#kubernetes-cluster-compatibility)
- [Dependencies](#dependencies)
  - [Helm Chart Support for FCG Versions](#helm-chart-support-for-fcg-versions)
- [Installation](#installation)
- [Image Configuration](#image-configuration)
- [Cluster Name](#cluster-name)
- [Falcon Configuration Options](#falcon-configuration-options)
  - [Per-Component Falcon Options](#per-component-falcon-options)
  - [Using Existing Kubernetes Secrets](#using-existing-kubernetes-secrets)
  - [Secrets Store CSI Driver Integration](#secrets-store-csi-driver-integration)
- [Cloud Provider Configuration](#cloud-provider-configuration)
- [Certificate Management](#certificate-management)
  - [Certificates Used by FCG](#certificates-used-by-fcg)
  - [Certificate Parameters](#certificate-parameters)
  - [Helm-Generated Certificates](#helm-generated-certificates)
  - [Using cert-manager](#using-cert-manager)
- [Node Sensor Configuration](#node-sensor-configuration)
  - [Deployment Considerations](#deployment-considerations)
  - [Sensor Uninstall and Maintenance Protection](#sensor-uninstall-and-maintenance-protection)
  - [Pod Security Standards](#pod-security-standards)
  - [Node Configuration](#node-configuration)
  - [Guardian Local Proxy](#guardian-local-proxy)
    - [Verifying upstream endpoints (TLS)](#verifying-upstream-endpoints-tls)
    - [Custom DNS for the node sensor](#custom-dns-for-the-node-sensor)
  - [GKE Autopilot Configuration](#gke-autopilot-configuration)
- [Cluster Guard Controller Configuration](#cluster-guard-controller-configuration)
  - [Cluster Guard Controller and Admission Control](#cluster-guard-controller-and-admission-control)
  - [Cluster Visibility](#cluster-visibility)
  - [Webhook Configuration](#webhook-configuration)
  - [Resource Limits](#resource-limits)
- [Image Analyzer Configuration](#image-analyzer-configuration)
  - [Enabling Image Analyzer](#enabling-image-analyzer)
  - [DaemonSet Mode](#daemonset-mode)
  - [Image Analyzer Credentials](#image-analyzer-credentials)
  - [Image Analyzer Options](#image-analyzer-options)
- [OpenShift Compatibility](#openshift-compatibility)
- [Uninstall Helm Chart](#uninstall-helm-chart)
- [Troubleshooting](#troubleshooting)
  - [Upgrade Errors](#upgrade-errors)
- [Chart Layout](#chart-layout)

## What is FCG?

FCG replaces the separate `falcon-sensor` (node-only), `falcon-kac`, and `falcon-image-analyzer`
charts with a unified installer built around a single container image. FCG provides:

- **Node-level protection**: eBPF/kernel-based sensor deployed as a DaemonSet on every cluster node
- **Cluster Guard controller**: central gRPC metadata service that supplies Kubernetes context to node sensors, eliminating the scalability bottleneck of each sensor querying the API server directly
- **Admission control**: optional ValidatingWebhookConfiguration that inspects Kubernetes API requests
- **Resource visibility**: periodic snapshots + live event watchers for cluster-wide resource discovery
- **Image assessment** (optional): a Falcon Image Analyzer (IAR) Deployment or DaemonSet that assesses the container images running in the cluster. Disabled by default; see [Image Analyzer Configuration](#image-analyzer-configuration)

> **Note:** FCG does not currently support container sidecar injection. If you need the
> Falcon Container sensor (sidecar mode), continue using the `falcon-sensor` chart with
> `container.enabled=true`.

## Migrating from falcon-sensor and falcon-kac

If you are currently using `falcon-sensor` (node mode), `falcon-kac`, and/or `falcon-image-analyzer`,
use the migration script to generate a new values file:

```bash
# From individual chart values files
python3 scripts/migration/migrate-to-fcg.py \
  --sensor-values my-sensor-values.yaml \
  --kac-values my-kac-values.yaml \
  --iar-values my-iar-values.yaml \
  --fcg-image-repo <fcg-repo> \
  --fcg-image-tag <fcg-tag>

# From a falcon-platform umbrella values file
python3 scripts/migration/migrate-to-fcg.py --platform-values my-platform-values.yaml --fcg-image-repo <fcg-repo> --fcg-image-tag <fcg-tag>

# Interactive guided wizard
python3 scripts/migration/migrate-to-fcg.py --interactive
```

> [!NOTE]
> The script has no default FCG image repository, tag, or digest yet. Pass `--fcg-image-repo`
> and `--fcg-image-tag` (or `--fcg-image-digest`), or enter them when the script prompts.
> Default values will be added once FCG is generally available.

> [!IMPORTANT]
> Helm won't install FCG over objects that belong to another Helm release. If you installed any of
> these charts as their own releases, rather than through `falcon-platform`, deal with them first:
>
> | Standalone release          | Objects shared with FCG                                                                                                                   | What to do                                 |
> |:----------------------------|:------------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------|
> | `falcon-sensor` (node mode) | DaemonSet `falcon-sensor` and ConfigMap `falcon-sensor-config`, if it's in the FCG namespace                                              | Uninstall it. FCG runs the node sensor.    |
> | `falcon-kac`                | ValidatingWebhookConfiguration `validating.falcon-kac.crowdstrike.com` (cluster-wide), and Service `webhook` if it's in the FCG namespace | Uninstall it. FCG runs admission control.  |
> | `falcon-image-analyzer`     | Service `iar-agent-service`, if it's in the FCG namespace                                                                                 | Uninstall it. FCG runs the image analyzer. |
>
> Uninstall these even when nothing is shared, because a second node sensor, admission webhook, or
> image analyzer would run alongside FCG's.
>
> To keep each node's agent ID (AID), so hosts keep their identity in the Falcon console, skip the
> `falcon-sensor` cleanup when you uninstall it. The cleanup DaemonSet removes the sensor from every
> node, including its AID:
>
> ```bash
> helm uninstall <falcon-sensor-release> -n <namespace> --no-hooks
> ```
>
> FCG's node sensor then reuses the AID stored on each node. If you let the cleanup run instead,
> wait until its `*-node-cleanup` pods are gone before you install FCG.
>
> Upgrading `falcon-platform` should not need this step: the FCG subchart replaces the old subcharts'
> objects in the same release. Namespaces labeled `falcon-kac.crowdstrike.com/admission-review=disabled`
> stay excluded from admission control.

See `scripts/migration/README.md` for full documentation.

Key differences from non-fcg charts:

| Behavior                                       | falcon-sensor + falcon-kac + falcon-image-analyzer | falcon-clusterguard                                            |
|:-----------------------------------------------|:---------------------------------------------------|:---------------------------------------------------------------|
| Container images                               | Separate per chart                                 | Single unified image                                           |
| Node sensor                                    | `falcon-sensor` chart                              | `nodeSensor.*` values                                          |
| KAC                                            | `falcon-kac` chart                                 | `clusterguardController.*` values                              |
| `admissionControl.enabled` default             | `true`                                             | **`false`**                                                    |
| Image Analyzer                                 | `falcon-image-analyzer` chart                      | `imageAnalyzer.*` values                                       |
| Container sidecar sensor                       | Supported (`container.enabled=true`)               | Not supported — use `falcon-sensor`                            |
| gRPC metadata service                          | Not available                                      | Built-in (always enabled)                                      |
| Controller Deployment name                     | `falcon-kac` (`<nameOverride>`)                    | `falcon-clusterguard-controller` (`<nameOverride>-controller`) |
| Controller pod `app` label                     | `falcon-kac`                                       | `falcon-clusterguard`                                          |
| Controller `app.kubernetes.io/component` label | `kac`                                              | `clusterguard`                                                 |

## Kubernetes Cluster Compatibility

FCG has been tested on the following Kubernetes distributions:

- Amazon Elastic Kubernetes Service (EKS)
- Azure Kubernetes Service (AKS)
- Google Kubernetes Engine (GKE), including GKE Autopilot
- Rancher K3s

> **OpenShift:** OpenShift is **not a recommended** configuration for this Helm chart. The
> [official Red Hat certified CrowdStrike Falcon Operator](https://catalog.redhat.com/en/software/container-stacks/detail/62f2d38f76d039249424703d)
> is the recommended installation method for OpenShift clusters. A best-effort
> compatibility mode is available (see [OpenShift Compatibility](#openshift-compatibility) below).

## Dependencies

1. Requires an x86_64 or ARM64 Kubernetes cluster
1. Must be a CrowdStrike customer with access to the Falcon Cluster Guard image from the CrowdStrike Container Registry
1. Kubernetes nodes must be Linux distributions supported by CrowdStrike
1. Before deploying, ensure the FCG image is available in a registry accessible to your cluster
1. Helm 3.x is installed and supported by your Kubernetes vendor

### Helm Chart Support for FCG Versions

| Helm Chart Version | FCG Sensor Version | Notes                                    |
|:-------------------|:-------------------|:-----------------------------------------|
| `1.0.0`            | `>= 8.14`          | Initial release for Falcon Cluster Guard |

## Installation

### Add the CrowdStrike Falcon Helm repository

```bash
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
helm repo update
```

### Minimal install (node sensor + clusterguard controller)

```bash
helm upgrade --install falcon-clusterguard crowdstrike/falcon-clusterguard \
  -n falcon-system --create-namespace \
  --set falcon.cid="<CrowdStrike_CID>" \
  --set image.registryConfigJSON="<YOUR_BASE64_ENCODED_DOCKER_CONFIG_JSON>"
```

### Full install (node sensor + clusterguard controller + admission control)

```yaml
# falcon-clusterguard-values.yaml
clusterName: "my-cluster"     # required for self-hosted K8s; auto-discovered on EKS/GKE/AKS

image:
  repository: registry.crowdstrike.com/falcon-clusterguard/release/falcon-clusterguard
  digest: sha256:ffdc91f66ef8570bd7612cf19145563a787f552656f5eec43cd80ef9caca0398
  pullSecret: crowdstrike-pull-secret

falcon:
  cid: "<CrowdStrike_CID>"
  trace: info
  billing: default

nodeSensor:
  enabled: true
  daemonset:
    updateStrategy: RollingUpdate

clusterguardController:
  admissionControl:
    enabled: true             # default is false — set true to enable the webhook
  webhook:
    failurePolicy: Ignore
  visibility:
    resourceSnapshots:
      enabled: true
      interval: 22h
    resourceWatcher:
      enabled: true
```

```bash
helm upgrade --install falcon-clusterguard crowdstrike/falcon-clusterguard \
  -n falcon-system --create-namespace \
  -f falcon-clusterguard-values.yaml
```

For a complete listing of configurable parameters:

```bash
helm show values crowdstrike/falcon-clusterguard
```

## Image Configuration

A single FCG container image is used by both the node sensor DaemonSet and the clusterguard
controller Deployment.

| Parameter                  | Description                                                                                                          |
|:---------------------------|:---------------------------------------------------------------------------------------------------------------------|
| `image.repository`         | FCG container image repository (Default: `registry.crowdstrike.com/falcon-clusterguard/release/falcon-clusterguard`) |
| `image.tag`                | Image tag. Prefer `image.digest` for immutability. (Default: `8.12.0-1102-1`)                                        |
| `image.digest`             | Image digest (`sha256:...`). Overrides `image.tag` when set.                                                         |
| `image.pullPolicy`         | Kubernetes image pull policy (Default: `Always`)                                                                     |
| `image.pullSecret`         | Name of an existing docker-registry Secret                                                                           |
| `image.registryConfigJSON` | Base64-encoded Docker `config.json`. Conflicts with `image.pullSecret`.                                              |

## Cluster Name

FCG usually discovers the cluster name on managed Kubernetes (EKS, GKE, AKS). Set `clusterName` when it
can't be discovered, for example on self-hosted clusters such as MicroK8s. The node sensor, clusterguard
controller, and image analyzer all use this value.

| Parameter     | Description                                  | Default                    |
|:--------------|:---------------------------------------------|:---------------------------|
| `clusterName` | Cluster name reported by every FCG component | None (auto-discovery used) |

## Falcon Configuration Options

The following table lists the Falcon sensor options shared by both the node sensor and
the clusterguard controller. These are passed to `falconctl` as `FALCONCTL_OPT_*` environment
variables in both the node and clusterguard controller ConfigMaps. To set `falcon.trace`,
`falcon.feature`, or `falcon.tags` differently for one of them, see
[Per-Component Falcon Options](#per-component-falcon-options). The image analyzer does not use
these options.

> [!NOTE]
> `falcon.cid` and `falcon.provisioning_token` are handled separately via the
> `falconSecret` mechanism and are not written as plain `FALCONCTL_OPT_*` env vars
> when `falconSecret.enabled=true`.

| Parameter                   | Description                                                                       | Default |
|:----------------------------|:----------------------------------------------------------------------------------|:--------|
| `falcon.cid`                | CrowdStrike Customer ID (CID). Required unless `falconSecret.enabled=true`.       | None    |
| `falcon.cloud`              | CrowdStrike cloud region (`us-1`, `us-2`, `us-3`, `eu-1`, `us-gov-1`, `us-gov-2`) | None    |
| `falcon.apd`                | App Proxy Disable (APD)                                                           | None    |
| `falcon.aph`                | App Proxy Hostname (APH)                                                          | None    |
| `falcon.app`                | App Proxy Port (APP)                                                              | None    |
| `falcon.trace`              | Set trace level (`none`, `err`, `warn`, `info`, `debug`)                          | `none`  |
| `falcon.feature`            | Sensor feature options                                                            | None    |
| `falcon.billing`            | Billing mode (`default` or `metered`)                                             | None    |
| `falcon.tags`               | Comma-separated list of tags for sensor grouping                                  | None    |
| `falcon.provisioning_token` | Provisioning token value. Not supported when `falconSecret.enabled=true`.         | None    |

### Per-Component Falcon Options

`falcon.trace`, `falcon.feature`, and `falcon.tags` apply to both the node sensor and the
clusterguard controller. To change one of them for only one of these, set it under that
component's `falcon` block. A value set there
replaces the shared value for that component only, so per-component `tags` are not added to
`falcon.tags`.

| Parameter                               | Description                                                   | Default          |
|:----------------------------------------|:--------------------------------------------------------------|:-----------------|
| `nodeSensor.falcon.trace`               | Trace level for the node sensor                               | `falcon.trace`   |
| `nodeSensor.falcon.feature`             | Sensor feature options for the node sensor                    | `falcon.feature` |
| `nodeSensor.falcon.tags`                | Comma-separated sensor grouping tags for the node sensor      | `falcon.tags`    |
| `clusterguardController.falcon.trace`   | Trace level for the clusterguard controller                   | `falcon.trace`   |
| `clusterguardController.falcon.feature` | Feature options for the clusterguard controller               | `falcon.feature` |
| `clusterguardController.falcon.tags`    | Comma-separated grouping tags for the clusterguard controller | `falcon.tags`    |

For example, to debug the node sensor while the clusterguard controller keeps the shared trace level:

```yaml
falcon:
  trace: warn
  tags: prod/us-east

nodeSensor:
  falcon:
    trace: debug
```

### Using Existing Kubernetes Secrets

Instead of specifying sensitive values directly in Helm values, you can use an existing
Kubernetes secret to supply the Falcon CID and provisioning token.

The secret must be in the same namespace as the FCG deployment and must contain:
- `FALCONCTL_OPT_CID`: Falcon Customer ID (CID) — required
- `FALCONCTL_OPT_PROVISIONING_TOKEN`: Falcon provisioning token — optional

When the image analyzer is enabled (`imageAnalyzer.enabled=true`), the same secret must also contain
its credentials. Do not set `imageAnalyzer.crowdstrikeConfig.clientID`/`clientSecret` when using an
existing secret.
- `AGENT_CLIENT_ID`: CrowdStrike Falcon OAuth API client ID — required
- `AGENT_CLIENT_SECRET`: CrowdStrike Falcon OAuth API client secret — required
- `AGENT_CID`: Falcon Customer ID (CID) — required

> [!NOTE]
> `falcon.trace` and other `falcon.*` options are **not** sourced from `falconSecret` —
> they must still be set as Helm values. Only `cid` and `provisioning_token` are
> supplied via the secret.

Create the namespace and secret before installing:

```bash
kubectl create namespace falcon-system

kubectl create secret generic $FALCON_SECRET_NAME -n falcon-system \
  --from-literal=FALCONCTL_OPT_CID=$FALCON_CID \
  --from-literal=FALCONCTL_OPT_PROVISIONING_TOKEN=$FALCON_PROVISIONING_TOKEN

# With the image analyzer enabled, add its credentials to the same secret:
#   --from-literal=AGENT_CLIENT_ID=$FALCON_CLIENT_ID \
#   --from-literal=AGENT_CLIENT_SECRET=$FALCON_CLIENT_SECRET \
#   --from-literal=AGENT_CID=$FALCON_CID
```

Then reference the secret during installation:

```bash
helm install falcon-clusterguard crowdstrike/falcon-clusterguard \
  -n falcon-system --create-namespace \
  --set falconSecret.enabled=true \
  --set falconSecret.secretName=$FALCON_SECRET_NAME \
  --set image.repository="<Your_Registry>/falcon-clusterguard"
```

| Parameter                 | Description                                                                                                                                                                                 | Default |
|:--------------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------|
| `falconSecret.enabled`    | Use an existing Kubernetes secret for sensitive Falcon values. Must be `true` when `falcon.cid` is not set.                                                                                 | `false` |
| `falconSecret.secretName` | Name of the secret. Must be in the same namespace as FCG and must contain `FALCONCTL_OPT_CID`, plus `AGENT_CLIENT_ID`, `AGENT_CLIENT_SECRET`, and `AGENT_CID` when `imageAnalyzer.enabled`. | None    |

> [!NOTE]
> When `falconSecret.enabled` is `true`, `falcon.cid` must not be set. These are mutually exclusive.

### Secrets Store CSI Driver Integration

The chart supports sourcing Falcon credentials from external secret stores via the
[Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/). The supported
provider is:
- [Azure Key Vault](https://azure.microsoft.com/en-us/products/key-vault) via the [Azure Key Vault provider](https://azure.github.io/secrets-store-csi-driver-provider-azure/)

A single `secretsStore` block configures every FCG workload. It follows the same conventions as the
standalone `falcon-sensor`, `falcon-kac`, and `falcon-image-analyzer` charts:

- `secretsStore.*` (chart level) overrides `global.secretsStore.*`. `secretsStore.enabled` is unset by
  default, so `global.secretsStore.enabled=true` turns CSI on for FCG. Setting `secretsStore.enabled=false`
  explicitly turns it off even when the global value is `true`.
- Each set of credentials gets its own `SecretProviderClass` and CSI-synced Kubernetes secret, so a pod
  only mounts the secrets it uses:

| Workloads                                       | SecretProviderClass          | Synced Kubernetes secret                                              | Keys                                                               |
|:------------------------------------------------|:-----------------------------|:----------------------------------------------------------------------|:-------------------------------------------------------------------|
| Node sensor DaemonSet, Cluster Guard Controller | `<release-fullname>-csi`     | `secretsStore.secretName`, default `<release-fullname>-csi`           | `FALCONCTL_OPT_CID`, `FALCONCTL_OPT_PROVISIONING_TOKEN` (optional) |
| Image Analyzer (when `imageAnalyzer.enabled`)   | `<name>-iar-csi`             | `<secretsStore.secretName>-iar`, default `<name>-iar-csi`             | `AGENT_CLIENT_ID`, `AGENT_CLIENT_SECRET`, `AGENT_CID`              |

`<release-fullname>` is `<release>-falcon-clusterguard` (or `fullnameOverride`). `<name>` is
`nameOverride`, or `falcon-clusterguard` when it is not set, so image analyzer object names don't
include the release name.

The secrets store volume is mounted at `/mnt/secrets-store` in the node sensor container, the
`falcon-client` container of the clusterguard controller, and the image analyzer container. Every
controller container reads `FALCONCTL_OPT_CID` from the synced secret.

#### Configuration Parameters

| Parameter                                  | Description                                                                                               | Default |
|:-------------------------------------------|:----------------------------------------------------------------------------------------------------------|:--------|
| `secretsStore.enabled`                     | Enable Secrets Store CSI Driver integration. Overrides `global.secretsStore.enabled` when set.            | None    |
| `secretsStore.provider`                    | Secrets Store CSI Driver provider (`azure`). Falls back to `global.secretsStore.provider`.                | `""`    |
| `secretsStore.secretName`                  | Name of the node sensor/controller secret synced by the CSI driver.                                       | `""`    |
| `secretsStore.azure.vaultName`             | Azure Key Vault name. Falls back to `global.secretsStore.azure.vaultName`.                                | `""`    |
| `secretsStore.azure.tenantID`              | Azure Tenant ID. Falls back to `global.secretsStore.azure.tenantID`.                                      | `""`    |
| `secretsStore.azure.clientID`              | Azure Workload Identity client ID. Only required if multiple managed identities are assigned to the node. | `""`    |
| `secretsStore.provisioningTokenSecretName` | Name of the Key Vault secret containing `FALCONCTL_OPT_PROVISIONING_TOKEN`. Leave empty to omit.          | `""`    |

> [!NOTE]
> When the Secrets Store CSI Driver is enabled:
> - It cannot be combined with `falcon.cid`, `global.falcon.cid`, or `falconSecret` / `global.falconSecret`. The
>   CID for every component, including the image analyzer, comes from the `falcon-cid` Key Vault secret.
> - For the image analyzer, it cannot be combined with `imageAnalyzer.crowdstrikeConfig.clientID`/`clientSecret`.

#### Prerequisites

**For Azure Key Vault:**

The following must be installed and configured on your AKS cluster before enabling this feature:

- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/getting-started/installation)
- [Azure Key Vault Provider for Secrets Store CSI Driver](https://azure.github.io/secrets-store-csi-driver-provider-azure/docs/getting-started/installation/)
- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/docs/installation.html) webhook installed on the cluster
- AKS cluster with OIDC issuer enabled (`az aks update --enable-oidc-issuer --name <cluster> --resource-group <rg>`)
- A user-assigned managed identity with `Key Vault Secrets User` role on the vault
- A federated credential binding the managed identity to **each** FCG ServiceAccount that mounts secrets:
  the node sensor (`nodeSensor.serviceAccount.name`), the clusterguard controller (`clusterguardController.serviceAccount.name`),
  and, when enabled, the image analyzer (`imageAnalyzer.serviceAccount.name`, default `falcon-clusterguard-iar`).
  All of them are in the FCG namespace.

#### Required secrets in Azure Key Vault

| Key Vault secret name                        | Used by                              | Required                                  | Value                                      |
|:---------------------------------------------|:-------------------------------------|:------------------------------------------|:-------------------------------------------|
| `falcon-cid`                                 | All components                       | Yes                                       | CrowdStrike Customer ID (CID)              |
| `<secretsStore.provisioningTokenSecretName>` | Node sensor, clusterguard controller | When `provisioningTokenSecretName` is set | Provisioning token                         |
| `falcon-client-id`                           | Image Analyzer                       | When `imageAnalyzer.enabled`              | CrowdStrike Falcon OAuth API client ID     |
| `falcon-client-secret`                       | Image Analyzer                       | When `imageAnalyzer.enabled`              | CrowdStrike Falcon OAuth API client secret |

#### Configuration

**Azure Key Vault example:**

The `secretsStore` block configures the vault connection once. Azure Workload Identity still has to be
enabled per workload, through its ServiceAccount annotation and pod label:

```yaml
secretsStore:
  enabled: true
  provider: azure
  azure:
    vaultName: "my-keyvault"
    tenantID: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    # clientID is optional - only required if multiple managed identities are assigned
    clientID: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  # provisioningTokenSecretName: "falcon-provisioning-token"   # optional

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

imageAnalyzer:            # only when the image analyzer is enabled
  enabled: true
  serviceAccount:
    annotations:
      azure.workload.identity/client-id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  podLabels:
    azure.workload.identity/use: "true"
```

## Cloud Provider Configuration

These settings describe the cluster's platform rather than one component, so they sit at the top
level of the values and apply wherever they are relevant across FCG.

| Parameter                     | Description                                                                                                                                                                                                                                         | Default                      |
|:------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:-----------------------------|
| `gke.enabled`                 | Set on GKE clusters (Standard or Autopilot). Adds `system-node-critical` to the clusterguard ResourceQuota scope and, when the Image Analyzer is enabled, an init container that waits for the GKE metadata server (needed with Workload Identity). | `false`                      |
| `gke.autopilot`               | Set on GKE Autopilot clusters. Applies Autopilot resource defaults to the node sensor DaemonSets and creates their PriorityClass. See [GKE Autopilot Configuration](#gke-autopilot-configuration).                                                  | `false`                      |
| `gke.deployAllowListVersion`  | GKE Autopilot WorkloadAllowlist version for the node sensor DaemonSet, in `vX.Y.Z` form. Required when `gke.autopilot=true`. Adds the `cloud.google.com/matching-allowlist` annotation.                                                             | `""`                         |
| `gke.cleanupAllowListVersion` | GKE Autopilot WorkloadAllowlist version for the node sensor cleanup DaemonSet, in `vX.Y.Z` form. Required when `gke.autopilot=true`.                                                                                                                | `""`                         |
| `azure.enabled`               | Mount the node's Azure config file into the Image Analyzer pod for registry authentication on AKS without a pull token. On OpenShift, the Image Analyzer SCC also allows `hostPath` volumes.                                                        | `false`                      |
| `azure.azureConfig`           | Path to the Azure config file on worker nodes                                                                                                                                                                                                       | `/etc/kubernetes/azure.json` |

```yaml
gke:
  enabled: true
  autopilot: true   # GKE Autopilot only
```

## Certificate Management

FCG uses TLS in three places: the clusterguard controller's admission webhook, mutual TLS (mTLS)
on the gRPC API between the node sensor and the clusterguard controller, and, when enabled, the
Image Analyzer agent service. The chart creates these certificates with Helm (default) or has
cert-manager issue them. Either way they are stored in the same Secrets, so workloads mount them
the same way.

### Certificates Used by FCG

| Secret                                    | Used by                                                     | Purpose                                                 | Created by           |
|:------------------------------------------|:------------------------------------------------------------|:--------------------------------------------------------|:---------------------|
| `falcon-cg-controller-tls`                | Clusterguard controller; admission webhook `caBundle`       | Admission webhook server certificate                    | Helm or cert-manager |
| `falcon-api-ca`                           | Clusterguard controller, node sensor                        | CA certificate for gRPC mTLS between them               | Helm                 |
| `falcon-grpc-ca`                          | cert-manager only (not mounted by any pod)                  | gRPC mTLS CA certificate and private key                | cert-manager         |
| `falcon-api-tls`                          | Clusterguard controller                                     | gRPC API server certificate                             | Helm or cert-manager |
| `falcon-node-sensor-tls`                  | Node sensor                                                 | gRPC client certificate                                 | Helm or cert-manager |
| `falcon-clusterguard-iar-tls`             | Image Analyzer (when `imageAnalyzer.enabled=true`)          | Image Analyzer agent service certificate                | Helm or cert-manager |
| `nodeSensor.guardian.proxy.tlsSecretName` | Node sensor (when `nodeSensor.guardian.proxy.enabled=true`) | Optional CA bundle for verifying upstream TLS endpoints | You (optional)       |

### Certificate Parameters

| Parameter                                             | Description                                                                                                                                                                                  | Default |
|:------------------------------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------|
| `certManager.enabled`                                 | Use cert-manager to issue every FCG certificate instead of Helm-generated self-signed certs. Requires cert-manager, including its cainjector. See [Using cert-manager](#using-cert-manager). | `false` |
| `certManager.issuerRef`                               | cert-manager `Issuer` or `ClusterIssuer` reference. `issuerRef.name` is required when `certManager.enabled=true`.                                                                            | `{}`    |
| `clusterguardController.autoCertificateUpdate`        | Regenerate the admission webhook and gRPC mTLS certificates (controller and node sensor) on each `helm upgrade`. Set to `false` to reuse them. Ignored with cert-manager.                    | `true`  |
| `clusterguardController.certExpiration`               | Validity period in days for the admission webhook and gRPC mTLS certificates                                                                                                                 | `3650`  |
| `clusterguardController.domainName`                   | Custom DNS domain suffix. Also changes the admission webhook certificate's DNS names to `webhook.<namespace>.svc.<domainName>`                                                               | None    |
| `imageAnalyzer.iarAgentService.autoCertificateUpdate` | Regenerate the Image Analyzer certificate on each `helm upgrade`. Set to `false` to reuse it. Ignored with cert-manager.                                                                     | `true`  |
| `imageAnalyzer.iarAgentService.certExpiration`        | Image Analyzer certificate validity period in days                                                                                                                                           | `3650`  |
| `imageAnalyzer.iarAgentService.domainName`            | Custom DNS domain suffix for the Image Analyzer certificate (e.g., `testing.io` if `svc.testing.io` is required)                                                                             | None    |

### Helm-Generated Certificates

By default, Helm generates a self-signed CA and certificates on install, and again on every
`helm upgrade` while `autoCertificateUpdate=true`. The clusterguard controller restarts on upgrade
(`clusterguardController.autoDeploymentUpdate`), so it picks up its new certificates.

Set `autoCertificateUpdate=false` to keep certificates across upgrades. Each set of certificates is
reused only if all of its Secrets still exist; if any of them is missing, that whole set is
regenerated together so certificates always match their CA:

- **Admission webhook** (`clusterguardController.autoCertificateUpdate`): certificate, key, and CA from `falcon-cg-controller-tls`
- **gRPC mTLS** (`clusterguardController.autoCertificateUpdate`): `falcon-api-ca`, `falcon-api-tls`, and `falcon-node-sensor-tls`
- **Image Analyzer** (`imageAnalyzer.iarAgentService.autoCertificateUpdate`): certificate, key, and CA from `falcon-clusterguard-iar-tls` (`<nameOverride>-iar-tls` if you set `nameOverride`)

### Using cert-manager

With `certManager.enabled=true`, the chart creates a cert-manager `Certificate` for each Secret in
[Certificates Used by FCG](#certificates-used-by-fcg) that cert-manager can create. It doesn't create
`falcon-api-ca`, which only Helm uses, or the Guardian proxy CA bundle, which you always provide:

- The admission webhook and Image Analyzer certificates are issued directly by `issuerRef`.
- The gRPC certificates come from a chart-managed CA so the controller and node sensor share one
  trust root. The chart creates a self-signed `ClusterIssuer` (`<release-fullname>-grpc-selfsigned`)
  that issues this CA (`falcon-grpc-ca`), and a namespaced CA `Issuer` (`falcon-grpc-ca-issuer`)
  that signs `falcon-api-tls` and `falcon-node-sensor-tls` with it. The gRPC CA never uses
  `issuerRef`, so it is never a subordinate of your organization's CA.
- The `falcon-grpc-ca` Secret holds the CA private key and is not mounted by any pod. The
  controller and node sensor read the CA certificate from the `ca.crt` key that cert-manager writes
  into their own certificate Secrets (`falcon-api-tls` and `falcon-node-sensor-tls`).
- The `ValidatingWebhookConfiguration` gets its `caBundle` from cert-manager's cainjector
  (`cert-manager.io/inject-ca-from`).

The issuer must be able to sign certificates for in-cluster service names, so use a self-signed or
CA issuer rather than an ACME issuer.

```yaml
certManager:
  enabled: true
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
```

## Node Sensor Configuration

### Deployment Considerations

To ensure a successful deployment:

1. The FCG node sensor runs as a privileged DaemonSet. Best practice is to use a dedicated namespace such as `falcon-system`.
1. You must be a cluster administrator to deploy Helm Charts to the cluster.
1. The Falcon Linux Sensor requires privileged access so that it can properly interact with the kernel. This is a requirement for any kernel module deployed to a container-optimized OS.
1. The FCG node sensor creates `/opt/CrowdStrike` on Kubernetes nodes. **Do not delete this directory.**
1. CrowdStrike's Helm Chart is a project, not a product, released to the community as a way to automate sensor deployment to Kubernetes clusters. The upstream repository is [https://github.com/CrowdStrike/falcon-helm](https://github.com/CrowdStrike/falcon-helm).

### Sensor Uninstall and Maintenance Protection

- **Falcon Node sensor for Linux with sensor version 7.33 and earlier:** We do not recommend enabling the **Uninstall and maintenance protection** policy setting for DaemonSet deployments. This setting can cause operational issues that require manual intervention.
- **Falcon Node sensor for Linux with sensor version 7.34 and later:** DaemonSet deployments do not support the **Uninstall and maintenance protection** policy setting and automatically ignore it.

### Pod Security Standards

Starting with Kubernetes 1.25, Pod Security Standards are enforced. Apply the required `privileged` labels to the install namespace:

```bash
kubectl label --overwrite ns falcon-system \
  pod-security.kubernetes.io/enforce=privileged

# Optionally silence warnings and adjust auditing:
kubectl label --overwrite ns falcon-system \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged
```

In automated testing environments, set `testing.labelNamespace: true` to apply these labels automatically via a pre-install Job. This requires outbound access to `docker.io` and is not suitable for air-gapped or registry-restricted environments.

### Node Configuration

The following table lists the configurable parameters for the FCG node sensor DaemonSet.

| Parameter                                  | Description                                                                                                                  | Default                                          |
|:-------------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------------|
| `nodeSensor.enabled`                       | Enable the node sensor DaemonSet                                                                                             | `true`                                           |
| `nodeSensor.serviceAccount.name`           | Name of the Kubernetes ServiceAccount used by the node sensor DaemonSet and cleanup DaemonSet                                | `falcon-node-sensor-sa`                          |
| `nodeSensor.serviceAccount.annotations`    | Annotations applied to the ServiceAccount (e.g., for IRSA or Workload Identity)                                              | `{}`                                             |
| `nodeSensor.daemonset.annotations`         | Annotations applied to the DaemonSet resource                                                                                | `{}`                                             |
| `nodeSensor.daemonset.labels`              | Additional labels applied to the DaemonSet resource                                                                          | `{}`                                             |
| `nodeSensor.daemonset.podAnnotationKey`    | Annotation key used to control per-pod/per-node sensor injection                                                             | `sensor.falcon-system.crowdstrike.com/injection` |
| `nodeSensor.daemonset.priorityClassCreate` | Create a PriorityClass for the node sensor pods                                                                              | `false`                                          |
| `nodeSensor.daemonset.priorityClassName`   | Assign an existing PriorityClass name to node sensor pods                                                                    | `""`                                             |
| `nodeSensor.daemonset.priorityClassValue`  | Priority value when `priorityClassCreate` is true                                                                            | `1000000000`                                     |
| `nodeSensor.daemonset.tolerations`         | Pod tolerations for node scheduling. Defaults include master, control-plane, and Azure spot nodes.                           | See `values.yaml`                                |
| `nodeSensor.daemonset.nodeAffinity`        | Node affinity rules for the DaemonSet                                                                                        | `{}`                                             |
| `nodeSensor.daemonset.resources`           | CPU and memory resource requests and limits. Minimum: 250m CPU, 512Mi memory. A CPU limit is not recommended, because the sensor is throttled when it reaches it; GKE Autopilot requires one. GKE Autopilot default: 750m CPU, 1.5Gi memory. | None                                             |
| `nodeSensor.daemonset.updateStrategy`      | DaemonSet update strategy                                                                                                    | `RollingUpdate`                                  |
| `nodeSensor.daemonset.maxUnavailable`      | Maximum number of unavailable nodes during a rolling update                                                                  | `1`                                              |
| `nodeSensor.podAnnotations`                | Annotations applied to node sensor pods                                                                                      | `{}`                                             |
| `nodeSensor.podLabels`                     | Additional labels applied to node sensor pods. Note: may affect WorkloadAllowlists on GKE Autopilot.                         | `{}`                                             |
| `nodeSensor.terminationGracePeriod`        | Seconds to wait for node sensor pods to stop gracefully                                                                      | `60`                                             |
| `nodeSensor.hooks.postDelete.enabled`      | Run a cleanup DaemonSet during `helm uninstall` to remove `/opt/CrowdStrike` from all nodes                                  | `true`                                           |
| `nodeSensor.cleanupOnly`                   | Run the cleanup DaemonSet only (skip the main sensor DaemonSet). Requires `nodeSensor.hooks.postDelete.enabled: true`.       | `false`                                          |

GKE and GKE Autopilot settings (`gke.*`) are in [Cloud Provider Configuration](#cloud-provider-configuration).


### Guardian Local Proxy

| Parameter                                 | Description                                                                                         | Default            |
|:------------------------------------------|:----------------------------------------------------------------------------------------------------|:-------------------|
| `nodeSensor.guardian.proxy.enabled`       | Enable the Guardian Local Proxy (`falcon-proxy` Service).                                           | `false`            |
| `nodeSensor.guardian.proxy.port`          | Container port for the proxy (40000–49512). Required when `nodeSensor.guardian.proxy.enabled=true`. | None               |
| `nodeSensor.guardian.proxy.tlsSecretName` | Name of an optional Secret with CA certificate(s) for upstream TLS verification.                    | `falcon-proxy-tls` |
| `nodeSensor.dnsConfig`                    | `dnsConfig` fields appended to the node sensor pod spec                                             | `{}`               |

When `nodeSensor.guardian.proxy.enabled: true`, FCG:

1. Exposes a named `proxy` port (`nodeSensor.guardian.proxy.port`, required) on the sensor container.
2. Creates a `falcon-proxy` Service with `internalTrafficPolicy: Local` so traffic is
   always routed to the proxy pod on the **same node** — no cross-node hops.

```yaml
nodeSensor:
  guardian:
    proxy:
      enabled: true
      port: 48080
```

```bash
helm upgrade --install falcon-clusterguard crowdstrike/falcon-clusterguard \
  -n falcon-system \
  --set nodeSensor.guardian.proxy.enabled=true \
  --set nodeSensor.guardian.proxy.port=48080
```

#### Verifying upstream endpoints (TLS)

If the proxy needs to verify TLS certificates for upstream endpoints, create a Secret
containing the CA bundle and reference it via `nodeSensor.guardian.proxy.tlsSecretName`:

```bash
kubectl create secret generic falcon-proxy-tls \
  -n falcon-system \
  --from-file=ca.crt=/path/to/ca.crt
```

```yaml
nodeSensor:
  guardian:
    proxy:
      enabled: true
      port: 48080
      tlsSecretName: falcon-proxy-tls
```

The Secret is declared `optional: true`, so the pod will start even if the Secret does not
exist — the proxy simply runs without a custom CA bundle.

#### Custom DNS for the node sensor

The node sensor pod runs with `hostNetwork: true`, which forces `dnsPolicy:
ClusterFirstWithHostNet`. This is not configurable. If you need additional DNS search
domains or custom nameservers for the sensor pod, use `nodeSensor.dnsConfig`:

```yaml
nodeSensor:
  dnsConfig:
    nameservers:
      - "10.0.0.53"
    searches:
      - "corp.internal"
    options:
      - name: ndots
        value: "2"
```

### GKE Autopilot Configuration

Running DaemonSet pods with privileged access on GKE Autopilot requires configuring an
AllowlistSynchronizer. This resource applies CrowdStrike-specific WorkloadAllowlists to
your cluster, which the GKE Autopilot validating webhook uses to approve pod deployments
based on their manifest spec and image digests.

Install FCG with `gke.enabled=true` and `gke.autopilot=true`, and set `gke.deployAllowListVersion` /
`gke.cleanupAllowListVersion` to the WorkloadAllowlist versions you use (see
[Cloud Provider Configuration](#cloud-provider-configuration)).

1. Create a file named `allowlist-synchronizer.yaml`:

```yaml
apiVersion: auto.gke.io/v1
kind: AllowlistSynchronizer
metadata:
  name: crowdstrike-synchronizer
spec:
  allowlistPaths:
  - CrowdStrike/falcon-sensor/*
```

2. Apply it to your cluster:

```bash
kubectl apply -f allowlist-synchronizer.yaml
```

3. Confirm the AllowlistSynchronizer is running:

```bash
kubectl get allowlistsynchronizers
```

4. Confirm the WorkloadAllowlists have been fetched:

```bash
kubectl get workloadallowlists
```

Example output:

```
NAME                                                  AGE
crowdstrike-falconsensor-cleanup-allowlist-v1.0.0     7d
crowdstrike-falconsensor-deploy-allowlist-v1.0.1      7d
crowdstrike-falconsensor-falconctl-allowlist-v1.0.0   7d
```

#### WorkloadAllowlist definitions

- `crowdstrike-falconsensor-cleanup-allowlist-vX.X.X`: Authorizes the cleanup DaemonSet
- `crowdstrike-falconsensor-deploy-allowlist-vX.X.X`: Authorizes the sensor DaemonSet
- `crowdstrike-falconsensor-falconctl-allowlist-vX.X.X`: Authorizes the falconctl Job

> [!NOTE]
> Additional information: [https://cloud.google.com/kubernetes-engine/docs/reference/crds/allowlistsynchronizer](https://cloud.google.com/kubernetes-engine/docs/reference/crds/allowlistsynchronizer)

#### Obtaining an authorized image

WorkloadAllowlists validate container images by digest. To view approved digests:

```bash
kubectl get workloadallowlists <crowdstrike-falconsensor-XXXXXXX-allowlist-vX.X.X> \
  -o=jsonpath='{range .containerImageDigests[*].imageDigests[*]}{@}{"\n"}{end}'
```

To copy an image to a private registry while preserving its digest, use a tool like
[Skopeo](https://github.com/containers/skopeo):

```bash
skopeo copy \
  docker://registry.crowdstrike.com/falcon-clusterguard/release/falcon-clusterguard:<TAG> \
  docker://my-registry.company.com/falcon-clusterguard:<TAG>
```

#### Falcon Secret usage with GKE Autopilot

When using `falconSecret` with GKE Autopilot, `falconSecret.secretName` must be
`"falcon-node-sensor-secret"`. Any other secret name is disallowed by GKE Autopilot.

## Cluster Guard Controller Configuration

### Cluster Guard Controller and Admission Control

FCG has two independent feature gates for the clusterguard controller:

- **`clusterguardController.admissionControl.enabled`**: controls only the ValidatingWebhookConfiguration and webhook Service. The clusterguard controller runs in visibility-only mode by default.
- **`imageAnalyzer.enabled`**: deploys the image analyzer alongside the clusterguard controller for image assessment. This is disabled by default. See [Image Analyzer Configuration](#image-analyzer-configuration).

> **Important:** The FCG default for `clusterguardController.admissionControl.enabled` is `false`, whereas
> the old `falcon-kac` default was `true`. If you are migrating from `falcon-kac`, you must
> explicitly set `clusterguardController.admissionControl.enabled=true` to preserve admission control behavior.

| Parameter                                           | Description                                                                                                                                           | Default                       |
|:----------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------|:------------------------------|
| `clusterguardController.admissionControl.enabled`   | Enable the ValidatingWebhookConfiguration and webhook Service.                                                                                        | `false`                       |
| `clusterguardController.serviceAccount.name`        | Name of the Kubernetes ServiceAccount used by the clusterguard controller Deployment                                                                  | `falcon-cg-controller-sa`     |
| `clusterguardController.serviceAccount.annotations` | Annotations applied to the clusterguard controller ServiceAccount (e.g., for IRSA or Workload Identity)                                               | `{}`                          |
| `clusterguardController.resourceQuota.pods`         | Maximum pods allowed by the ResourceQuota scoped to the `system-cluster-critical` PriorityClass (plus `system-node-critical` when `gke.enabled=true`) | `2`                           |
| `clusterguardController.hostNetwork`                | Run clusterguard controller in host network mode. Required when a custom CNI prevents control plane nodes from communicating directly with pods.      | `false`                       |
| `clusterguardController.webhookPort`                | HTTPS port on which the validating webhook backend listens                                                                                            | `4443`                        |
| `clusterguardController.watcherPort`                | HTTP port on which the resource watcher listens (internal)                                                                                            | `4080`                        |
| `clusterguardController.dnsPolicy`                  | Pod DNS policy. Defaults to `ClusterFirstWithHostNet` when `hostNetwork=true`; otherwise follows cluster default.                                     | None                          |
| `clusterguardController.domainName`                 | Custom DNS domain suffix for in-cluster service resolution (e.g., `testing.io` if `svc.testing.io` is required).                                      | None                          |
| `clusterguardController.tlsVersionMinimum`          | Minimum TLS version accepted by the webhook (`TLS1.2` or `TLS1.3`)                                                                                    | None                          |
| `clusterguardController.autoDeploymentUpdate`       | Roll out a new Deployment automatically on `helm upgrade`                                                                                             | `true`                        |
| `clusterguardController.annotations`                | Annotations applied to the clusterguard controller Deployment resource                                                                                | `{}`                          |
| `clusterguardController.labels`                     | Additional labels applied to the clusterguard controller Deployment resource                                                                          | `{}`                          |
| `clusterguardController.podAnnotations`             | Annotations applied to clusterguard controller pods                                                                                                   | `{}`                          |
| `clusterguardController.podLabels`                  | Additional labels applied to clusterguard controller pods                                                                                             | `{}`                          |
| `clusterguardController.tolerations`                | Pod tolerations for node scheduling                                                                                                                   | `[]`                          |
| `clusterguardController.affinity`                   | Pod affinity/anti-affinity rules. Defaults to require `amd64` or `arm64` node architecture.                                                           | `nodeAffinity` (amd64, arm64) |

The clusterguard controller Deployment is named `<nameOverride>-controller`, which is
`falcon-clusterguard-controller` when `nameOverride` is not set.

### Cluster Visibility

Controls how FCG monitors and reports Kubernetes cluster state to CrowdStrike cloud.

| Parameter                                                      | Description                                                                                                                           | Default |
|:---------------------------------------------------------------|:--------------------------------------------------------------------------------------------------------------------------------------|:--------|
| `clusterguardController.visibility.resourceSnapshots.enabled`  | Periodic snapshots of Kubernetes resources. Disabling may cause long-lived resources to disappear from Falcon UI after ~7 days.       | `true`  |
| `clusterguardController.visibility.resourceSnapshots.interval` | Interval between snapshots. Maximum `22h`, minimum `30m`. Format: `HHhMMm` (e.g., `12h`, `45m`, `1h30m`).                             | `22h`   |
| `clusterguardController.visibility.resourceWatcher.enabled`    | Continuously watch cluster for resource create/update/delete events. Disabling means Falcon UI reflects only the last snapshot state. | `true`  |
| `clusterguardController.visibility.resourceConfigMap.enabled`  | Watch ConfigMap events. FCG redacts known sensitive patterns before sending. Set to `false` to exclude ConfigMaps from visibility.    | `true`  |

### Webhook Configuration

| Parameter                                          | Description                                                                                              | Default  |
|:---------------------------------------------------|:---------------------------------------------------------------------------------------------------------|:---------|
| `clusterguardController.webhook.failurePolicy`     | Webhook failure policy (`Ignore` or `Fail`). `Ignore` allows workloads to proceed if FCG is unavailable. | `Ignore` |
| `clusterguardController.webhook.disableNamespaces` | Comma-separated list of namespaces excluded from webhook validation (e.g., `test1,test2`)                | None     |

### Resource Limits

CPU and memory resource requests and limits for each clusterguard controller container.

| Parameter                                                              | Description                                                           | Default |
|:-----------------------------------------------------------------------|:----------------------------------------------------------------------|:--------|
| `clusterguardController.resources.client.requests.cpu`                 | CPU request for the `falcon-client` (webhook receiver) container      | `250m`  |
| `clusterguardController.resources.client.requests.memory`              | Memory request for the `falcon-client` container                      | `384Mi` |
| `clusterguardController.resources.client.limits.memory`                | Memory limit for the `falcon-client` container                        | `384Mi` |
| `clusterguardController.resources.clientNoWebhook.requests.cpu`        | CPU request for `falcon-client` when admission control is disabled    | `100m`  |
| `clusterguardController.resources.clientNoWebhook.requests.memory`     | Memory request for `falcon-client` when admission control is disabled | `128Mi` |
| `clusterguardController.resources.clientNoWebhook.limits.memory`       | Memory limit for `falcon-client` when admission control is disabled   | `128Mi` |
| `clusterguardController.resources.watcher.requests.cpu`                | CPU request for the `falcon-watcher` (K8s event streamer) container   | `250m`  |
| `clusterguardController.resources.watcher.requests.memory`             | Memory request for the `falcon-watcher` container                     | `512Mi` |
| `clusterguardController.resources.watcher.limits.memory`               | Memory limit for the `falcon-watcher` container                       | `512Mi` |
| `clusterguardController.resources.admissionController.requests.cpu`    | CPU request for the `falcon-ac` (admission controller) container      | `100m`  |
| `clusterguardController.resources.admissionController.requests.memory` | Memory request for the `falcon-ac` container                          | `256Mi` |
| `clusterguardController.resources.admissionController.limits.memory`   | Memory limit for the `falcon-ac` container                            | `256Mi` |

## Image Analyzer Configuration

FCG can optionally deploy the Falcon Image Analyzer (IAR) to assess the container images
running in your cluster. IAR is installed in the same namespace as the rest of FCG.

When `imageAnalyzer.enabled=true`, the chart creates:

- A `falcon-clusterguard-iar` Deployment or DaemonSet (see `imageAnalyzer.mode`), ServiceAccount, ConfigMap, ClusterRole, and ClusterRoleBinding (read access to pods, secrets, services, namespaces, and nodes)
- An `iar-agent-service` Service (port `443` → `imageAnalyzer.iarAgentService.httpPort`) and a `falcon-clusterguard-iar-tls` Secret with a Helm-generated (or cert-manager) certificate
- A credentials Secret, image pull Secret, `SecretProviderClass`, or OpenShift SCC, depending on configuration

These names use `nameOverride` in place of `falcon-clusterguard` when it is set (for example
`<nameOverride>-iar`). They don't include the release name.

IAR runs in one of two modes:

| `imageAnalyzer.mode`   | Workload   | How images are assessed                                                                          | Privileges                                                                                        |
|:-----------------------|:-----------|:-------------------------------------------------------------------------------------------------|:--------------------------------------------------------------------------------------------------|
| `deployment` (default) | Deployment | Watcher mode: discovers running images through the Kubernetes API and pulls them from registries | Root (UID 0), privilege escalation disabled, all capabilities dropped                             |
| `daemonset`            | DaemonSet  | Socket mode: reads images directly from the container runtime socket on each node                | Privileged, with the runtime socket mounted from the host (see [DaemonSet Mode](#daemonset-mode)) |

The `privileged` Pod Security Standards label that the node sensor already requires on the FCG
namespace also covers IAR in both modes (see [Pod Security Standards](#pod-security-standards)).

### Enabling Image Analyzer

```yaml
# falcon-clusterguard-values.yaml
falcon:
  cid: "<CrowdStrike_CID>"

image:
  repository: registry.crowdstrike.com/falcon-clusterguard/release/falcon-clusterguard
  digest: sha256:<FCG_IMAGE_DIGEST>

imageAnalyzer:
  enabled: true
  crowdstrikeConfig:
    clientID: "<FALCON_API_CLIENT_ID>"
    clientSecret: "<FALCON_API_CLIENT_SECRET>"
    agentRegion: us-1
```

```bash
helm upgrade --install falcon-clusterguard crowdstrike/falcon-clusterguard \
  -n falcon-system --create-namespace \
  -f falcon-clusterguard-values.yaml
```

### DaemonSet Mode

Set `imageAnalyzer.mode=daemonset` to run IAR on every node in socket mode. Instead of pulling
images from registries, each pod reads them from the node's container runtime, so it also
assesses images that are only present on the node. `crowdstrikeConfig.agentRuntime` is required:

```yaml
imageAnalyzer:
  enabled: true
  mode: daemonset
  crowdstrikeConfig:
    clientID: "<FALCON_API_CLIENT_ID>"
    clientSecret: "<FALCON_API_CLIENT_SECRET>"
    agentRuntime: containerd        # docker, containerd, crio, or podman
    # agentRuntimeSocket: unix:///run/k3s/containerd/containerd.sock   # only for non-standard paths
```

The chart mounts the runtime socket from the host. It defaults to the standard path for
`agentRuntime`: `/run/docker.sock`, `/run/containerd/containerd.sock`, `/run/crio/crio.sock`, or
`/run/podman/podman.sock`. Set `agentRuntimeSocket` if your nodes use a different path. For
CRI-O, the chart also mounts the node's container storage (`/run/containers/storage`,
`/var/lib/containers`), `/etc/containers`, and `/usr/bin/fuse-overlayfs`.

Reading the runtime socket requires a privileged container. `imageAnalyzer.securityContext`
supports `privileged`, `allowPrivilegeEscalation`, `runAsUser`, and `runAsGroup`; any of these not
set default to `true`, `true`, `0`, and `0`. Explicit values, including `false`, take precedence.
Other keys are ignored.

### Image Analyzer Credentials

IAR authenticates to the CrowdStrike API with an OAuth client ID and secret, in addition to
the CID. All three must come from **one** source. The chart validates at install time that exactly
one source is configured and rejects any mix, such as a CID in Helm values with the client
credentials in a secret.

| Source                     | Client ID / client secret                                                                                | CID                                   |
|:---------------------------|:---------------------------------------------------------------------------------------------------------|:--------------------------------------|
| Helm values                | `imageAnalyzer.crowdstrikeConfig.clientID` / `clientSecret`                                              | `falcon.cid` (or `global.falcon.cid`) |
| Existing Kubernetes secret | `AGENT_CLIENT_ID` / `AGENT_CLIENT_SECRET` keys in the `falconSecret` secret (or `global.falconSecret`)   | `AGENT_CID` key in the same secret    |
| Secrets Store CSI Driver   | `falcon-client-id` / `falcon-client-secret` in the store (chart-level `secretsStore.*` block, see below) | `falcon-cid` in the store             |

With Helm values, the chart creates a `falcon-clusterguard-iar` Secret containing all three keys.
The existing-secret option uses the same `falconSecret` as the node sensor and clusterguard
controller (see [Using Existing Kubernetes Secrets](#using-existing-kubernetes-secrets)). The
secret is loaded into every FCG workload with `envFrom`, so the node sensor and controller pods
also receive the `AGENT_*` keys. The Secrets Store CSI Driver keeps the image analyzer credentials
in their own synced secret.

| Parameter                                        | Description                                                                                                                                                                                           | Default |
|:-------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------|
| `imageAnalyzer.crowdstrikeConfig.clientID`       | CrowdStrike Falcon OAuth API client ID. Must be provided together with `clientSecret` and `falcon.cid`. Must be empty when using `falconSecret` or `secretsStore`.                                    | `""`    |
| `imageAnalyzer.crowdstrikeConfig.clientSecret`   | CrowdStrike Falcon OAuth API client secret. Must be provided together with `clientID` and `falcon.cid`. Must be empty when using `falconSecret` or `secretsStore`.                                    | `""`    |

#### Image Analyzer Secrets Store CSI Driver Integration

The image analyzer uses the same chart-level `secretsStore` block as the node sensor and clusterguard
controller. There is no separate `imageAnalyzer.secretsStore` block. See
[Secrets Store CSI Driver Integration](#secrets-store-csi-driver-integration) for the parameters,
prerequisites, and an example.

When `secretsStore` is enabled and `imageAnalyzer.enabled=true`, the chart creates a separate
`falcon-clusterguard-iar-csi` SecretProviderClass. It syncs these Key Vault secrets into the
`falcon-clusterguard-iar-csi` Kubernetes secret, or `<secretsStore.secretName>-iar` when a name is set:

| Key Vault secret name  | Synced key            | Value                                      |
|:-----------------------|:----------------------|:-------------------------------------------|
| `falcon-client-id`     | `AGENT_CLIENT_ID`     | CrowdStrike Falcon OAuth API client ID     |
| `falcon-client-secret` | `AGENT_CLIENT_SECRET` | CrowdStrike Falcon OAuth API client secret |
| `falcon-cid`           | `AGENT_CID`           | CrowdStrike Customer ID (CID)              |

The API client credentials are only synced into the image analyzer's own secret and are only mounted by
the image analyzer pod. They are never mounted by the node sensor or clusterguard controller.

### Image Analyzer Options

| Parameter                                                 | Description                                                                                                                                 | Default                                           |
|:----------------------------------------------------------|:--------------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------       |
| `imageAnalyzer.enabled`                                   | Deploy the image analyzer                                                                                                                   | `false`                                           |
| `imageAnalyzer.mode`                                      | Workload type: `deployment` (watcher mode) or `daemonset` (socket mode, privileged). See [DaemonSet Mode](#daemonset-mode).                 | `deployment`                                      |
| `imageAnalyzer.serviceAccount.name`                       | IAR ServiceAccount name                                                                                                                     | `falcon-clusterguard-iar`                         |
| `imageAnalyzer.serviceAccount.annotations`                | Annotations applied to the IAR ServiceAccount (e.g., for IRSA or Workload Identity)                                                         | `{}`                                              |
| `imageAnalyzer.crowdstrikeConfig.agentRegion`             | CrowdStrike API region (`us-1`, `us-2`, `eu-1`, `gov1`, `gov2`), or `autodiscovery`                                                         | `autodiscovery`                                   |
| `imageAnalyzer.crowdstrikeConfig.agentMaxConsumerThreads` | Maximum number of image-processing consumer threads                                                                                         | `"1"`                                             |
| `imageAnalyzer.crowdstrikeConfig.agentRuntime`            | DaemonSet mode only, required. Node container runtime: `docker`, `containerd`, `crio`, or `podman`.                                         | `""`                                              |
| `imageAnalyzer.crowdstrikeConfig.agentRuntimeSocket`      | DaemonSet mode only. Runtime socket, e.g. `unix:///run/containerd/containerd.sock`. Defaults to the standard socket for `agentRuntime`.     | `""`                                              |
| `imageAnalyzer.crowdstrikeConfig.enableKlogs`             | Enable Kubernetes client (klog) logging. Use only for troubleshooting.                                                                      | `"false"`                                         |
| `imageAnalyzer.log.output`                                | Log output stream: `1` = stdout, `2` = stderr                                                                                               | `2`                                               |
| `imageAnalyzer.log.verbosity`                             | Log verbosity (`info`, `debug`, `warn`, `error`)                                                                                            | `info`                                            |
| `imageAnalyzer.watcher.listPageSize`                      | Page size used when listing pods in watcher mode                                                                                            | `500`                                             |
| `imageAnalyzer.privateRegistries.credentials`             | Comma-separated `namespace:secretname` list of docker-registry secrets for private registries. Ignored when `autoDiscoverCredentials=true`. | `""`                                              |
| `imageAnalyzer.privateRegistries.autoDiscoverCredentials` | Discover docker-registry secrets in all namespaces at startup. Secrets added later require an IAR restart.                                  | `true`                                            |
| `imageAnalyzer.exclusions.namespace`                      | Comma-separated list of namespaces to exclude from image assessment                                                                         | `""`                                              |
| `imageAnalyzer.exclusions.registry`                       | Comma-separated list of registries (without `http(s)://`) to exclude                                                                        | `""`                                              |
| `imageAnalyzer.exclusions.imageName`                      | Comma-separated list of fully qualified image names to exclude                                                                              | `""`                                              |
| `imageAnalyzer.iarAgentService.httpPort`                  | Container port for the IAR agent service                                                                                                    | `8001`                                            |
| `imageAnalyzer.volumes`                                   | Pod volumes. Must include the `tmp-volume` emptyDir used as image working space; size it to your largest image.                             | `tmp-volume` emptyDir, `sizeLimit: 20Gi`          |
| `imageAnalyzer.volumeMounts`                              | Container volume mounts                                                                                                                     | `tmp-volume` at `/tmp`                            |
| `imageAnalyzer.hostNetwork`                               | Run IAR on the host network. Sets `dnsPolicy: ClusterFirstWithHostNet` unless `imageAnalyzer.dnsPolicy` is set.                             | `false`                                           |
| `imageAnalyzer.dnsPolicy`                                 | Pod DNS policy                                                                                                                              | None                                              |
| `imageAnalyzer.podAnnotations`                            | Annotations applied to IAR pods                                                                                                             | `{}`                                              |
| `imageAnalyzer.podLabels`                                 | Additional labels applied to IAR pods                                                                                                       | `{}`                                              |
| `imageAnalyzer.podSecurityContext`                        | Pod-level security context                                                                                                                  | `{}`                                              |
| `imageAnalyzer.securityContext`                           | DaemonSet mode only. `privileged`, `allowPrivilegeEscalation`, `runAsUser`, `runAsGroup`; unset keys default to privileged root.            | `{}`                                              |
| `imageAnalyzer.resources`                                 | CPU and memory requests and limits. No CPU limit is set by default. In daemonset mode these apply to the pod on every node.                 | requests 500m CPU / 1Gi memory, limits 8Gi memory |
| `imageAnalyzer.nodeSelector`                              | Node selector for IAR pods                                                                                                                  | `{}`                                              |
| `imageAnalyzer.tolerations`                               | Pod tolerations                                                                                                                             | `[]`                                              |
| `imageAnalyzer.affinity`                                  | Pod affinity rules. Defaults to require Linux nodes.                                                                                        | `nodeAffinity` (`kubernetes.io/os: linux`)        |
| `imageAnalyzer.priorityClassName`                         | PriorityClass for IAR pods                                                                                                                  | `""`                                              |
| `imageAnalyzer.proxyConfig.HTTP_PROXY`                    | HTTP proxy for IAR outbound traffic                                                                                                         | `""`                                              |
| `imageAnalyzer.proxyConfig.HTTPS_PROXY`                   | HTTPS proxy for IAR outbound traffic                                                                                                        | `""`                                              |
| `imageAnalyzer.proxyConfig.NO_PROXY`                      | Comma-separated list of hosts that bypass the proxy                                                                                         | `""`                                              |

The Image Analyzer TLS certificate settings (`imageAnalyzer.iarAgentService.autoCertificateUpdate`,
`certExpiration`, and `domainName`) are documented in [Certificate Management](#certificate-management).
AKS registry authentication (`azure.*`) and the GKE metadata-server init container (`gke.enabled`) are in
[Cloud Provider Configuration](#cloud-provider-configuration).

## OpenShift Compatibility

> **Note:** OpenShift is **not a recommended** configuration for this Helm chart. The
> [official Red Hat certified CrowdStrike Falcon Operator](https://catalog.redhat.com/en/software/container-stacks/detail/62f2d38f76d039249424703d)
> is the recommended installation method for OpenShift clusters.

This chart provides a best-effort compatibility mode for deploying FCG on OpenShift clusters.

### Security Context Constraints

OpenShift uses Security Context Constraints (SCC) to control pod privileges. FCG uses up to
three separate SCCs:

- **Node sensor SCC**: grants privileged host access (`hostPID`, `hostIPC`, `hostNetwork`,
  and a privileged container) required by the node DaemonSet
- **Cluster Guard Controller SCC**: grants host network access required by the clusterguard controller when
  `clusterguardController.hostNetwork=true`
- **Image Analyzer SCC**: allows the IAR Deployment to run as root (UID 0) when
  `imageAnalyzer.enabled=true`. No host access is granted unless `imageAnalyzer.hostNetwork` or `azure.enabled`
  is set. With `imageAnalyzer.mode=daemonset`, it also allows privileged containers, privilege
  escalation, and `hostPath` volumes for the runtime socket.

When `openshift.enabled=true` and `openshift.createSCC=true`, the chart creates the SCCs
that apply and binds them to the appropriate service accounts automatically.

**Helm User Permissions:** When `openshift.createSCC: true`, the user or service account
running Helm must have permission to create, update, and delete `SecurityContextConstraints`
resources at the cluster level.

To use existing SCCs instead, set `openshift.createSCC=false` and provide names via
`openshift.nodeSCCName`, `openshift.cgControllerSCCName`, and (for IAR) `openshift.iarSCCName`.
The SCCs must be created and bound to the service accounts before installing.

OpenShift runs Pod Security Admission in warn/audit mode alongside SCCs. To suppress PSA warnings:

```bash
kubectl label namespace falcon-system \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/audit=privileged
```

### OpenShift Values

| Parameter                       | Description                                                                             | Default               |
|:--------------------------------|:----------------------------------------------------------------------------------------|:----------------------|
| `openshift.enabled`             | Enable OpenShift compatibility mode                                                     | `false`               |
| `openshift.createSCC`           | Create SCCs for all FCG components, and bind them to their respective service accounts. | `true`                |
| `openshift.nodeSCCName`         | Name of the node sensor SCC. Defaults to `<release-fullname>-node-sensor`               | `""` (auto-generated) |
| `openshift.cgControllerSCCName` | Name of the clusterguard controller SCC. Defaults to `<release-fullname>-cg-controller` | `""` (auto-generated) |
| `openshift.iarSCCName`          | Name of the image analyzer SCC. Defaults to `falcon-clusterguard-iar`                   | `""` (auto-generated) |

### Installing on OpenShift

```bash
helm upgrade --install falcon-clusterguard crowdstrike/falcon-clusterguard \
  -n falcon-system --create-namespace \
  --set falcon.cid="<CrowdStrike_CID>" \
  --set image.repository="<Your_Registry>/falcon-clusterguard" \
  --set image.tag="<FCG_VERSION>" \
  --set openshift.enabled=true
```

## Uninstall Helm Chart

```bash
helm uninstall falcon-clusterguard -n falcon-system
```

You may also want to delete the namespace:

```bash
kubectl delete ns falcon-system
```

## Troubleshooting

### Node Sensor Cleanup DaemonSet Fails

After uninstall, the cleanup DaemonSet removes `/opt/CrowdStrike` from all nodes. If it fails,
you can run the cleanup manually:

```bash
helm install falcon-clusterguard crowdstrike/falcon-clusterguard \
  -n falcon-system \
  --set image.repository="<Your_Registry>/falcon-clusterguard" \
  --set image.tag="<FCG_VERSION>" \
  --set nodeSensor.enabled=true \
  --set nodeSensor.cleanupOnly=true
```

Validate removal:

```bash
for node in $(kubectl get nodes -o name); do
  echo -n "$node: "
  kubectl debug $node -it --image=busybox -- /bin/sh -c \
    'if test -d /opt/CrowdStrike; then echo "CrowdStrike directory still exists"; else echo "CrowdStrike directory successfully deleted"; fi'
done
```

Then uninstall the cleanup release:

```bash
helm uninstall falcon-clusterguard -n falcon-system
```

### Admission Webhook Not Receiving Requests

Ensure `clusterguardController.admissionControl.enabled=true`. The clusterguard controller Deployment can run
without a webhook (visibility-only mode) — the webhook is disabled by default.

Check that the ValidatingWebhookConfiguration exists:

```bash
kubectl get validatingwebhookconfiguration | grep falcon
```

If it is missing, upgrade with `clusterguardController.admissionControl.enabled=true`.

### Image Analyzer Not Starting

Credential problems are reported at install time. `helm install` fails with an
`IAR credential validation failed` message that lists the missing values. If the
install succeeds but the pod does not become ready, check its status and logs:

```bash
kubectl get pods -n falcon-system -l app=falcon-image-analyzer
kubectl logs -n falcon-system -l app=falcon-image-analyzer --tail=100
```

Common causes:

- Pod rejected by Pod Security Admission: IAR runs as root, so the namespace needs the `privileged` (or at least `baseline`) enforcement label.
- Authentication errors in the logs: verify the API client credentials and `imageAnalyzer.crowdstrikeConfig.agentRegion`.
- DaemonSet pods stuck in `ContainerCreating` with a `hostPath type check failed` event: the runtime socket is not at the expected path. Check `crowdstrikeConfig.agentRuntime`, or set `crowdstrikeConfig.agentRuntimeSocket` to the socket on your nodes.

### Upgrade Errors

#### `spec.selector: Invalid value: ... field is immutable`

```text
Error: UPGRADE FAILED: ... DaemonSet.apps "falcon-sensor" is invalid: spec.selector: Invalid value: {...}: field is immutable
```

The release already has a DaemonSet with the same name but different selector labels. Kubernetes
doesn't allow a workload's selector to change after it is created. FCG uses the same node sensor
selector labels as the `falcon-sensor` chart, so when a `falcon-platform` release already has a
`falcon-sensor` node DaemonSet with the same name, the upgrade updates it in place. You can still see
this error if:

- The old DaemonSet was created by a pre-release FCG build, which used different selector labels.
- Your old `falcon-sensor` values set `nameOverride`, and your FCG values set a different one (or none).

`--force-replace`, `--server-side --force-conflicts`, and `--take-ownership` don't fix this error.
They change how Helm writes the object, but the API server still rejects the new selector. Delete the
DaemonSet, then run the upgrade again:

```bash
kubectl delete daemonset falcon-sensor -n falcon-system
helm upgrade <release> <chart> -n <release-namespace> -f <values-file>
```

Nodes aren't protected between the delete and the new pods starting, so run the upgrade right away.
Each node keeps its agent ID (AID), because the sensor stores it on the node and the cleanup
DaemonSet only runs on `helm uninstall`. Don't delete with `--cascade=orphan`: the new DaemonSet
doesn't adopt the old pods, so each node would run two node sensors.

#### `exists and cannot be imported into the current release`

```text
Error: UPGRADE FAILED: Unable to continue with update: Secret "falcon-cg-controller-tls" in namespace "falcon-system" exists and cannot be imported into the current release: invalid ownership metadata
```

Helm won't create an object that already exists unless the object belongs to the same release.
Common causes:

- **A standalone `falcon-sensor`, `falcon-kac`, or `falcon-image-analyzer` release owns the object.**
  Uninstall it first. See [Migrating from falcon-sensor and falcon-kac](#migrating-from-falcon-sensor-and-falcon-kac).
- **You set `certManager.enabled=false` after using cert-manager.** cert-manager created the
  certificate Secrets, so Helm doesn't own them. Delete the `Certificate` objects first, so
  cert-manager doesn't recreate the Secrets, then delete the Secrets and upgrade. Helm generates new
  certificates, and the clusterguard controller restarts to pick them up:

  ```bash
  NS=falcon-system
  kubectl delete certificate -n $NS -l app.kubernetes.io/instance=<release>
  kubectl delete secret -n $NS falcon-cg-controller-tls falcon-api-tls falcon-node-sensor-tls falcon-grpc-ca falcon-clusterguard-iar-tls
  helm upgrade <release> <chart> -n <release-namespace> -f <values-file>
  ```

  Turning cert-manager on doesn't need these steps. Helm removes the Secrets it generated, and
  cert-manager issues new ones. Pods that start before cert-manager has issued their certificates
  wait in `ContainerCreating` until it does.

#### `Apply failed with N conflicts: conflict with "<manager>"`

Helm 4 upgrades with server-side apply. This error means a field Helm sets was last changed by
another tool, for example `kubectl edit`, `kubectl set image`, or `kubectl scale`. To let Helm take
the fields back, add `--force-conflicts`:

```bash
helm upgrade <release> <chart> -n <release-namespace> -f <values-file> --server-side=true --force-conflicts
```

To keep a manual change, set it in your values file instead, so the next upgrade doesn't revert it.

## Chart Layout

Templates are grouped by component under `templates/`:

| Directory                   | Contents                                                                                                     |
|:----------------------------|:-------------------------------------------------------------------------------------------------------------|
| `templates/`                | Resources used by more than one component (image pull Secret, `SecretProviderClass`) and chart-wide validation |
| `templates/node-sensor/`    | Node sensor DaemonSet, ConfigMap, RBAC, SCC, PriorityClass, Guardian proxy Service, and post-delete cleanup  |
| `templates/cg-controller/`  | Cluster Guard controller Deployment, webhook configuration, ConfigMap, RBAC, SCC, ResourceQuota, Services, and certificates |
| `templates/image-analyzer/` | Image Analyzer Deployment or DaemonSet and supporting resources, plus `_helpers.tpl` and `_pod.tpl`          |
| `templates/tests/`          | `helm test` hooks                                                                                            |

Shared helpers live in `templates/_helpers.tpl`. Templates that compute a checksum of another
template must use its full path under `templates/`, for example
`include (print $.Template.BasePath "/node-sensor/configmap.yaml") .`.
