# CrowdStrike Falcon Image Analyzer (IAR Image Assessment at Runtime) Helm Chart

[Falcon](https://www.crowdstrike.com/) is the [CrowdStrike](https://www.crowdstrike.com/)
platform purpose-built to stop breaches via a unified set of cloud-delivered
technologies that prevent all types of attacks — including malware and much
more.

## Table of Contents
- [Kubernetes Cluster Compatibility](#kubernetes-cluster-compatibility)
- [New Updates in the Current Version](#new-updates-in-current-release)
- [Dependencies](#dependencies)
- [Helm Repo Setup](#helm-repo-setup)
  - [Add The Crowdstrike Falcon Helm Repo](#add-the-crowdstrike-falcon-helm-repository)
  - [Update Helm Repo](#update-the-local-helm-repository-cache)
- [Configuration Options](#falcon-configuration-options)
  - [Allow traffic to CrowdStrike servers](#allow-traffic-to-crowdstrike-servers)
- [Installation on Kubernetes Cluster](#installing-on-kubernetes-cluster-nodes)
  - [Installing using Helm Chart](#install-using-helm-chart)
  - [Deployment considerations](#deployment-considerations)
  - [Pod Security Standards](#pod-security-standards)
  - [Temp Mounts](#temp-volume-mount)
  - [IAM Roles](#aws-iam-roles-for-service-accounts)
  - [Authentication for Private Registries](#authentication-for-private-registries)
  - [Proxy Usage](#proxy-usage)
  - [Pod Eviction Issue](#pod-eviction)
  - [Exclusions](#exclusions)
    - [Registry Exclusion](#registry)
    - [Namespace Exclusion](#namespace)
    - [Pod Exclusions](#pod-exclusions-via-podspec)
- [Uninstalling IAR](#uninstall-helm-chart)


## Kubernetes cluster compatibility

The Falcon Image Analyzer Helm chart has been tested to deploy on the following Kubernetes distributions:

* Amazon Elastic Kubernetes Service (EKS) - EKS and EKS Fargate
* Azure Kubernetes Service (AKS)
* Google Kubernetes Engine (GKE)
* SUSE Rancher K3s
* Red Hat OpenShift Kubernetes


## New updates in current release
Helm (1.1.17) + iar 1.0.21
- ~~`scanStats`~~ field deprecated. The feature is always on from IAR 1.0.21 onwards
- Adding Cluster Name autodiscovery in IAR 1.0.21 if cluster name is left blank
- Adding Image Analyzer - Kubernetes Admission Control ( KAC ) inter-communication. Supported only from `crowdstrike/falcon-image-analyzer  chart version >= 1.0.17`
- Adding auto discovery of DockerConfig / Regsitry Credential secrets to be pulled in for image. see `privateRegistries.autoDiscoverCredentials`



## Dependencies

1. Requires a x86_64/arm64 Kubernetes cluster
2. Before deploying the Helm chart, you should have the `falcon-imageanalyzer` container image in your own container registry, or use CrowdStrike's registry before installing the Helm chart. See the [Deployment Considerations](#deployment-considerations) for more.
3. Helm 3.x is installed and supported by the Kubernetes vendor.

## Helm Repo Setup

### Add the CrowdStrike Falcon Helm repository

```
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
```

### Update the local Helm repository cache

```
helm repo update
```

## Falcon configuration options

The following tables list the Falcon sensor configurable parameters and their default values.

| Parameter                                                                                                                                          | Description                                                                                                                                                    | Default                                                                                                     |
|:---------------------------------------------------------------------------------------------------------------------------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------|:------------------------------------------------------------------------------------------------------------|
| `deployment.enabled`   required                                                                                                                    | Set to `true` if running in Watcher Mode i.e.                                                                                                                  | false                                                                                                       |
| `daemsonset.enabled`     required                                                                                                                  | Set to `true` if running in Socket Mode i.e. Both CANNOT be true . This  causes the IAR to run in `socket` mode                                                | false                                                                                                       |
| `watcher.listPageSize`     optional ( available in falcon-imageanalyzer Helm Chart >= 1.1.9)                                                       | numeric value to be used for listing pods in watcher mode                                                                                                      | 500                                                                                                         |
| `priorityClassName`                  optional    ( available in falcon-imageanalyzer Helm Chart >= 1.1.4)                                          | Set to `system-node-critical` or `system-cluster-critical` to avoid pod evictions due to resource limits.                                                      | ""                                                                                                          |
| `privateRegistries.credentials`  optional                                                                                                          | Use this param to provide the comma separated registry secrets of the form namsepace1:secretname1,namespace:secret2                                            | ""                                                                                                          |
| `privateRegistries.autoDiscoverCredentials`  optional                                                                                              | Set to `true` to automatically discovery all Docker secrets for private registries. note that if this is `true` the above `privateRegistries.credentials`is NA | true                                                                                                        |
| `image.repository`       required                                                                                                                  | IAR image repo name                                                                                                                                            | `[CROWDSTRIKE_IMAGE_REGISTRY]/falcon-imageanalyzer/[us-1/us-2/eu-1/gov1/gov2]/release/falcon-imageanalyzer` |
| `image.tag`        required                                                                                                                        | Image tag version                                                                                                                                              | None                                                                                                        |
| `image.registryConfigJSON`        optional                                                                                                         | iar private registry secret in docker config format                                                                                                            | None                                                                                                        |
| `azure.enabled`         optional                                                                                                                   | Set to `true` if cluster is Azure AKS or self-managed on Azure nodes.                                                                                          | false                                                                                                       |
| `azure.azureConfig`          optional                                                                                                              | Azure  config file path                                                                                                                                        | `/etc/kubernetes/azure.json`                                                                                |
| `gcp.enabled`                  optional                                                                                                            | Set to `true` if cluster is Gogle GKE or self-managed on Google Cloud GCP nodes.                                                                               | false                                                                                                       |
| `exclusions.namespace`                  optional   ( available in falcon-imageanalyzer >= 1.0.8 and Helm Chart v >= 1.1.3)                         | Set the value as a comma separate list of namespaces to be excluded. all pods in that namespace(s) will be excluded                                            | ""                                                                                                          |
| `exclusions.registry`                  optional   ( available in falcon-imageanalyzer >= 1.0.8 and Helm Chart v >= 1.1.3)                          | Set the value as a comma separate list of registries to be excluded. all images in that registry(s) will be excluded                                           | ""                                                                                                          |
| `log.output`                  optional   ( available  Helm Chart v >= 1.1.7 & falcon-imageanalyzer >= 1.0.12)                                      | Set the value to for log output terminal. `2=stderr` and `1=stdout`                                                                                            | 2 ( stderr )                                                                                                |
| `hostNetwork`                  optional   ( available  Helm Chart v >= 1.1.11)                                                                     | Set the value to `true` to use the hostNetwork instead of pod network                                                                                          | `false`                                                                                                     |
| `dnsPolicy`                  optional   ( available  Helm Chart v >= 1.1.11)                                                                       | Set the value to any supported value from https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-s-dns-policy                            | ``  no value implies `Default`                                                                              |
| ~~`scanStats.enabled`~~                 optional   (**Deprecated in 1.1.17+** . available  Helm Chart v >= 1.1.8 & falcon-imageanalyzer >= 1.0.13) | Set `enabled` to true for agent to send scan error and stats to cloud                                                                                          | `true`                                                                                                      |
| `crowdstrikeConfig.clusterName`     optional                                                                                                       | Cluster name                                                                                                                                                   | None                                                                                                        |
| `crowdstrikeConfig.enableDebug`   optional                                                                                                         | Set to `true` for debug level log verbosity.                                                                                                                   | false                                                                                                       |
| `crowdstrikeConfig.enableKlogs`   optional                                                                                                         | Set to `true` for kubernetes api log verbosity.                                                                                                                | false                                                                                                       |
| `crowdstrikeConfig.clientID`    required                                                                                                           | CrowdStrike Falcon OAuth API Client ID                                                                                                                         | None                                                                                                        |
| `crowdstrikeConfig.clientSecret`     required                                                                                                      | CrowdStrike Falcon OAuth API Client secret                                                                                                                     | None                                                                                                        |
| `crowdstrikeConfig.cid`         required                                                                                                           | Customer ID (CID)                                                                                                                                              | None                                                                                                        |
| `crowdstrikeConfig.dockerAPIToken`  optional                                                                                                       | Crowdstrike Artifactory Image Pull Token for pulling IAR image directly from  `[CROWDSTRIKE_IMAGE_REGISTRY] described below`                                   | None                                                                                                        |
| `crowdstrikeConfig.existingSecret`      optional                                                                                                   | Existing secret ref name of the customer Kubernetes cluster                                                                                                    | None                                                                                                        |
| `crowdstrikeConfig.agentRegion`      required                                                                                                      | Region of the CrowdStrike API to connect to value should be one of `us-1/us-2/eu-1/gov1/gov2`                                                                  | None                                                                                                        |
| `crowdstrikeConfig.agentRuntime`             required ( if daemonset )                                                                             | The underlying runtime of the OS. docker/containerd/podman/crio. ONLY TO BE USED with `daemonset.enabled` = `true`                                             | None                                                                                                        |
| `crowdstrikeConfig.agentRuntimeSocket`              optional                                                                                       | The unix socket path for the runtime socket. For example: `unix///var/run/docker.sock`. ONLY TO BE USED with ONLY TO BE USED with `daemonset.enabled` = `true` | None                                                                                                        |



The `[CROWDSTRIKE_IMAGE_REGISTRY]` can be replaced with below registries based on the environment ( `agentRegion` )

- `us-1 or us-2 or eu-1` = `registry.crowdstrike.com`
- `gov1` = `registry.laggar.gcw.crowdstrike.com`
- `gov2` = `registry.us-gov-2.crowdstrike.mil`



| Region | ImageName                                                                                    | 
|:-------|:---------------------------------------------------------------------------------------------|
| `us-1` | `registry.crowdstrike.com/falcon-imageanalyzer/us-1/release/falcon-imageanalyzer`            |
| `us-2` | `registry.crowdstrike.com/falcon-imageanalyzer/us-2/release/falcon-imageanalyzer`            | 
| `eu-1` | `registry.crowdstrike.com/falcon-imageanalyzer/eu-1/release/falcon-imageanalyzer`            |
| `gov1` | `registry.laggar.gcw.crowdstrike.com/falcon-imageanalyzer/gov1/release/falcon-imageanalyzer` |
| `gov2` | `registry.us-gov-2.crowdstrike.mil/falcon-imageanalyzer/gov2/release/falcon-imageanalyzer`   |



Note:
-
- Please set either `daemonset.enabled` OR `deployment.enabled`

- For deployment, the replica count is set to **1** always. This is because IAR is not a load balanced service i.e. increasing replicas will not divide the work but rather duplicate creating unncessary resource consumption.

- For ease of installation and avoiding complication, the recommended way to install IAR is to create a `config_values.yaml` file at some path like below

For deployment
```
deployment:
  enabled: true


#optional. Use If in EKS / or EC2 required Roles. See Section IAM Roles fopr more details
serviceAccount:
  # Annotations to add to the service account
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::532730071073:role/svc-devtest-cwpp-oidc-eks


#optional. Use if target registries are private with secret. See section Authentication for Private Registries for more details
privateRegistries
  credentials
  autoDiscoverCredentials

image:
  repository: "[CROWDSTRIKE_IMAGE_REGISTRY]/falcon-imageanalyzer/us-1/release/falcon-imageanalyzer"
  tag: 1.0.3

  # OPTIONAL
  # Value must be base64. This setting conflicts with image.pullSecret
  # The base64 encoded string of the docker config json for the pull secret can be
  # gotten through:
  # $ cat ~/.docker/config.json | base64 -
  registryConfigJSON:
crowdstrikeConfig:
  clientID: "xxxxxxxxxxx"
  clientSecret: "yyyyyyyyyyyy"
  clusterName: my-test-cluster
  agentRegion: us-1 or us-2 or eu-1 or gov1 or gov2
  cid: MYCID-XY
  dockerAPIToken: asdfsfsdfsfsd ( Crowdstrike Artifacotry Token for IAR Image )

```

for daemonset
```
daemonset:
  enabled: true



#optional. Use If in EKS / or EC2 required Roles. See Section IAM Roles fopr more details
serviceAccount:
  # Annotations to add to the service account
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::532730071073:role/svc-devtest-cwpp-oidc-eks


#optional. Use if target registries are private with secret. See section Authentication for Private Registries for more details
privateRegistries
  credentials
  autoDiscoverCredentials

image:
  repository: "[CROWDSTRIKE_IMAGE_REGISTRY]/falcon-imageanalyzer/us-1/release/falcon-imageanalyzer"
  tag: 1.0.3

  # OPTIONAL
  # Value must be base64. This setting conflicts with image.pullSecret
  # The base64 encoded string of the docker config json for the pull secret can be
  # gotten through:
  # $ cat ~/.docker/config.json | base64 -
  registryConfigJSON:

crowdstrikeConfig:
  clientID: "xxxxxxxxxxx"
  clientSecret: "yyyyyyyyyyyy"
  clusterName: my-test-cluster
  agentRegion: us-1 or us-2 or eu-1 or gov1 or gov2
  agentRuntime: containerd or crio or podman or docker
  cid: MYCID-XY
  dockerAPIToken: asdfsfsdfsfsd ( Crowdstrike Artifacotry Token for IAR Image )

```

If the IAR image is already pulled in advance and pushed to another customer private registry then use that in place
of `[CROWDSTRIKE_IMAGE_REGISTRY]` and the secret for that should be passed in the
`image.registryConfigJSON` with explanation above and `crowdstrikeConfig.dockerAPIToken` should NOT be used


<!-- markdown-link-check-disable -->
### Allow traffic to CrowdStrike servers
***( The below server settings are default for IAR >= `v1.0.20`  )***

From IAR ver >-= 1.0.20 IAR will dynamically switch between PRIMARY and SECONDARY Scan Upload Servers so as to maximize throughput and minmize error rate

IAR requires internet access to your assigned CrowdStrike authentication API and upload servers.
If your network requires it, configure your allowlists with your assigned CrowdStrike cloud servers.

| Region | Authentication API |             PRIMARY Scan Upload Servers             | SECONDARY Scan Upload Servers          |   
|:----:|:--:|:---------------------------------------------------:|----------------------------------------| 
| US-1 | https://api.crowdstrike.com |    https://container-upload.us-1.crowdstrike.com    | https://api.crowdstrike.com            |
| US-2 | https://api.us-2.crowdstrike.com |    https://container-upload.us-2.crowdstrike.com    | https://api.us-2.crowdstrike.com       |
| EU-1 | https://api.eu-1.crowdstrike.com |    https://container-upload.eu-1.crowdstrike.com    | https://api.eu-1.crowdstrike.com       |
| US-GOV-1 | https://api.laggar.gcw.crowdstrike.com | https://container-upload.laggar.gcw.crowdstrike.com | https://api.laggar.gcw.crowdstrike.com |
| US-GOV-2 | https://api.us-gov-2.crowdstrike.mil |  https://container-upload.us-gov-2.crowdstrike.mil  | https://api.us-gov-2.crowdstrike.mil   |

#### ***For IAR versions < 1.0.20 both Authtentication/Upload Servers point to the same

| Region | Authentication API |          Scan Upload Servers           |   
|:----:|:--:|:--------------------------------------:| 
| US-1 | https://api.crowdstrike.com |      https://api.crowdstrike.com       |
| US-2 | https://api.us-2.crowdstrike.com |    https://api.us-2.crowdstrike.com    |
| EU-1 | https://api.eu-1.crowdstrike.com |    https://api.eu-1.crowdstrike.com    |
| US-GOV-1 | https://api.laggar.gcw.crowdstrike.com | https://api.laggar.gcw.crowdstrike.com |
| US-GOV-2 | https://api.us-gov-2.crowdstrike.mil |  https://api.us-gov-2.crowdstrike.mil  |



<!-- markdown-link-check-enable -->


## Installing on Kubernetes cluster nodes

### Install Using Helm Chart

Before you install IAR, set the Helm chart variables and add them to the `config_values.yaml` file. Then, run the following to install IAR:

```
helm upgrade --install -f /path/to/config_values.yaml \
      --create-namespace -n falcon-image-analyzer imageanalyzer crowdstrike/falcon-image-analyzer
```


For more details, see the [falcon-helm](https://github.com/CrowdStrike/falcon-helm) repository.

```
helm show values crowdstrike/falcon-image-analyzer
```


### Deployment considerations

For a successful deployment, you will want to ensure that:
1. By default, the Helm chart installs in the `default` namespace. Best practices for deploying to Kubernetes is to create a new namespace. This can be done by adding `--create-namespace -n falcon-image-analyzer` to your `helm install` command. The namespace can be any name that you wish to use.
1. You must be a cluster administrator to deploy Helm charts to the cluster.
1. CrowdStrike's Helm chart is a project, not a product, and released to the community as a way to automate sensor deployment to Kubernetes clusters. The upstream repository for this project is [https://github.com/CrowdStrike/falcon-helm](https://github.com/CrowdStrike/falcon-helm).

### Pod Security Standards

Starting with Kubernetes 1.25, Pod Security Standards will be enforced. Setting the appropriate Pod Security Standards policy needs to be performed by adding a label to the namespace. Run the following command, and replace `my-existing-namespace` with the namespace that you have installed the falcon sensors, for example: `falcon-image-analyzer`.
```
kubectl label --overwrite ns my-existing-namespace \
  pod-security.kubernetes.io/enforce=privileged
```

If you want to silence the warning and change the auditing level for the Pod Security Standard, add the following labels:
```
kubectl label ns --overwrite my-existing-namespace pod-security.kubernetes.io/audit=privileged
kubectl label ns --overwrite my-existing-namespace pod-security.kubernetes.io/warn=privileged
```

### Temp Volume Mount
In order to perform image scan, IAR will pull the image and un-compress it for traversal through layers and image config and manifest.
For this, IAR will use a temp space that is added as a mount of type `emptyDir` . The idea of the storage here is to accommodate the max size image that one could run in the kubernetes.
By Default, this is set to `20Gi` but can be overridden by the customer by adding the following in the `config_values.yaml`
```
# This is a mandatory mount for both deployment and daemonset.
# this is used as a tmp working space for image storage.
# adjust this space to any comfortable value. the temp ssize limit should be equal to 
# 2 X to the largest image possible to run in the container.
# for e.g. if the largest possible image is in the range of 4g put 8Gi as the value.
volumes:
  - name: tmp-volume
    emptyDir:
      sizeLimit: 20Gi --> Change this to any other value if need
```

**From the IAR `1.0.8` on wards any image that is greater than the allowed size will NOT be scanned to avoid container eviction crash due to tmp space shortage.**


### AWS IAM Roles for Service Accounts
- **KIAM OR Kube2IAM.** 
For the IAR to detect cloud as AWS, it should be able to retrieve sts token to assume role to retrieve ECR Tokens.
  There are 2 options for  that . If your EKS cluster us using the **kiam** or **kube2iam** admission controller, add annotations
  for the IAR service account in the `config_values.yaml` as stated below, before installing. Make sure the roles have trust-relationship to allow
  the serviceaccount in the `falcon-image-analyzer` namespace
```
serviceAccount:
  # Annotations to add to the service account
  annotations:
    iam.amazonaws.com/role: role-name-with-s2sassume-role-permission -> NOTE That is role name ONLY Not the full ARN
```

Make sure the above role `role-name-with-s2sassume-role-permission` in **AWS** has the as policy with ECR all permissions as IAR will need to pull images and assume ECR Tokens
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "ecr:*"
            ],
            "Resource": "*"
        }
    ]
}
```
The above role is important so that IAR can read/pull/list from all ECR registries if any workload is launched with an image from any ECR.
Modify the resource part of the role above to restrict to specific registry or AWS Account. Keep the actions as atleast get* and gist*.
Consult the AWS IAM Role Guide/Wizard for syntax and avoid typos.

Make sure the trust-relationship of the has  principal role of `kiam` or `kube2iam` service with `s2s:assumeRole` permissions.

- **OIDC Connector.**
For the EKS Cluster using the OIDC providers add the annotation as below. Make sure the roles have trust-relationship to allow
  the serviceaccount in the `falcon-image-analyzer` namespace


```
serviceAccount:
  # Annotations to add to the service account
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::111122223333:role/my-role
```

Make sure the above role `arn:aws:iam::111122223333:role/my-role` in **AWS** has the as policy with ECR all permissions as IAR will need to pull images and assume ECR Tokens
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "ecr:*"
            ],
            "Resource": "*"
        }
    ]
}
```

and a trust-relationship as
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "EKS-OIDC-ARN"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "EKS-OIDC-ARN:aud": "sts.amazonaws.com",
                    "EKS-OIDC-ARN:sub": "system:serviceaccount:falcon-image-analyzer:imageanalyzer-falcon-image-analyzer"
                }
            }
        }
    ]
}
```

Here `falcon-image-analyzer` is the namespace of IAR and `imageanalyzer-falcon-image-analyzer` is the name of the iar Service Account

### Authentication for Private Registries
- If you are using ECR or cloud based Private Registries then assigning the IAM role to the iar service-account in `falcon-image-analyzer` namespace should be enough

- If you are using a 3rd party private registry such as jfrog artifactory for running all your workload images, etc. then use the below param in the `config_values.yaml`
```
privateRegistries:
  credentials: ""
  autoDiscoverCredentials: true
```
`credentials`
to provide the comma separated registry secrets of the form `"namsepace1:secretname1,namespace:secret2"`
each secret should be of type docker-registry for each of the private registry that is used.
for e.g.  a docker-registry secret can be created as below
```
 kubectl create secret docker-registry regcred \
--docker-server=my-artifactory.jfrog.io \
--docker-username=read-only \
--docker-password=my-super-secret-pass \
--docker-email=johndoe@example.com  -n my-app-ns

 kubectl create secret docker-registry regcred2 \
--docker-server=my2ndregistry-artifactory.jfrog.io \
--docker-username=2nd-read-only \
--docker-password=2nd-my-super-secret-pass \
--docker-email=johndoe@example.com  -n my-app-ns

```
use the above secret as `"my-app-ns:regcred,my-app-ns:regcred2"`

`autoDiscoverCredentials`
if set to true, the IAR will try to discover the docker-registry secrets across all namespaces.
if autoDiscoverCredentials is set to `true` then the provided credentials are ignored. Note that the secret
should be existing of type docker-registry in ANY namespace on the cluster to be discovered. 
IAR will NOT pick up any new secret added to the cluster after IAR is running. 
For that a restart of IAR is needed.

### PROXY Usage

The proxy parameters canbe set as below
```
proxyConfig:
  HTTP_PROXY: ""
  HTTPS_PROXY: ""
  NO_PROXY: ""

```

If a customer us using proxy settings. Please make sure to add the registry domains ```myreg.some.com``` in the ```NO_PROXY```.
This is so that the IAR can connect to the registries without proxy and authenticate if needed using secrets provided or download the public free images.

***Note that some registries domains also have other urls based on the auth challenge that is sent by the registry service. Please make sure to add those as well to ```NO_PROXY```
for e.g. for gitlab registries there exists the 
- registry domain ```my-reg.gitlab.com``` 
- and the other ```www.gitlab.com```

- The above is very registry provider specific. One needs to ensure nothing ie being blocked by Proxy 

### Pod Eviction
If for some reason pod evictions are observed in the Cluster due to exceeding ephemeral storage
please set the `priorityClassName`  to `system-node-critical` or `system-cluster-critical` in `config-values.yaml` and update.

### Exclusions
***(Available in falcon-imageanalyzer v >= 1.0.8 and Helm Chart v >= 1.1.3)***

In order to exclude pods from scans, you can either exclude the registries, namespace, or specific pods

#### Registry

Registries can be excluded by adding the full registry name in the below section of the `config_values.yaml` ( without transport i.e. `http(s)://`)

1. **Helm Chart Values** : If you are installing IAR on a cluster that is running a lot of pods and would like to exclude images from specific registry(s) from IAR scanning then use the `exclusions.registry` param in your `config_values.yaml` for IAR and set the value to be a comma separate list of registries that need to be excluded
   e.g.
  ```
  exclusions:
    registry: "index.docker.io,my.private.registry,localhost,localhost:1234"
  ```

#### Namespace
Namespaces can be excluded in two ways:

1. **Helm Chart Values** : If you are installing IAR on a cluster that is running a lot of pods and would like to exclude them from IAR scanning then use the `exclusions.namespace` param in your `config_values.yaml` for IAR and set the value to be a comma separate list of namespaces that needs to be excluded
   e.g.
  ```
  exclusions:
    namespace: "ns1,ns2"
  ```

2. **Annotations**: Once the IAR has been installed, any new namespace can be excluded by adding the below annotation to the target namespace spec
   `sensor.crowdstrike.com/imageanalyzer: "disabled"`

e.g.
```
apiVersion: v1
kind: Namespace
metadata:
  name: "my-newnamespace-to-be-excluded"
  annotations:
    sensor.crowdstrike.com/imageanalyzer: "disabled"
```

#### POD Exclusions via PodSpec

For excluding a specific pod from IAR scanning, one can add the below annotation on pod spec or pod annotation in their own target deployment, daemonset, cron spec.
`sensor.crowdstrike.com/imageanalyzer: "disabled"`


1. **PodSpec**
```
apiVersion: v1
kind: Pod
metadata:
  namespace: default
  name: my-pod-spec
  labels:
    app: my-app
  annotations:
    sensor.crowdstrike.com/imageanalyzer: "disabled"
spec:
  containers:
    - image: myappimage:x.y.z
    ....
```

2. **Deployment / Daemonset**
```
apiVersion: apps/v1
kind: Deployment / Daemonset
metadata:
  name: myapp
  namespace: mynamespace
  
spec:
  replicas: 1
  template:
    metadata:
      annotations:
        sensor.crowdstrike.com/imageanalyzer: "disabled"
      labels:
        app: myapp
    spec:
      containers:
      .....
```

## Uninstall Helm chart

To uninstall, run the following command:
```
helm uninstall imageanalyzer -n falcon-image-analyzer && kubectl delete namespace falcon-image-analyzer
```
