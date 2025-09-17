# CrowdStrike Falcon Helm Charts

[![Artifact HUB](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/falcon-helm)](https://artifacthub.io/packages/search?repo=falcon-helm)

[Falcon](https://www.crowdstrike.com/) is the [CrowdStrike](https://www.crowdstrike.com/)
platform purpose-built to stop breaches via a unified set of cloud-delivered
technologies that prevent all types of attacks — including malware and much
more.

This repository is a collection of CrowdStrike Helm Charts designed to streamline the deployment and use of CrowdStrike products on Kubernetes clusters.

## Helm Charts

| Helm Chart                                                           | Description                                                                                                                                  |
| :-                                                                   | :-                                                                                                                                           |
| [Falcon Sensor](helm-charts/falcon-sensor)                           | Deploys the Falcon Sensor to Kubernetes Nodes or as a Sidecar to a pod. See [the README](helm-charts/falcon-sensor/README.md) for more info. |
| [Falcon Integration Gateway](helm-charts/falcon-integration-gateway) | Deploys the Falcon Integration Gateway. See [the README](helm-charts/falcon-integration-gateway/README.md) for more info.                    |
| [Falcon Kubernetes Admission Controller](helm-charts/falcon-kac)     | Deploy the Falcon Kubernetes Admission Controller. If you're looking for Kubernetes Protection Agent (KPA), it has been deprecated; use this chart instead. See [the README](helm-charts/falcon-kac/README.md) for more info. |
| [Falcon Image Analyzer](helm-charts/falcon-image-analyzer)           | Deploy the Falcon Image Analyzer. See [the README](helm-charts/falcon-image-analyzer/README.md) for more info.       |
| [Falcon Self Hosted Registry Assessment](helm-charts/falcon-self-hosted-registry-assessment)           | Deploy the Falcon Self Hosted Registry Assessment. See [the README](helm-charts/falcon-self-hosted-registry-assessment/README.md) for more info.       |
| [ASPM Relay](helm-charts/aspm-relay)                                 | Deploy the ASPM Relay. See [the README](helm-charts/aspm-relay/README.md) for more info.                                                     |

## Developer Guide
If you are a developer, please read our [Developer's Guide](docs/developer_guide.md).

## Support
CrowdStrike Falcon Helm is an open source project maintained by CrowdStrike. CrowdStrike will support use of `falcon-helm` in connection with the use of CrowdStrike’s products pursuant to applicable terms in the license for such product.

Learn how to get help, where to submit requests, and more [here](SUPPORT.md)
