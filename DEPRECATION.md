# Deprecation Notes

This document outlines deprecated features and charts in our Helm chart repository. Support information can be found in [SUPPORT.md](./SUPPORT.md).

## Previously Removed
### Charts
- **cs-k8s-protection-agent** -  End-of-Support (EOS) date is August 18, 2025
  - **Removal Date**: September 17, 2025
  - **Reason**: Cluster visibility has been added to the [Falcon Kubernetes Admission Controller (KAC)](https://github.com/CrowdStrike/falcon-helm/blob/main/helm-charts/falcon-kac/README.md) ver. 7.20 and newer.
  - **Migration Path**: See [Tech Alert | Falcon Kubernetes Protection Agent End of Support and Transition to Falcon Kubernetes Admission Controller](https://falcon.crowdstrike.com/support/release-notes/tech-alert-falcon-kubernetes-protection-agent-end-of-support-and-transition-to-falcon-kubernetes-admission-controller-2)
