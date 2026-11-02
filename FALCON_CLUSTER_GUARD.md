# Announcement: Prepare Your Kubernetes Environment for Migrating to Falcon Cluster Guard in January 2027

## Summary

The December 2026 releases of the Falcon sensor for Linux (DaemonSet), Kubernetes Admission Controller (KAC), and Image Assessment at Runtime (IAR) will be their final standalone versions.

In January 2027, CrowdStrike will consolidate those three features into Falcon Cluster Guard, a unified Kubernetes security suite that eliminates the need to manage three separate deployments.

## Applies To

- **Requires one or more of these subscriptions:**
  - Falcon Cloud Security with Containers CNAPP
  - Falcon Cloud Security with Containers Runtime Protection
  - Falcon Cloud Security with Containers Cloud Detection and Response
  - Falcon Cloud Security with Containers
- **Platform:** Kubernetes clusters running the Falcon sensor for Linux (DaemonSet), the Kubernetes Admission Controller, or Image Assessment at Runtime
  - Non-DaemonSet deployments and Container Sensor deployments are not affected
- **CrowdStrike clouds:** Available in all clouds

### Affected Falcon Helm Charts

| Product                                   | Helm Chart                                                                  | Affected                                          |
|:------------------------------------------|:----------------------------------------------------------------------------|:--------------------------------------------------|
| Falcon sensor for Linux (DaemonSet)       | [falcon-sensor](helm-charts/falcon-sensor/README.md)                        | Yes, when deployed as a DaemonSet (`node.enabled`) |
| Falcon Container Sensor (sidecar)         | [falcon-sensor](helm-charts/falcon-sensor/README.md)                        | No (`container.enabled`)                          |
| Kubernetes Admission Controller (KAC)     | [falcon-kac](helm-charts/falcon-kac/README.md)                              | Yes                                               |
| Image Assessment at Runtime (IAR)         | [falcon-image-analyzer](helm-charts/falcon-image-analyzer/README.md)        | Yes                                               |
| All of the above from a single chart      | [falcon-platform](helm-charts/falcon-platform/README.md)                    | Yes, if it deploys any affected component         |

## Details

The Falcon sensor for Linux (DaemonSet), KAC, and IAR currently operate as separate components. Falcon Cluster Guard unifies them into a single solution, enabling continuous context sharing and intelligence across components. This provides a complete, correlated view of your cluster, from deployment posture to workload behavior.

## Action Required

To prepare for Falcon Cluster Guard, we recommend identifying any DaemonSet sensor, KAC, or IAR products installed in your environments, and the corresponding scripts or the CI/CD workflows you use to deploy them. Having this inventory early will simplify your transition to Falcon Cluster Guard.

### Identify Affected Workloads on a Cluster

To list the affected workloads on a cluster, run:

```sh
kubectl get daemonsets,deployments --all-namespaces \
  -l 'app.kubernetes.io/component in (kernel_sensor,kac,iar)' \
  -L app.kubernetes.io/managed-by,helm.sh/chart
```

Falcon Container Sensor (sidecar) deployments are not affected and are not listed.

If labels have been removed or modified, you can search by image name instead:

```sh
kubectl get daemonsets,deployments --all-namespaces \
  -o jsonpath='{range .items[*]}{.kind}{"\t"}{.metadata.namespace}/{.metadata.name}{"\t"}{.spec.template.spec.containers[*].image}{"\n"}{end}' \
  | awk -F'\t' '($1 == "DaemonSet" && $3 ~ /falcon-(node-)?sensor/) || $3 ~ /falcon-(kac|imageanalyzer)/'
```

This matches the CrowdStrike registry image names, including images mirrored to a private registry under the same name. If you renamed the images when mirroring them, replace the names in the command with your image names.

### Identify Helm Releases

To list the Helm releases that deploy the affected charts, run:

```sh
helm list --all-namespaces | grep -E 'falcon-(sensor|kac|image-analyzer|platform)-[0-9]'
```

> [!NOTE]
> `helm list` only shows charts installed with `helm install` or `helm upgrade`, including tools that use Helm directly such as Flux, Rancher Fleet, Helmfile, and the Terraform Helm provider. It does not show charts rendered with `helm template` and applied separately, such as with Argo CD or Kustomize `helmCharts`. Use the workload query above to find those deployments.

### Identify GitOps Deployments

With GitOps tools, the Git repository is the source of truth, and changes made directly to the cluster are reverted. Identify the Git repositories and resources that reference the affected charts so you can update them when Falcon Cluster Guard launches.

To list Argo CD Applications that reference the affected charts, run:

```sh
kubectl get applications --all-namespaces -o yaml \
  | grep -nE 'crowdstrike\.github\.io/falcon-helm|CrowdStrike/falcon-helm|chart: falcon-(sensor|kac|image-analyzer|platform)'
```

To list Flux HelmReleases that reference the affected charts, run:

```sh
kubectl get helmreleases --all-namespaces -o yaml \
  | grep -nE 'chart: falcon-(sensor|kac|image-analyzer|platform)'
```

To search a Git repository for references to the affected charts and images, run this command from the repository root:

```sh
git grep -nE 'crowdstrike\.github\.io/falcon-helm|falcon-(sensor|kac|image-analyzer|platform)|falcon-(node-sensor|imageanalyzer)'
```

### Identify Installations with Next-Gen SIEM

To identify these products in your environment via Next-Gen SIEM Advanced Event Search, use the below queries.

List out all KAC installations online within the last week:

```
setTimeInterval(start="7d")
| event_platform="K8s" #event_simpleName="K8SClusterInfo"
| groupBy([K8SClusterId, K8SClusterName], limit=max, function=[count(aid, distinct=true)])
```

List out all IAR installations online within the last week:

```
setTimeInterval(start="7d")
| #event_simpleName=K8SCluster aid=iar
| groupBy([K8SClusterId, K8SClusterName], limit=max, function=[count(K8SClusterId, distinct=true)])
```

List out all Kubernetes clusters with DaemonSet Linux sensors online within the last week:

```
setTimeInterval(start="7d")
| event_platform="Lin" #event_simpleName=AgentOnline K8SClusterId=*
| groupBy([K8SClusterId], limit=max, function=[count(K8SClusterId, distinct=true)])
```

### When Falcon Cluster Guard Launches

When Falcon Cluster Guard launches, a single unified image will be published to the CrowdStrike registry. Once available, please complete the following steps:

- Update your scripts and CI/CD pipelines to reference the new image.
- Upgrade your Helm and Operator deployments using the upgrade and configuration instructions that will be shared prior to launch.

CrowdStrike will provide additional updates and migration guidance before the migration date.

## Resources

- Read our [documentation](https://docs.crowdstrike.com/)
- See [SUPPORT.md](SUPPORT.md) for Falcon Helm support options
