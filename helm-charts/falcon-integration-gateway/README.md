# Helm Chart - Falcon Integration Gateway

[Falcon Integration Gateway](https://github.com/CrowdStrike/falcon-integration-gateway) (FIG) forwards threat detection findings from CrowdStrike Falcon platform to the [backend](https://github.com/CrowdStrike/falcon-integration-gateway/tree/main/fig/backends) of your choice. Consult the project page to learn more about its capabilities. This document describes a helm chart that can be used to deploy the FIG in various configurations.

## Dependencies

1. Requires a Kubernetes cluster
1. Helm 3.x is installed and supported by the Kubernetes vendor.
1. Must be a CrowdStrike customer
1. At least one [backend](https://github.com/CrowdStrike/falcon-integration-gateway/tree/main/fig/backends) prepared to ingest events

## Configuration Options

The following tables lists the Falcon Sensor configurable parameters and their default values.

| Parameter                                              | Description                                            | Default                    |
| :----------------------------------------------------- | :----------------------------------------------------- | :------------------------- |
| `falcon.client_id`                                     | CrowdStrike API Client ID                              | None                       |
| `falcon.client_secret`                                 | CrowdStrike API Client Secret                          | None                       |
| `falcon.cloud_region`                                  | CrowdStrike Cloud Region (us-1, us-2, eu-1, us-gov-1)  | None       (Required)      |
| `falcon.existingSecret`                                | Existing k8s secret name containing the above values   | None                       |
| `credentials_store.store`                              | Use valid credentials store (ssm, secrets_manager)     | None                       |
| `credentials_store.ssm.region`                         | AWS region for SSM                                     | None                       |
| `credentials_store.ssm.client_id`                      | SSM parameter name for client_id                       | None                       |
| `credentials_store.ssm.client_secret`                  | SSM parameter name for client_secret                   | None                       |
| `credentials_store.secrets_manager.region`             | AWS region for Secrets Manager                         | None                       |
| `credentials_store.secrets_manager.secret_name`        | Secrets Manager secret name                            | None                       |
| `credentials_store.secrets_manager.client_id_key`      | Secrets Manager key for client_id                      | None                       |
| `credentials_store.secrets_manager.client_secret_key`  | Secrets Manager key for client_secret                  | None                       |
| `falcon.integration_gateway.application_id`            | Unique string for each FIG instance within your CID    | helm-chart-default         |
| `falcon.integration_gateway.level`                     | Logging level (ERROR, WARN, INFO, DEBUG)               | INFO                       |
| `falcon.integration_gateway.severity_threshold`        | Filter events based on severity (1-5)                  | 2                          |
| `falcon.integration_gateway.older_than_days_threshold` | Filter events based on age in days                     | 21                         |
| `falcon.integration_gateway.detections_exclude_clouds` | Exclude events based on cloud origination              | None                       |
| `falcon.integration_gateway.worker_threads`            | Number of FIG application threads to process events    | 4                          |
| `falcon.integration_gateway.offset`                    | Offset number to start the stream from                 | 0                          |
| `push.aws_security_hub.enabled`                        | Enable event forwarding to AWS Security Hub            | `false`                    |
| `push.aws_security_hub.region`                         | AWS Region                                             | None                       |
| `push.aws_security_hub.confirm_instance`               | Confirm instance in AWS account supported region       | `true`                     |
| `push.aws_sqs.enabled`                                 | Enable event forwarding to AWS SQS                     | `false`                    |
| `push.aws_sqs.region`                                  | AWS Region                                             | None                       |
| `push.aws_sqs.sqs_queue_name`                          | AWS SQS Queue Name                                     | None                       |
| `push.azure_log_analytics.enabled`                     | Enable event forwarding to Azure Log Analytics         | `false`                    |
| `push.azure_log_analytics.workspace_id`                |                                                        | None                       |
| `push.azure_log_analytics.primary_key`                 |                                                        | None                       |
| `push.azure_log_analytics.arc_autodiscovery`           |                                                        | `false`                    |
| `push.chronicle.enabled`                               | Enable event forwarding to Google Chronicle            | `false`                    |
| `push.chronicle.region`                                | Google Cloud Chronicle Region                          | None                       |
| `push.chronicle.service_account`                       | Google Cloud Service Account                           | None                       |
| `push.chronicle.customer_id`                           | Google Chronicle Customer ID                           | None                       |
| `push.cloudtrail_lake.enabled`                         | Enable event forwarding to AWS CloudTrail Lake         | `false`                    |
| `push.cloudtrail_lake.channel_arn`                     | CloudTrail Lake Channel for sending events             | None                       |
| `push.cloudtrail_lake.region`                          | AWS Region                                             | None                       |
| `push.gcp_security_command_center.enabled`             | Enable event forwarding to GCP Security Command Center | `false`                    |
| `push.vmware_workspace_one.enabled`                    | Enable event forwarding to VMware Workspace ONE        | `false`                    |
| `push.vmware_workspace_one.syslog_host`                |                                                        | None                       |
| `push.vmware_workspace_one.syslog_port`                |                                                        | None                       |
| `push.vmware_workspace_one.token`                      |                                                        | None                       |
| `push.generic.enabled`                                 | Enable event forwarding to stdout (debugging)          | `false`                    |
| `serviceAccount.annotations`                           | Annotations for serviceAccount                         | `{}`                       |

## API Scopes

- Obtain OAuth2 API credentials for CrowdStrike Falcon
  - Navigate to [API Clients and Keys](https://falcon.crowdstrike.com/support/api-clients-and-keys) within CrowdStrike Falcon platform.
  - Use *Add new API client* button in the top right corner to create a new key pair
  - Make sure only the following permissions are assigned to the key pair:
    - **Event streams**: [Read]
    - **Hosts**: [Read]

> ***Consult the [backend](https://github.com/CrowdStrike/falcon-integration-gateway/tree/main#backends-w-available-deployment-guides) guides for additional API scopes that may be required.***

## Authentication

FIG requires the authentication of an API client ID and client secret, along with its associated cloud region, to establish a connection with the CrowdStrike API.

FIG supports auto-discovery of the Falcon cloud region. If you do not specify a cloud region, FIG will attempt to auto-discover the cloud region based on the API client ID and client secret provided.

> [!IMPORTANT]
> Auto-discovery is only available for [us-1, us-2, eu-1] regions.

Below are a few examples of how to provide the Falcon API credentials to the FIG helm chart.

### Via values.yaml

#### Example declaring the Falcon API credentials directly

```yaml
falcon:
   client_id: "YOUR_FALCON_CLIENT_ID"
   client_secret: "YOUR FALCON_CLIENT_SECRET"
   cloud_region: "us-1"
```

#### Example using AWS Secrets Manager

```yaml
falcon:
   cloud_region: "us-1"
   credentials_store:
      store: "secrets_manager"
      secrets_manager:
         region: "us-west-2"
         secret_name: "falcon-k8s-secret"
         client_id_key: "client_id"
         client_secret_key: "client_secret"
```

#### Example using an existing k8s secret

```yaml
falcon:
   existingSecret: "falcon-k8s-secret"
```

### Via Helm CLI

You can also use the helm CLI to provide the Falcon API credentials.

#### Example specifying the Falcon API credentials directly

```bash
helm upgrade --install falcon-fig crowdstrike/falcon-integration-gateway -n falcon-integration-gateway --create-namespace \
     --set falcon.client_id=$FALCON_CLIENT_ID \
     --set falcon.client_secret=$FALCON_CLIENT_SECRET \
     --set falcon.cloud_region=$FALCON_CLOUD
     ...
```

#### Example using AWS SSM parameter store as the credentials store

```bash
helm upgrade --install falcon-fig crowdstrike/falcon-integration-gateway -n falcon-integration-gateway --create-namespace \
     --set falcon.cloud_region=$FALCON_CLOUD \
     --set credentials_store.store="ssm" \
     --set credentials_store.ssm.region="us-east-2" \
     --set credentials_store.ssm.client_id="/falcon/fig/client_id" \
     --set credentials_store.ssm.client_secret="/falcon/fig/client_secret"
     ...
```

## Installation

### Helm Chart

The helm chart is under active development. Contributors are welcomed to install either directly from the git repository or from the helm repository.

#### Installation from Helm Repository

1. Add the CrowdStrike Falcon Helm repository

   ```bash
   helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
   ```

1. Update the local Helm repository Cache

   ```bash
   helm repo update
   ```

1. Example install with Azure Log Analytics enabled:

   ```bash
   helm upgrade --install falcon-fig crowdstrike/falcon-integration-gateway -n falcon-integration-gateway --create-namespace \
        --set falcon.client_id=$FALCON_CLIENT_ID \
        --set falcon.client_secret=$FALCON_CLIENT_SECRET \
        --set falcon.cloud_region=$FALCON_CLOUD \
        --set push.azure_log_analytics.enabled=true \
        --set push.azure_log_analytics.workspace_id=1234ab-cdef-abc7d-acdb-82321223 \
        --set push.azure_log_analytics.primary_key=ASDFzxy/vgC/m6HKOY6bqi5g==
   ```

1. Alternative example install with AWS Security Hub enabled:

   ```bash
   helm upgrade --install falcon-fig crowdstrike/falcon-integration-gateway -n falcon-integration-gateway --create-namespace \
        --set falcon.client_id=$FALCON_CLIENT_ID \
        --set falcon.client_secret=$FALCON_CLIENT_SECRET \
        --set falcon.cloud_region=$FALCON_CLOUD \
        --set push.aws_security_hub.enabled=true \
        --set push.aws_security_hub.region="eu-west-2" \
        --set serviceAccount.annotations."eks.amazonaws.com/role-arn"="arn:aws:iam::12345678910:role/fig-demo-J78KUNY32R1"
    ```

#### Installation directly from Git

Example run with Azure Log Analytics enabled:

```bash
helm install -n test --create-namespace --generate-name ./falcon-integration-gateway \
     --set falcon.client_id=$FALCON_CLIENT_ID \
     --set falcon.client_secret=$FALCON_CLIENT_SECRET \
     --set falcon.cloud_region=$FALCON_CLOUD \
     --set push.azure_log_analytics.enabled=true \
     --set push.azure_log_analytics.workspace_id=1234ab-cdef-abc7d-acdb-82321223 \
     --set push.azure_log_analytics.primary_key=ASDFzxy/vgC/m6HKOY6bqi5g==
```
