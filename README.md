# CrowdStrike Falcon Helm Charts

[![Artifact HUB](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/falcon-helm)](https://artifacthub.io/packages/search?repo=falcon-helm)

[Falcon](https://www.crowdstrike.com/) is the [CrowdStrike](https://www.crowdstrike.com/)
platform purpose-built to stop breaches via a unified set of cloud-delivered
technologies that prevent all types of attacks — including malware and much
more.

This repository is a collection of CrowdStrike Helm Charts. The Helm Charts developed here are an open source project, not a CrowdStrike product. As such, the project itself carries no formal support, expressed or implied.

## Helm Charts

| Helm Chart                                                           | Description                                                                                                                                  |
| :-                                                                   | :-                                                                                                                                           |
| [Falcon Sensor](helm-charts/falcon-sensor)                           | Deploys the Falcon Sensor to Kubernetes Nodes or as a Sidecar to a pod. See [the README](helm-charts/falcon-sensor/README.md) for more info. |
| [Falcon Integration Gateway](helm-charts/falcon-integration-gateway) | Deploys the Falcon Integration Gateway. See [the README](helm-charts/falcon-integration-gateway/README.md) for more info.                    |
| [Falcon Kubernetes Admission Controller](helm-charts/falcon-kac)     | Deploy the Falcon Kubernetes Admission Controller. See [the README](helm-charts/falcon-kac/README.md) for more info. | 

## Developer Guide
If you are a developer, please read our [Developer's Guide](docs/developer_guide.md).

