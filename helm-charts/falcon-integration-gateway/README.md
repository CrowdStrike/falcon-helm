# Helm Chart - Falcon Integration Gateway

[Falcon Integration Gateway](https://github.com/CrowdStrike/falcon-integration-gateway) (FIG) forwards threat detection findings from CrowdStrike Falcon platform to the [backend](https://github.com/CrowdStrike/falcon-integration-gateway/tree/main/fig/backends) of your choice. Consult the project page to learn more about its capabilities. This document describes a helm chart that can be used to deploy the FIG in various configurations.

# Dependencies

1. Requires a Kubernetes cluster
1. Helm 3.x is installed and supported by the Kubernetes vendor.
1. Must be a CrowdStrike customer
1. At least one [backend](https://github.com/CrowdStrike/falcon-integration-gateway/tree/main/fig/backends) prepared to ingest events

# Configuration Options

The following tables lists the Falcon Sensor configurable parameters and their default values.

| Parameter                                              | Description                                            | Default                    |
| :----------------------------------------------------- | :----------------------------------------------------- | :------------------------- |
| `falcon.client_id`                                     | CrowdStrike API Client ID                              | None       (Required)      |
| `falcon.client_secret`                                 | CrowdStrike API Client Secret                          | None       (Required)      |
| `falcon.cloud_region`                                  | CrowdStrike Cloud Region (us-1, us-2, eu-1, us-gov-1)  | None       (Required)      |
| `falcon.integration_gateway.application_id`            | Unique string for each FIG instance within your CID    | helm-chart-default         |
| `falcon.integration_gateway.level`                     | Logging level (ERROR, WARN, INFO, DEBUG)               | INFO                       |
| `falcon.integration_gateway.severity_threshold`        | Filter events based on severity (1-5)                  | 2                          |
| `falcon.integration_gateway.older_than_days_threshold` | Filter events based on age in days                     | 14                         |
| `falcon.integration_gateway.worker_threads`            | Number of FIG application threads to process events    | 4                          |
| `push.aws_security_hub.enabled`                        | Enable event forwarding to AWS Security Hub            | `false`                    |
| `push.aws_security_hub.region`                         | AWS Region                                             | None                       |
| `push.azure_log_analytics.enabled`                     | Enable event forwarding to Azure Log Analytics         | `false`                    |
| `push.azure_log_analytics.workspace_id`                |                                                        | None                       |
| `push.azure_log_analytics.primary_key`                 |                                                        | None                       |
| `push.chronicle.enabled`                               | Enable event forwarding to Google Chronicle            | `false`                    |
| `push.chronicle.region`                                |                                                        | None                       |
| `push.chronicle.security_key`                          |                                                        | None                       |
| `push.gcp_security_command_center.enabled`             | Enable event forwarding to GCP Security Command Center | `false`                    |
| `push.vmware_workspace_one.enabled`                    | Enable event forwarding to VMware Workspace ONE        | `false`                    |
| `push.vmware_workspace_one.syslog_host`                |                                                        | None                       |
| `push.vmware_workspace_one.syslog_port`                |                                                        | None                       |
| `push.vmware_workspace_one.token`                      |                                                        | None                       |
| `serviceAccount.annotations`                           | Annotations for serviceAccount                         | `{}`                       |


## Installation

### Pre-requsites

 - Obtain OAuth2 API credentials for CrowdStrike Falcon
   - Navigate to [API Clients and Keys](https://falcon.crowdstrike.com/support/api-clients-and-keys) within CrowdStrike Falcon platform.
   - Use *Add new API client* button in the top right corner to create a new key pair
   - Make sure only the following permissions are assigned to the key pair:
     - Event streams: READ
     - Hosts: READ

### Installation

The helm chart is under active development. Contributors are welcomed to install either directly from the git repository or from the helm repository.

#### Installation from Helm Repository

1. Add the CrowdStrike Falcon Helm repository
   ```
   helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
   ```
1. Update the local Helm repository Cache
   ```
   helm repo update
   ```
1. Exmaple install with Azure Log Analytics enabled:
   ```
   helm upgrade --install falcon-fig crowdstrike/falcon-integration-gateway -n falcon-integration-gateway --create-namespace \
        --set falcon.client_id=$FALCON_CLIENT_ID \
        --set falcon.client_secret=$FALCON_CLIENT_SECRET \
        --set falcon.cloud_region=$FALCON_CLOUD \
        --set push.azure_log_analytics.enabled=true \
        --set push.azure_log_analytics.workspace_id=1234ab-cdef-abc7d-acdb-82321223 \
        --set push.azure_log_analytics.primary_key=ASDFzxy/vgC/m6HKOY6bqi5g==
   ```

1. Alternative example install with AWS Security Hub enabled:
   ```
   helm upgrade --install falcon-fig crowdstrike/falcon-integration-gateway -n falcon-integration-gateway --create-namespace \
        --set falcon.client_id=$FALCON_CLIENT_ID \
        --set falcon.client_secret=$FALCON_CLIENT_SECRET \
        --set falcon.cloud_region=$FALCON_CLOUD \
        --set push.aws_security_hub.enabled=true \
        --set push.aws_security_hub.region="eu-west-2" \
        --set serviceAccount.annotations."eks.amazonaws.com/role-arn"="arn:aws:iam::12345678910:role/fig-demo-J78KUNY32R1"
    ```

#### Installation directly from Git
Exemplary run with Azure Log Analytics enabled:
```
helm install -n test --create-namespace --generate-name ./falcon-integration-gateway \
     --set falcon.client_id=$FALCON_CLIENT_ID \
     --set falcon.client_secret=$FALCON_CLIENT_SECRET \
     --set falcon.cloud_region=$FALCON_CLOUD \
     --set push.azure_log_analytics.enabled=true \
     --set push.azure_log_analytics.workspace_id=1234ab-cdef-abc7d-acdb-82321223 \
     --set push.azure_log_analytics.primary_key=ASDFzxy/vgC/m6HKOY6bqi5g==
```
