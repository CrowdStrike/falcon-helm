# CrowdStrike Self-hosted Registry Assessment (SHRA) Helm Chart 

[Falcon](https://www.crowdstrike.com/) is the [CrowdStrike](https://www.crowdstrike.com/)
platform purpose-built to stop breaches via a unified set of cloud-delivered
technologies.

This Helm Chart helps you deploy CrowdStrike's Self-hosted Registry Assessment tool (SHRA) to create inventories of the container images in your registries. The software sends the inventories to the CrowdStrike cloud where they are analyzed for vulnerabilities and reported in your Falcon console. With SHRA, your images stay in your environment. This approach is an alternative to CrowdStrike's cloud-based [Cloud Workload Protection](https://www.crowdstrike.com/platform/cloud-security/cwpp/) registry assessment options, where images are copied into the CrowdStrike registry to create the image inventories. 

Choosing to use the self-hosted approach vs CrowdStrike's cloud-based Cloud Workload Protection solution has a cost implication.
For example, running these services in your environment requires additional storage and computing time.
These costs may or may not be offset by the savings for data egress costs incurred with the cloud-based Cloud Workload Protection solution. 

## Table of Contents

- [CrowdStrike Self-hosted Registry Assessment (SHRA) Helm Chart](#crowdstrike-self-hosted-registry-assessment-shra-helm-chart)
  - [Table of Contents](#table-of-contents)
  - [Supported registries](#supported-registries)
  - [How it works](#how-it-works)
    - [How SHRA determines if an image is new](#how-shra-determines-if-an-image-is-new)
  - [Kubernetes cluster compatibility](#kubernetes-cluster-compatibility)
  - [Requirements](#requirements)
  - [Create a basic config file](#create-a-basic-config-file)
  - [Customize your deployment](#customize-your-deployment)
    - [Create the SHRA namespace](#create-the-shra-namespace)
    - [Configure your CrowdStrike credentials](#configure-your-crowdstrike-credentials)
    - [Copy the SHRA images to your registry](#copy-the-shra-images-to-your-registry)
      - [Download the Falcon sensor pull script](#download-the-falcon-sensor-pull-script)
      - [List available images](#list-available-images)
      - [Copy the SHRA images to your registry](#copy-the-shra-images-to-your-registry-1)
      - [Prepare credentials for your registry](#prepare-credentials-for-your-registry)
      - [Add registry and image details to the configuration](#add-registry-and-image-details-to-the-configuration)
    - [Configure which registries to scan](#configure-which-registries-to-scan)
      - [Amazon Elastic Container Registry (AWS ECR)](#amazon-elastic-container-registry-aws-ecr)
      - [Azure Container Registry](#azure-container-registry)
      - [Docker Hub](#docker-hub)
      - [Docker Registry V2](#docker-registry-v2)
      - [GitHub](#github)
      - [GitLab](#gitlab)
      - [Google Artifact Registry (GAR)](#google-artifact-registry-gar)
      - [Google Container Registry (GCR)](#google-container-registry-gcr)
      - [Harbor](#harbor)
        - [IBM Cloud Registry](#ibm-cloud-registry)
      - [Jfrog Artifactory](#jfrog-artifactory)
      - [Mirantis Secure Registry (MCR)](#mirantis-secure-registry-mcr)
      - [Oracle Container Registry](#oracle-container-registry)
      - [Red Hat OpenShift](#red-hat-openshift)
      - [Red Hat Quay.io](#red-hat-quayio)
      - [Sonatype Nexus](#sonatype-nexus)
      - [Validate the credentials locally](#validate-the-credentials-locally)
      - [Apply your changes to the configuration file](#apply-your-changes-to-the-configuration-file)
    - [Configure your scanning schedules](#configure-your-scanning-schedules)
    - [Optional. Configure which repositories to scan](#optional-configure-which-repositories-to-scan)
    - [Configure persistent data storage](#configure-persistent-data-storage)
      - [Change persistent storage retention](#change-persistent-storage-retention)
    - [Configure temporary storage](#configure-temporary-storage)
    - [Configure SHRA scaling to meet your scanning needs](#configure-shra-scaling-to-meet-your-scanning-needs)
    - [Allow traffic to CrowdStrike servers](#allow-traffic-to-crowdstrike-servers)
    - [Optional. Configure CrowdStrike allow list](#optional-configure-crowdstrike-allow-list)
    - [Optional. Configure gRPC over TLS](#optional-configure-grpc-over-tls)
      - [Option 1. Enable gRPC TLS with Cert Manager](#option-1-enable-grpc-tls-with-cert-manager)
      - [Option 2. Enable gRPC TLS with custom secret](#option-2-enable-grpc-tls-with-custom-secret)
      - [Option 3. Enable gRPC TLS with custom certificate files](#option-3-enable-grpc-tls-with-custom-certificate-files)
    - [Optional. Configure HTTP Proxy](#optional-configure-http-proxy)
  - [Forward SHRA Container Logs to LogScale](#forward-shra-container-logs-to-logscale)
    - [Configure SHRA log levels](#configure-shra-log-levels)
    - [Create the HEC Ingest Connector](#create-the-hec-ingest-connector)
    - [Start the Kubernetes LogScale Collector in your SHRA namespace](#start-the-kubernetes-logscale-collector-in-your-shra-namespace)
      - [Review logs in the UI](#review-logs-in-the-ui)
    - [Configure saved searches to monitor SHRA](#configure-saved-searches-to-monitor-shra)
  - [Install the SHRA Helm Chart](#install-the-shra-helm-chart)
  - [Update SHRA](#update-shra)
  - [Uninstall SHRA](#uninstall-shra)
  - [Falcon Chart configuration options](#falcon-chart-configuration-options)

## Supported registries

* Amazon Elastic Container Registry (AWS ECR)
* Azure Container Registry
* Docker Hub
* Docker Registry V2
* GitHub
* GitLab
* Google Artifact Registry (GAR)
* Google Container Registry (GCR)
* Harbor
* IBM Cloud
* JFrog Artifactory
* Mirantis Secure Registry (MSR)
* Oracle Container Registry
* Red Hat OpenShift
* Red Hat Quay.io
* Sonatype Nexus

## How it works

The following architecture diagram gives you insight into how SHRA works. 

* Following our [configuration instructions](#customize-your-deployment), you create a `values_override.yaml` file specific to your environment, including:
  * Your CrowdStrike identification and credentials.
  * The container registry where you have placed the two SHRA images.
  * The container registries you want SHRA to scan for new images, and how often to scan them.
  * How SHRA should configure its persistent and temporary storage.
  
* You run the Helm install command. As the Helm Chart deploys SHRA:
  * The jobs database and registry assessment cache are initialized in persistent storage.
  * The **Jobs Controller** Pod spins up.
  * One or more **Executor** Pods spin up.

* Per your configured schedule, the Jobs Controller tells one or more Executors which registries to scan. The Executors break up the work as follows:
   * `Registry scan`: identifies the repositories within your configured registries
   * `Repository scan`: identifies image tags within the repositories
   * `Tag assessment`: downloads, uncompresses, and inventories new images, then sends the inventories to CrowdStrike's cloud for analysis

* The CrowdStrike cloud assesses the image inventories to determine their potential vulnerabilities. Results are visible in the Falcon console. 
  * Go to [**Cloud security > Vulnerabilities > Image assessments**](https://falcon.crowdstrike.com/cloud-security/cwpp/image-assessment/images), then click the **Images** tab. 
Images scanned by SHRA have **Self-hosted registry** in the optional **Sources** column.

![High level diagram showing the architecture and deployment for the Falcon Self-hosted Registry Assessment tool (SHRA). It depicts a user installing SHRA via the Helm Chart files and a values_override.yaml file. SHRA's two images, the Jobs Controller and Executor, and three related persistent volume claims are created inside the namespace falcon-self-hosted-registry-assessment. Arrows depict the flow of new image inventories from the Executor's tag assessment component to the CrowdStrike cloud, where analysis results are visible to the user via the Falcon console.](self-hosted-registry-assessment-flow.jpg "Self-hosted Registry Assessment")

> [!TIP]  
> Performance of the `Registry scan` and `Repository scan` jobs are networking bound, for the most part. 
> By contrast, the `Tag assessment` job is mainly constrained by the amount of available disk space to unpack the images and perform the inventory. 
> Ensure you provide sufficient disk space. For more information, see Configure temporary storage.

### How SHRA determines if an image is new

To streamline work, the Executor's `Tag assessment` process uses a local registry assessment database to keep track of image tags previously scanned. 
If an image tag is not found in the local database, it asks the CrowdStrike cloud if the image is new. 
Only images that have not been inventoried before are unpacked and inventoried.

## Kubernetes cluster compatibility

The Falcon Self-hosted Registry Scanner Helm Chart has been tested to deploy on the following Kubernetes distributions:

* Amazon Elastic Kubernetes Service (EKS) - EKS and EKS Fargate
* Azure Kubernetes Service (AKS)
* Google Kubernetes Engine (GKE)
* SUSE Rancher K3s
* Red Hat OpenShift Kubernetes

## Requirements

* Access to the Falcon console with one or more of these default roles:
  * Falcon Administrator
  * Cloud Security Manager
  * Kubernetes and Containers Manager
* A client API key, as described in the configuration steps.
* A x86_64 (AMD64) Kubernetes cluster.
* [Helm](https://helm.sh/) 3.x is installed and supported by the Kubernetes provider.
* A 1+ GiB persistent volume for a job controller sqlite database. 
* A 1+ GiB persistent volume used by the executor for a registry assessment cache.
* A working volume to store and expand images for assessment.
* Networking sufficient to communicate with CrowdStrike cloud services and your image registries.
* Optional. [Cert Manager - Helm](https://cert-manager.io/docs/installation/helm/) if you wish to use TLS between the containers in this Chart. See [TLS Configuration](#optional-configure-grpc-over-tls).

> [!NOTE]  
> For more information on SHRA's persistent and temporary storage needs, see [Configure persistent data storage](#configure-persistent-data-storage) and [Configure temporary storage](#configure-temporary-storage).

## Create a basic config file

Before you install this Helm Chart, there are several config values to customize for your specific use case.

To start, copy the following code block into a new file called `values_override.yaml`.
Follow the steps in [Customize your deployment](#customize-your-deployment) to configure these values.

> [!TIP]  
> If you have experience deploying other CrowdStrike Helm Charts, you can refer to [Falcon Chart configuration options](#falcon-chart-configuration-options) for details on how to customize the fields in this minimal installation example. 

```yaml
crowdstrikeConfig:
  clientID: ""
  clientSecret: ""
  
executor:
  image:
    registry: ""
    repository: ""
    tag: ""

  dbStorage:
    storageClass: ""

  assessmentStorage:
    type: "PVC"
    pvc:
      storageClass: ""

jobController:
  image:
    registry: ""
    repository: ""
    tag: ""

  dbStorage:
    storageClass: ""

registryConfigs:
  - type: dockerhub
    credentials:
      username: ""
      password: ""
    allowedRepositories: ""
    port: "443"
    host: "https://registry-1.docker.io"
    cronSchedule: "* * * * *"
  - type: dockerhub
    credentials:
      username: ""
      password: ""
    allowedRepositories: ""
    port: "443"
    host: "https://registry-2.docker.io"
    cronSchedule: "0 0 * * *"
```

Continue to tailor this file for your environment by following the remaining steps in this guide.

## Customize your deployment

Configure your deployment of the Self-hosted Registry Assessment tool by preparing a namespace for SHRA and adding your configuration details to your `values_override.yaml` file.

> [!IMPORTANT]
> Deployment of SHRA deployment with Helm isn’t complicated, but there are several detailed steps and some must happen in sequence. 
> We strongly recommend that you follow these steps, in order, from top to bottom.

The most commonly used parameters are described in the steps below. 
For other options, refer to the [full set of configurations options](#falcon-chart-configuration-options) and the comments in provided `values.yaml`.

### Create the SHRA namespace

Create a namespace to use for deploying SHRA, storing Kubernetes secrets, and hosting optional utilities throughout the installation process.

We recommend the namespace `falcon-self-hosted-registry-assessment`, and we use that namespace throughout these instructions.

1. Create the namespace:
   ``` sh
   kubectl create namespace falcon-self-hosted-registry-assessment
   ```
1. As needed to meet your security requirements, create Kubernetes Roles and/or RoleBindings for this namespace and apply them. 
   The SHRA Pods don't interact with the Kubernetes APIs and don't need any specific Kubernetes permissions, so only default access is needed.
   For more information, see [Kubernetes documentation on RBAC authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/).

### Configure your CrowdStrike credentials 

To download and operate CrowdStrike's self-hosted registry assessment tool, you need a CrowdStrike API client ID and secret with the required API scopes.

Create your client ID and secret: 
1. In the Falcon console, go to [**Support and resources** > **Resources and tools** > **API clients and keys**](https://falcon.crowdstrike.com/api-clients-and-keys/).
1. Click **Add new API client**.
1. In the **Add new API client** dialog, enter a client name and description that identify this key is for self-hosted registry assessment.
1. Set the following API scopes
   * **Falcon Container CLI**: Write
   * **Falcon Container Image**: Read/Write
   * **Falcon Images Download**: Read
   * **Sensor Download**: Read  
1. Click **Add**.
1. From the **API client created** dialog, copy the **client ID** and **secret** to a password management or secret management service. 

> [!NOTE]  
> The API client secret will not be presented again, so don't close the dialog until you have this value safely saved. 

Export these variables for use in later steps:
```sh
export FALCON_CLIENT_ID=<your-falcon-api-client-id>
export FALCON_CLIENT_SECRET=<your-falcon-api-client-secret>
```

In your `values_override.yaml` file, set `crowdstrikeConfig.clientID` and `crowdstrikeConfig.clientSecret` to the values you saved in `FALCON_CLIENT_ID` and `FALCON_CLIENT_SECRET`.

For example, 
```yaml
crowdstrikeConfig:
  clientID: "aabbccddee112233445566aabbccddee"
  clientSecret: "aabbccddee112233445566aabbccddee11223344"
```

| Parameter                           |           | Description                                                                                           | Default   |
|:------------------------------------|-----------|:------------------------------------------------------------------------------------------------------|:----------|
| `crowdstrikeConfig.clientID`        | required  | The client id used to authenticate the self-hosted registry assessment service with CrowdStrike.      | ""        |
| `crowdstrikeConfig.clientSecret`    | required  | The client secret used to authenticate the self-hosted registry assessment service with CrowdStrike.  | ""        |
| `crowdstrikeConfig.clientSecretRef` | optional  | Refernce to a secret which contains `clientID` (`CLIENT_ID`) and `clientSecret` (`CLIENT_SECRET`).  | ""

### Copy the SHRA images to your registry

To strengthen your container supply chain security and maintain security best practices, we recommend you deploy the SHRA containers from your private registry.

The two OCI images you need are:
- `falcon-jobcontroller`: The job controller manages scheduling and coordination.
- `falcon-registryassessmentexecutor`: The executor finds and inventories new images to scan. 

There are a few ways to get the available image tags, including the [Falcon sensor pull script](https://github.com/CrowdStrike/falcon-scripts/tree/main/bash/containers/falcon-container-sensor-pull) and tools like [skopeo](https://github.com/containers/skopeo). 
These instructions use the Falcon sensor pull script.

**What you'll do**:
- Download the Falcon sensor pull script
- List available images
- Copy your selected SHRA container image versions to your private registry
- Add your registry URL and authentication info to your `values_override.yaml` file.

The following steps guide you through the image copy process.

#### Download the Falcon sensor pull script

Get the latest version of our Falcon sensor pull script from our [GitHub repo](https://github.com/CrowdStrike/falcon-scripts/tree/main/bash/containers/falcon-container-sensor-pull).

1. Download the Falcon sensor pull script:
   ```
   curl -sSL -o falcon-container-sensor-pull.sh "https://raw.githubusercontent.com/CrowdStrike/falcon-scripts/main/bash/containers/falcon-container-sensor-pull/falcon-container-sensor-pull.sh"
   ```
1. Make the local script executable:
   ```
   chmod u+x ./falcon-container-sensor-pull.sh
   ```

#### List available images

These steps use the environment variables `FALCON_CLIENT_ID` and `FALCON_CLIENT_SECRET` set in earlier steps. 
If you're in a new terminal window or if running the commands below causes authentication errors, repeat the variable exports described in [Configure your CrowdStrike credentials](#configure-your-crowdstrike-credentials).

1. Use the pull script to fetch the image tags for the SHRA job controller image to see available tag versions:
   ```
   ./falcon-container-sensor-pull.sh \
     --client-id ${FALCON_CLIENT_ID} \
     --client-secret ${FALCON_CLIENT_SECRET} \
     --list-tags \
     --type falcon-jobcontroller
   ```
   You can expect output similar to this:
   ```
   {
   "name": "falcon-jobcontroller",
   "repository": "registry.crowdstrike.com/falcon-selfhostedregistryassessment/release/falcon-jobcontroller",
   "tags": [
      "1.0.0",
      "1.0.1"
   ]
   }
   ```

1. Repeat the process for the executor image:
   ```
   ./falcon-container-sensor-pull.sh \
   --client-id ${FALCON_CLIENT_ID} \
   --client-secret ${FALCON_CLIENT_SECRET} \
   --list-tags \
   --type falcon-registryassessmentexecutor
   ```
   You can expect output similar to this:
   ```
   {
   "name": "falcon-registryassessmentexecutor",
   "repository": "registry.crowdstrike.com/falcon-selfhostedregistryassessment/release/falcon-registryassessmentexecutor",
   "tags": [
      "1.0.0",
      "1.0.1",
      "1.0.2"
   ]
   }
   ```

1. Make a note of the latest image tag for both the executor and job-controller images. 
   For example, in the sample output, the latest tags are `1.0.1` for falcon-jobcontroller and `1.0.2` for falcon-registryassessmentexecutor.

> [!TIP]
> For stronger matching, we recommend using digests instead of tags to identify images. 
> Use a tool like [skopeo](https://github.com/containers/skopeo) to discover available SHRA image digests.
> If needed, use the Falcon sensor pull script’s `--dump-credentials` option to retrieve your CrowdStrike registry credentials.

#### Copy the SHRA images to your registry

Copy the SHRA's `falcon-jobcontroller` and `falcon-registryassessmentexecutor` images from the CrowdStrike registry and store them in your private registry.

> [!NOTE]  
> These steps assume that:
>   * you're authenticated to your target registry and have authorization to push new images
>   * following our directions, you have set the required environment variables 

1. Create new environment variables for your chosen versions of the two SHRA images. 
   Replace `1.0.0` with the image tag you want to fetch.
   ```sh
   export FALCON_SHRA_JC_VERSION="1.0.0"
   export FALCON_SHRA_EX_VERSION="1.0.0"
   ```

1. Set an environment variable with the URL for your private registry, where you'll store these images. 
   We recommend using `falcon-selfhostedregistryassessment` in your repository name. 
   Adjust this sample with your registry's URL and to match your repository naming scheme. 
   ```sh
   export MY_SHRA_REPO=<your-registry-url>/falcon-selfhostedregistryassessment
   ```

1. Use the Falcon sensor pull script to copy the SHRA job controller image to your registry:
   ```
   ./falcon-container-sensor-pull.sh \
   --client-id ${FALCON_CLIENT_ID} \
   --client-secret ${FALCON_CLIENT_SECRET} \
   --copy ${MY_SHRA_REPO}/falcon-jobcontroller \
   --type falcon-jobcontroller \
   --version ${FALCON_SHRA_JC_VERSION}
   ```

1. Repeat the process for the executor image:
   ```
   ./falcon-container-sensor-pull.sh \
   --client-id ${FALCON_CLIENT_ID} \
   --client-secret ${FALCON_CLIENT_SECRET} \
   --copy ${MY_SHRA_REPO}/falcon-registryassessmentexecutor \
   --type falcon-registryassessmentexecutor \
   --version ${FALCON_SHRA_EX_VERSION}
   ```

1. Optional. Verify the copy was successful. Use `skopeo list`, `docker pull`, or `docker images` commands to verify that the SHRA images are accessible now from your registry.

Follow the next step to prepare your registry credentials. Then, add your registry url, repository paths, image versions, and credentials to `values_override.yaml` file. 
For more info, see [Add registry and image details to the configuration](#add-registry-and-image-details-to-the-configuration).

#### Prepare credentials for your registry

The Helm Chart installation process requires authentication to your registry to download the SHRA images for deployment.

You have two options for providing registry credentials:

* **Option 1:** Use the following command to get a base64 encoded version of your Docker authentication string (modify as needed if your credentials are not located at ~/.docker/config.json):
   ``` sh
   cat ~/.docker/config.json | base64
   ```
   In the next step, use the resulting value to configure `executor.image.registryConfigJSON` and `jobController.image.registryConfigJSON`.

* **Option 2:** Create a Kubernetes imagePullSecret with your credentials in the `falcon-self-hosted-registry-assessment` namespace. 
   Follow the Kubernetes instructions to [create your imagePullSecret](https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod).
   In the next step, use your pullSecret's name to configure `executor.image.pullSecret` and `jobController.image.pullSecret`.

#### Add registry and image details to the configuration

Now that you've gathered the necessary information, verify and adjust image registry location, version tags, and authentication data in your `values_override.yaml` file. 

For example, using a pullSecret for authentication to the registry:
```yaml
executor:
  image:
    registry: "myregistry.example.com/falcon-selfhostedregistryassessment"
    repository: "falcon-registryassessmentexecutor"
    tag: "1.0.0"
    pullSecret: "my-reg-credentials"

jobController:
  image:
    registry: "myregistry.example.com/falcon-selfhostedregistryassessment"
    repository: "falcon-jobcontroller"
    tag: "1.0.0"
    pullSecret: "my-reg-credentials"
```

| Parameter                                |                                         | Description                                                                                                                                      | Default                              |
|:-----------------------------------------|:----------------------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------|
| `executor.image.registry`                |required                                 | The registry to pull the `executor` image from. We recommend that you store this image in your registry.                                         |                                      |
| `executor.image.repository`              |                                         | The repository for the `executor` image file.                                                                                                    | "falcon-registryassessmentexecutor"  |
| `executor.image.digest`                  |required or `executor.image.tag`         | The sha256 digest designating the `executor` image to pull. This value overrides the `executor.image.tag` field.                                 | ""                                   |
| `executor.image.tag`                     |required or `executor.image.digest`      | Tag designating the `executor` image to pull. Ignored if `executor.image.digest` is supplied. We recommend use of `digest` instead of `tag`.     | ""                                   |
| `executor.image.pullPolicy`              |                                         | Policy for determining when to pull the `executor` image.                                                                                        | "IfNotPresent"                       |
| `executor.image.pullSecret`              |                                         | Use this to specify an existing secret in the `falcon-self-hosted-registry-assessment` namespace.                                                | ""                                   |
| `executor.image.registryConfigJSON`      |                                         | The base64 encoded Docker secret for your private registry.                                                                                      | ""                                   |
| `jobController.image.registry`           |required                                 | The registry to pull the `job-controller` image from. We recommend that you store this image in your registry.                                   | ""                                   |
| `jobController.image.repository`         |                                         | The repository for the `job-controller` image.                                                                                                   | "falcon-jobcontroller"               |
| `jobController.image.digest`             |required or `jobController.image.tag`    | The sha256 digest for the `job-controller` image to pull. This value overrides the `jobController.image.tag` field.                              | ""                                   |
| `jobController.image.tag`                |required or `jobController.image.digest` | Tag for the `job-controller` image to pull. Ignored if `jobController.image.digest` is supplied. We recommend use of `digest` instead of `tag`.  | ""                                   |
| `jobController.image.pullPolicy`         |                                         | Policy for determining when to pull the `job-controller` image.                                                                                  | "IfNotPresent"                       |
| `jobController.image.pullSecret`         |                                         | Use this to specify an existing secret in the `falcon-self-hosted-registry-assessment` namespace                                                 | ""                                   |
| `jobController.image.registryConfigJSON` |                                         | The base64 encoded Docker secret for your private registry.                                                                                      | ""                                   |

### Configure which registries to scan

The Self-hosted Registry Assessment tool watches one or more registries.
When multiple registries are configured, jobs are scheduled round robin to balance between them.

Find your registry type(s) in the sections below for configuration instructions, including authentication requirements and any additional required fields. 

* [Amazon Elastic Container Registry (AWS ECR)](#amazon-elastic-container-registry-aws-ecr)
* [Azure Container Registry](#azure-container-registry)
* [Docker Hub](#docker-hub)
* [Docker Registry V2](#docker-registry-v2)
* [GitLab](#gitlab)
* [Github](#github)
* [Google Artifact Registry](#google-artifact-registry-gar)
* [Google Container Registry](#google-container-registry-gcr)
* [Harbor](#harbor)
* [IBM Cloud Registry](#ibm-cloud-registry)
* [JFrog Artifactory](#jfrog-artifactory)
* [Mirantis Secure Registry (MCR)](#mirantis-secure-registry-mcr)
* [Oracle Container Registry](#oracle-container-registry)
* [Red Hat Openshift](#red-hat-openshift)
* [Red Hat Quay.io](#red-hat-quayio)
* [Sonatype Nexus](#sonatype-nexus)

For each registry you want to add, create an entry in the `registryConfigs` array in your `values_override.yaml` file.
Be sure to specify the correct `type` field for your registry so SHRA knows how to connect to it. 

> [!TIP]
> For registry types with username and password authentication, we recommend Kubernetes secrets instead of plaintext passwords.
> We support two [Kubernetes secret types](https://kubernetes.io/docs/concepts/configuration/secret/#secret-types): [`dockercfg`](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret_docker-registry/) and [`dockerconfigjson`](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry).
> 1. Create your named secrets in the `falcon-self-hosted-registry-assessment` namespace.
> 1. In your `values_override.yaml` file, replace the `username` and `password` parameters with `kubernetesSecretName` and `kubernetesSecretNamespace` (both are required).

#### Amazon Elastic Container Registry (AWS ECR)

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

Notes:
* To access ECR, the host needs either direct access or the ability to assume an IAM role with appropriate permissions for the ECR registry.
* If role assumption is needed to retrieve ECR tokens, supply both `credentials.aws_iam_role` and `credentials.aws_external_id`. 
  Ensure the roles have a trust-relationship configured to allow the service account access to the resources in the SHRA namespace (the default namespace used in these setup instructions is `falcon-self-hosted-registry-assessment`).
  For additional information on IAM Roles, refer to the [AWS documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user.html).

```yaml
 - type: ecr
   credentials:
    aws_iam_role: ""
    aws_external_id: ""
   allowedRepositories: ""
   port: "443"
   host: ""
   cronSchedule: "0 0 * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Azure Container Registry

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

```yaml
  - type: acr
    credentials:
      username: ""
      password: ""
    allowedRepositories: ""
    port: "443"
    host: ""
    cronSchedule: "0 0 * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Docker Hub

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

```yaml
  - type: dockerhub
    credentials:
      username: ""
      password: ""
    allowedRepositories: ""
    host: "https://registry-1.docker.io"
    cronSchedule: "0 0 * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Docker Registry V2

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

```yaml
  - type: basic
    credentials:
      username: ""
      password: ""
    allowedRepositories: ""
    port: ""
    host: ""
    cronSchedule: "0 0 * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### GitHub

Copy this registry configuration to your `values_override.yaml` file and provide the required information. 

* `domain_url` and `host` should both be the fully qualified domain name of your Githab installation. The values provided in the example below are for Github cloud. 

```yaml
  - type: github
    credentials:
      username: ""
      domain_url: "https://api.github.com"
      password: ""
    allowedRepositories: ""
    port: "443"
    host: "https://ghcr.io"
    cronSchedule: "0 0 * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### GitLab

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

Notes:
* `domain_url` and `host` should both be the fully qualified domain name of your GitLab installation

```yaml
  - type: gitlab
    credentials:
      username: ""
      password: ""
      domain_url: ""
    allowedRepositories: ""
    port: ""
    host: ""
    cronSchedule: "0 0 * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Google Artifact Registry (GAR)

Authentication to Google Artifact Registry (GAR) requires a private key. To get your private key:

1. In your [GCP console](https://console.cloud.google.com/getting-started?pli=1), navigate to **IAM & Admin > Service accounts**.
1. Click **Create Service Account**.
1. Specify a service account name, grant it the following roles, then click **Done**.
    * **Artifact Registry Reader**
    * **Storage Object Viewer**
1. Within the service accounts table, locate the newly created service account, click the **actions icon**, and select **Manage Keys**.
1. Click the **Keys** tab.
1. Click the **Add key** dropdown and select **Create new key**.
1. Ensure **JSON** is selected and click **Create**. This downloads the newly created service account key in JSON format. Use it to populate the `service_account_json` fields below.

Copy this registry configuration to your `values_override.yaml` file and provide the required information.
Notes:
* Configure `host` with the region subdomain or multi-region associated with your GAR account. Find the regional or multi-regional information in the **location** column of the repository list in your GAR account.
    * https://<region>-docker.pkg.dev/ (for regional) or 
    * https://<multi-region>-docker.pkg.dev/ (for multi-regional)
* Set `scope_name` to the OAuth 2.0 style scope associated with the project ID. For example, `https://www.googleapis.com/auth/cloud-platform`. For more info, see [Google's documentation](https://cloud.google.com/compute/docs/access/service-accounts#accesscopesiam).

```yaml
  - type: gar
    credentials:
      scope_name: ""
      project_id: ""
      service_account_json:
        type: "service_account"
        project_id: ""
        private_key_id: ""
        private_key: ""
        client_email: ""
    allowedRepositories: ""
    port: "443"
    host: ""
    cronSchedule: "* * * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Google Container Registry (GCR)

Authentication to Google Container Registry (GCR) requires a private key. To get your private key:

1. In your [GCP console](https://console.cloud.google.com/getting-started?pli=1), navigate to **IAM & Admin > Service accounts**.
1. Click **Create Service Account**.
1. Specify a service account name, grant it the following role, then click **Done**.
    * **Storage Object Viewer**
1. Within the service accounts table, locate the newly created service account, click the **actions icon**, and select **Manage Keys**.
1. Click the **Keys** tab.
1. Click the **Add key** dropdown and select **Create new key**.
1. Ensure **JSON** is selected and click **Create**. This downloads the newly created service account key in JSON format. Use it to populate the `service_account_json` fields below.

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

Notes:
* Set host to one of the two following values. Substitute [REGION] with your GCR account's subdomain region (for example us). You can find the hostname URL in your GCR image list.
    * https://gcr.io/ or 
    * https://[REGION].gcr.io/
* Set `service_account_email` to the same value as `client_email`.

```yaml
  - type: gcr
    credentials:
      project_id: ""
      service_account_json:
        type: "service_account"
        project_id: ""
        private_key_id: ""
        private_key: ""
        client_email: ""
        service_account_email: ""
    allowedRepositories: ""
    port: "443"
    host: ""
    cronSchedule: "0 0 * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Harbor

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

Notes:
* Set both `domain_url` and `host` to the fully qualified domain name of your Harbor installation.


```yaml
  - type: harbor
    credentials:
      username: ""
      password: ""
      domain_url: ""
    allowedRepositories: ""
    port: ""
    host: ""
    cronSchedule: "* * * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

##### IBM Cloud Registry

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

Notes:
* Set both `host` and `credentials.domain_url` to:
    * https://icr.io (for global) or 
    * https://<region-key>.icr.io (for regional)

```yaml
  - type: icr
    credentials:
      username: ""
      domain_url: ""
      password: ""
    allowedRepositories: ""
    port: "443"
    host: ""
    cronSchedule: "0 0 * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Jfrog Artifactory

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

```yaml
  - type: artifactory
    credentials:
      username: ""
      password: ""
    allowedRepositories: ""
    port: ""
    host: ""
    cronSchedule: "0 0 * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Mirantis Secure Registry (MCR)

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

```yaml
  - type: mirantis
    credentials:
      username: ""
      password: ""
    allowedRepositories: ""
    port: ""
    host: ""
    cronSchedule: "* * * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Oracle Container Registry

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

Notes:
* For `username` use the format `tenancy-namespace/user`.
* You may need to provide `credentials.compartment_ids`. In the Oracle console, go to **Identity & Security**. Under Identity, click **Compartments**. This shows the list of compartments in your tenancy. 
Hover over the **OICD** column to copy the compartment ID that you want to register. If provided, there should be a single value in the list of compartment ids, use that value for this field.
* When using `compartment_ids`, the `credentials.scope_name` is required.

```yaml
  - type: oracle
    credentials:
      username: ""
      password: ""
      compartment_ids: [""]
      scope_name: ""
    allowedRepositories: ""
    port: "443"
    host: "https://us-phoenix-1.ocir.io"
    cronSchedule: "0 0 * * *"
    credential_type: "oracle"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Red Hat OpenShift

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

```yaml
  - type: openshift
    credentials:
      username: ""
      password: ""
    allowedRepositories: ""
    port: ""
    host: ""
    cronSchedule: "* * * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Red Hat Quay.io
Copy this registry configuration to your `values_override.yaml` file and provide the required information.

Notes:
- For `username` use the format `<organization_name>+<robot_account_name>`
- Set `domain_url` and `host` to the same value. For the cloud-hosted solution, use `https://quay.io`. Otherwise, provide the domain of your self hosted quay installation.

```yaml
  - type: quay.io
    credentials:
      username: ""
      password: ""
      domain_url: ""
    allowedRepositories: ""
    port: "443"
    host: ""
    cronSchedule: "* * * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Sonatype Nexus

Copy this registry configuration to your `values_override.yaml` file and provide the required information.

```yaml
  - type: nexus
    credentials:
      username: ""
      password: ""
    allowedRepositories: ""
    host: ""
    cronSchedule: "0 0 * * *"
```
Continue to add additional registries, or proceed to [Validate your registry credentials locally](#validate-the-credentials-locally).

#### Validate the credentials locally

The docker API spec notably lacks details on authentication; as such each registry implements authentication and access controls slightly differently. 
It is highly recommended that you test the credentials you plan to use with SHRA. 
Use the command line to validate that your credentials have the appropriate authorization to scan registries, list tags, and pull images. 

```sh
DOCKER_USERNAME=<your docker username for login>
DOCKER_PASSWORD=<your docker password for login>
REGISTRY=<your registry host>
```

Validate that you can login. The following command should return **Login Succeeded**
```sh
echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME $REGISTRY --password-stdin
```

Validate that you can list tags for a known repository. The following command should list the tags for a given repository.
```sh
REPOSITORY=<known repository name within the registry>
skopeo list-tags --creds $DOCKER_USERNAME:$DOCKER_PASSWORD docker://$REGISTRY/$REPOSITORY
```

Validate that you can pull one of the tags within the repository. The following command should pull the image down to your local machine.
```sh
TAG=<known tag from the above skopeo list-tags command>
docker pull $REGISTRY/$REPOSITORY:$TAG
```

If any of these validation tests returns an unexpected result, double-check your credentials and verify that you have the correct authorization. 
If you're not able to authenticate to the registry and pull images with these credentials, neither can SHRA.

#### Apply your changes to the configuration file

Now that you've gathered the necessary information for your private registries, verify and adjust the following parameters in your `values_override.yaml` file.

| Parameter                                                 |                                                      | Description                                                                                                             | Default |
|:----------------------------------------------------------|:-----------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------|:--------|
| `registryConfigs.*.type`                                  | required                                             | The registry type being assessed. See [Supported registries](#supported-registries) for options.                        | ""      |
| `registryConfigs.*.credentials.username`                  | required without `kubernetesSecretName`              | The username used to authenticate to the registry.                                                                      | ""      |
| `registryConfigs.*.credentials.password`                  | required without `kubernetesSecretName`              | The password used to authenticate to the registry.                                                                      | ""      |
| `registryConfigs.*.credentials.kubernetesSecretName`      | required with `kubernetesSecretNamespace`            | The Kubernetes secret name that contains registry credentials. The [secret type](https://kubernetes.io/docs/concepts/configuration/secret/#secret-types) must be a [kubernetes.io/dockercfg](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret_docker-registry/) or a kubernetes.io/dockerconfigjson type secret.                                                         | ""      |
| `registryConfigs.*.credentials.kubernetesSecretNamespace` | required with `kubernetesSecretName`                 | The namespace containing the Kubernetes secret with credentials.                                                        | ""      |
| `registryConfigs.*.port`                                  |                                                      | The port for connecting to the registry. Unless you specify a value here, SHRA uses port 80 for http and 443 for https. | ""      |
| `registryConfigs.*.host`                                  | required                                             | The host for connecting to the registry.                                                                                | ""      |


### Configure your scanning schedules

You configure how often you want SHRA to scan each of your configured registries. 
Specify your schedule as a unix-cron string in the `registryConfigs.*.cronSchedule` parameter for each registryConfigs section of your `values_override.yaml` file.

For example, if you have two dockerhub registries, the first with a weekly scan schedule and the second with a daily scan schedule:

```yaml 
registryConfigs:
  - type: dockerhub
    credentials:
      username: "myuser"
      password: "xxxyyyzzz"
    allowedRepositories: ""
    port: "5000"
    host: "https://registry-1.docker.io"
    cronSchedule: "0 0 * * 6"
  - type: dockerhub
    credentials:
      username: "anotheruser"
      password: "qqqrrrsss"
    allowedRepositories: ""
    port: "5000"
    host: "https://registry-2.docker.io"
    cronSchedule: "0 0 * * *"
```

A unix-cron schedule is defined with the string format "* * * * *". 
This set of 5 fields indicate when a job should be executed. A quick overview of the fields is:

```
|--------------------------- Minute (0-59)
|    |---------------------- Hour (0-23)
|    |    |----------------- Day of the month (1-31)
|    |    |    |------------ Month (1-12)
|    |    |    |    |------- Day of the week (0-6 where 0 is Monday; or MON-SUN)
|    |    |    |    |
|    |    |    |    |
*    *    *    *    *
```

In addition to the definitions above, unix-cron schedules permit various modifiers including:
* Match all possible values for a field with an asterisk (*)
* Specify ranges with a dash (-)
* Specify steps with a forward slash (/) 

Here are some common examples:
| `registryConfigs.*.cronSchedule` setting | Scanning schedule                             |
|:-----------------------------------------|:----------------------------------------------|
| `"* * * * *"`                            | Every minute.                                 |
| `"*/5 * * * *"`                          | Every 5 minutes.                              |
| `"0 * * * *"`                            | Every hour, at the top of the hour.           |
| `"0 17 * * *"`                           | Daily, at 17:00h / 5:00 pm.                   |
| `"0 0 * * 6"`                            | Weekly, Sundays at midnight.                  |
| `"0 2 15 * *"`                           | Every 15th of the month, at 2:00 am.          |
| `"0 */2 * * MON-FRI"`                    | Every 2 hours, Monday through Friday.         |

> [!NOTE]  
> If you schedule the scans for a registry too closely and the previous scan is still running when it's time for the next scan, the in-progress scan continues and the upcoming scan is skipped. 

| Parameter                                                 |                                                      | Description                                                                                                             | Default |
|:----------------------------------------------------------|:-----------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------|:--------|
| `registryConfigs.*.cronSchedule`                          | required                                             | A cron schedule that controls how often the top level registry collection job is created.                               | ""      |

### Optional. Configure which repositories to scan

By default, SHRA scans all repositories in your configured registries. 
However, you can tailor SHRA with a repository allowlist to limit scanning to specific repositories within a registry.
This reduces the overall scan load and limits the results to the repositories that are important to you.

To create a list of allowed repositories within a registry, add a comma-separated list of repository names to the `registryConfigs.*.allowedRepositories` parameter. 
This restricts SHRA to scan only the repositories you specify, rather than scanning all repositories in the registry.

For example, your configuration might look like this:

```yaml
registryConfigs:
  - type: dockerhub
    credentials:
      username: "myuser"
      password: "xxxyyyzzz"
    allowedRepositories: "myapp,my/other/app,mytestrepo"
    port: "5000"
    host: "https://registry-1.docker.io"
    cronSchedule: "0 0 * * *"
```

In this example, SHRA onlys scans the myapp, my/other/app, and mytestrepo repositories in the specified dockerhub registry.
All other repositories in this registry are excluded from the scans.

> [!NOTE]  
> The `allowedRepositories` parameter doesn't support wildcard characters or regex matches.
> You must provide a comma-separated list of the specific repository names you want to include.

> [!TIP]
> If SHRA is already deployed when you change your `allowedRepositories` list, or make any other change to your `values_override.yaml` file, redeploy the Helm Chart. 
> For more info, see [Update SHRA](#update-shra).

| Parameter                                                 |       | Description                                                                                                                                                  | Default |
|:----------------------------------------------------------|:------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------|
| `registryConfigs.*.allowedRepositories`                   |       | A comma separated list of repositories to assess. No regex or wildcard support. If this value is not set, all repositories within the registry are assessed. | ""      |

### Configure persistent data storage

SHRA needs 2 persistent volume claims (PVC) for SQLite databases that allow the service to be resilient to down time and upgrades. 

The executor and job controller databases created in the PVCs start small and grow with usage, accumulating job and image information respectively.
We recommend a **minimum of 1 gibibyte of storage** for each database. This size accommodates approximately 2 million image scans. 

If you have multiple registries, or wish to scan registries faster, we recommend you increase the executor database volume size.
You can also adjust job controller retention periods to reduce the footprint of the jobs database.
See [Change persistent storage retention](#change-persistent-storage-retention) for details.

You have 2 options for SHRA's persistent data storage:
* New persistent volume claims are created
* You provide existing storage claim names

> [!IMPORTANT]  
> At deployment, SHRA tries to create the required storage claims. 
> However, since each Kubernetes installation uses different storage classes, SHRA cannot offer default storage classes that work universally. 
> **Your deployment will fail unless you configure the storage class type or specify names to existing storage claims.** 

To configure existing storage claim names, set `executor.dbStorage.storageClass` and/or `jobController.dbStorage.storageClass` to `false` and configure the matching `*dbStorage.existingClaimName` with your storage class name.
See an example in the snippet below.

To instead have new persistent volume claims created, configure executor and job controller storage class types that match your Kubernetes runtime and installation.
The following table lists storage class options for SHRA's supported runtimes.
Use these values to configure `executor.dbStorage.storageClass` and `jobController.dbStorage.storageClass` in your `values_override.yaml` file.

| Runtime                      | CSI Volume Driver                    | Default storage class name | Storage provider documentation                                                                                               |
|------------------------------|--------------------------------------|----------------------------|------------------------------------------------------------------------------------------------------------------------------|
| EKS                          | EBS                                  | ebs-sc                     | https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html                                                                |
| EKS                          | EFS                                  | efs-sc                     | https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html                                                                |
| AKS                          | Standard SSD LRS                     | managed-csi                | https://learn.microsoft.com/en-us/azure/aks/concepts-storage#storage-classes                                                 |
| AKS                          | Azure Standard storage               | azurefile-csi              | https://learn.microsoft.com/en-us/azure/aks/concepts-storage#storage-classes                                                 |
| GKE                          | Compute Engine persistent disk       | standard                   | https://cloud.google.com/kubernetes-engine/docs/concepts/persistent-volumes#storageclasses                                   |
| K3s                          | Local Storage Provider               | local-path                 | https://docs.k3s.io/storage#setting-up-the-local-storage-provider                                                            |
| Red Hat OpenShift Kubernetes | Depends on underlying infrastructure | varies, see link           | https://docs.openshift.com/container-platform/4.16/storage/container_storage_interface/persistent-storage-csi-sc-manage.html |

The following snippet shows how to use an existing storage claim for `executor.dbStorage` while allowing the container to create its own storage for `jobController.dbStorage`.

```yaml
executor:
  dbStorage:
    create: false
    existingClaimName: falcon-executor-db
    accessModes:
      - "ReadWriteOnce"
    storageClass: 

jobController:
  dbStorage:
    create: true
    existingClaimName: ""
    storageClass: "ebs-sc"
    size: 1Gi
    accessModes:
      - ReadWriteOnce
```

Add and adjust the following lines in your `values_override.yaml` file to configure your persistent storage. 

| Parameter                                    |         | Description                                                                                                                                               | Default              |
|:---------------------------------------------|:--------|:----------------------------------------------------------------------------------------------------------------------------------------------------------|:---------------------|
| `executor.dbStorage.create`                  |required | `true` to create a persistent volume claim (PVC) storage for the executor's db cache file. `false` to use existing storage.                               | true                 |
| `executor.dbStorage.existingClaimName`       |         | Name of existing storage to use instead of creating one. Required if `executor.dbStorage.create` is `false`.                                              | ""                   |
| `executor.dbStorage.size`                    |         | Size of the storage claim to create for the executor's database.                                                                                          | "1Gi"                |
| `executor.dbStorage.accessModes`             |         | Array of access modes for the executor's database claim.                                                                                                  | "- ReadWriteOnce"    |
| `executor.dbStorage.storageClass`            |required | Storage class to use when creating a persistent volume claim for the `executor` db cache. Examples include "ebs-sc" in AKS and "standard" in GKE.         | ""                   |
| `jobController.dbStorage.create`             |required | `true` to create a persistent volume (PVC) storage for the job controller sqlite database file.                                                           | true                 |
| `jobController.dbStorage.existingClaimName`  |         | Name of existing storage to use instead of creating one. Required if `jobController.dbStorage.create` is `false`.                                         | ""                   |
| `jobController.dbStorage.size`               |         | Size of the storage claim to create for the job controller's database.                                                                                    | "1Gi"                |
| `jobController.dbStorage.accessModes`        |         | Array of access modes for the job controller's database claim.                                                                                            | "- ReadWriteOnce"    |
| `jobController.dbStorage.storageClass`       |required | Storage class to use when creating a persistent volume claim for the job controller database. Examples include "ebs-sc" in AKS and "standard" in GKE.     | ""                   |

#### Change persistent storage retention

To reduce the footprint of the `job controller` database, you can adjust data retention periods for each of the three main jobs it schedules for `executor`.

Retention for each of the three job types is 604800 seconds (7 days) unless you specify a different value when deploying the Helm Chart.
Be aware that a longer retention period may be helpful to facilitate debugging any potential registry assessment issues.

To change the default data retention for these job types, add or replace the following values in your `values_override.yaml` file.

| Parameter                                                               |         | Description                                                                           | Default   |
|:------------------------------------------------------------------------|:--------|:--------------------------------------------------------------------------------------|:----------|
| `crowdstrikeConfig.jobTypeConfigs.registryCollection.jobRetentionMax`   |         | Time in seconds to retain a registry scan job before deleting.                        | 604800    |
| `crowdstrikeConfig.jobTypeConfigs.tagScrape.jobRetentionMax`            |         | Time in seconds to retain a repository scan / tag scrape job before deleting.         | 604800    |
| `crowdstrikeConfig.jobTypeConfigs.tagAssessment.jobRetentionMax`        |         | Time in seconds to retain a completed tag assessment job before deleting.             | 604800    |


### Configure temporary storage

The self-hosted registry scanner pulls and decompresses each image it scans to traverse through layers, image configs, and manifests. 
To do this, it needs some scratch disk space. 

The size of this storage is important because if you provide too little storage it can be a significant bottleneck for processing images.
**The minimum recommended size for this mount is 3x the size of your largest compressed image.**
Larger volume mounts allow for image scanning concurrency and faster results.

The self-hosted scanner is forced to skip images that are too large to copy, unpack, and assess in the allocated storage space.

You have 3 options for SHRA's temporary data storage:
* A new Persistent Volume Claim, created during deployment
* You provide an existing storage claim name
* A new temp emptyDir, created during deployment

Persistent Volume Claim is the default storage type and is recommended if your storage provider supports dynamic creation of storage volumes. 

> [!IMPORTANT]  
> At deployment, SHRA will try to create a Persistent Volume Claim. 
> However, since each Kubernetes installation uses different storage classes, SHRA cannot offer a default storage class that works universally. 
> **Your deployment will fail unless you configure the storage class type, specify `local` for an emptyDir, or specify the name of an existing storage claim.**

To use an existing storage claim, set `executor.assessmentStorage.pvc.create` to `false` and configure `executor.assessmentStorage.pvc.existingClaimName` with your storage class name.

To have a new emptyDir created, set `executor.assessmentStorage.type` to `local` and if your deployment needs more than the default 100 gibibytes of storage, set the emptyDir size in `executor.assessmentStorage.size`. 

To have a new persistent volume claim created, configure `executor.assessmentStorage.pvc.storageClass` with a value from the table of storage class options for SHRA's supported runtimes in [Configure persistent data storage](#configure-persistent-data-storage).
If your deployment needs more than the default 100 gibibytes of storage, set the PVC size in `executor.assessmentStorage.size`. 

Configure your temporary storage location by editing the following lines to your `values_override.yaml` file. 

| Parameter                                           |             |Description                                                                                                                                                                                                                                               | Default           |
|:----------------------------------------------------|------------:|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:------------------|
| `executor.assessmentStorage.type`                   |required     | The type of storage volume to use for downloading and unpacking images. One of `local` or `PVC`. `local` creates an emptyDir mount. `PVC` creates a persistent volume claim. Ignored if `executor.assessmentStorage.pvc.existingClaimName` is provided.  | "PVC"             |
| `executor.assessmentStorage.size`                   |             | Size of claim to create. Required when the `assessmentStorage.type` is `PVC`. Setting this too small causes issues including skipped image assesments. Min recommended size is 3x your largest compressed image.                                         | "100Gi"           |
| `executor.assessmentStorage.pvc.create`             |             | If `true`, creates the persistent volume claim for assessment storage. Default setting is to create a PVC unless you modify the config.                                                                                                                  | true              |
| `executor.assessmentStorage.pvc.existingClaimName`  |             | An existing storage claim name you wish to use instead of the one created above. Required if `executor.assessmentStorage.pvc.create` is false.                                                                                                           | ""                |
| `executor.assessmentStorage.pvc.storageClass`       |required     | Storage class to use when creating a persistent volume claim for the assessment storage. Examples include "ebs-sc" in AKS and "standard" in GKE.                                                                                                         | ""                |
| `executor.assessmentStorage.pvc.accessModes`        |             | Array of access modes for this database claim.                                                                                                                                                                                                           | "- ReadWriteOnce" |

### Configure SHRA scaling to meet your scanning needs

We've tailored our Helm chart with performant default values to suit the majority of situations.
However, you can still scale your cluster to handle more throughput by adjusting the number of Executor Pods running.

Each Executor Pod can inventory approximately 100 images per hour, assuming an average image size of 1 GB. 

To increase or decrease the number of Executor Pods, edit the `executor.replicaCount` values in your `values_override.yaml` file. 

| Parameter                    |             |Description                                                                                                                  | Default     |
|:-----------------------------|------------:|:----------------------------------------------------------------------------------------------------------------------------|:------------|
| `executor.replicaCount`      |             | The number of Executor Pods. This value can be increased for greater concurrency if CPU is the bottleneck.                  | 1           |

<!-- markdown-link-check-disable -->
### Allow traffic to CrowdStrike servers

SHRA requires internet access to your assigned CrowdStrike authenication API and upload servers. 
If your network requires it, configure your allow lists with your assigned CrowdStrike cloud servers.  

| Region | Authentication API | Upload Servers |   
|:----:|:--:|:--:| 
| US-1 | https://api.crowdstrike.com | https://container-upload.us-1.crowdstrike.com |
| US-2 | https://api.us-2.crowdstrike.com | https://container-upload.us-2.crowdstrike.com |
| EU-1 | https://api.eu-1.crowdstrike.com | https://container-upload.eu-1.crowdstrike.com |
| US-GOV-1 | https://api.laggar.gcw.crowdstrike.com | https://container-upload.laggar.gcw.crowdstrike.com |
| US-GOV-2 | https://api.us-gov-2.crowdstrike.mil | https://container-upload.us-gov-2.crowdstrike.mil |
<!-- markdown-link-check-enable -->

### Optional. Configure CrowdStrike allow list

By default, API access to your CrowdStrike account is not limited by IP address. 
However, we offer the option to restrict access by IP addresses or ranges to ensure your account is only accessed from specific networks.

Note that if your account is already IP address restricted, requests from other IPs (including the one where you're deploying SHRA) will be denied access and result in the error `HTTP 403 "Access denied, authorization failed"`.

To protect your account, or add your SHRA IP details to the CrowdStrike allow list for your CID, see [IP Allowlist Management](https://falcon.crowdstrike.com/documentation/page/a80757b1/ip-allowlist-management).

### Optional. Configure gRPC over TLS

The Job Controller and Executor Pods communicate with one another over gRPC. 
If you wish, you can configure TLS for communication between these Pods with either [cert-manager](https://cert-manager.io/) or your own certificate files. 

To enable TLS (regardless of the option you choose) add the following line to your `values_override.yaml` file, then follow the steps below.

| Parameter                                   | | Description                                                                                                                             | Default     |
|:--------------------------------------------|-|:----------------------------------------------------------------------------------------------------------------------------------------|:------------|
| `tls.enable`                                | | Set to `true` to enforce TLS communication between the Executor Pods and job-controller as they communicate job information over gRPC.  | false       |

See [full `values.yaml` configuration options](#falcon-chart-configuration-options) for complete TLS configuration.

#### Option 1. Enable gRPC TLS with Cert Manager

Cert-manager is a native Kubernetes certificate management controller. 
It can help automate certificate management in cloud-native environments.

Add the Jetstack Helm repository:

```sh
helm repo add jetstack https://charts.jetstack.io --force-update
```
Install cert-manager with Helm:

```sh
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.15.2 \
  --set crds.enabled=true
```

Add the following line to your `values_override.yaml` file.

| Parameter                                 |   | Description                                                                                                                         | Default     |
|:------------------------------------------|---|:------------------------------------------------------------------------------------------------------------------------------------|:------------| 
| `tls.useCertManager`                      |   | When `tls.enable` is set to true, this field determines if cert manager should be used to create and control certificates.          | true        |

#### Option 2. Enable gRPC TLS with custom secret

If you have an existing certificate as a Kubernetes secret you wish to use for these Pods, provide them as the `tls.existingSecret`.

| Parameter                                 |   | Description                                                                                                    | Default     |
|:------------------------------------------|---|:---------------------------------------------------------------------------------------------------------------|:------------|
| `tls.existingSecret`                      |   | Specify an existing Kubernetes secret instead of cert manager.                                                 | ""          |

#### Option 3. Enable gRPC TLS with custom certificate files

If you have existing certificate files you wish to use for these Pods, provide them as the `tls.issuer`.

| Parameter                                 |   | Description                                                                                                    | Default     |
|:------------------------------------------|---|:---------------------------------------------------------------------------------------------------------------|:------------|
| `tls.issuer`                              |   | Reference to an existing cert manager Issuer or ClusterIssuer, used for creating the TLS certificates.         | {}          |

### Optional. Configure HTTP Proxy

If needed, you can route HTTP traffic through a proxy for your registry connections and/or CrowdStrike connections.
There are three environment variables you can set for the executor by configuring `proxyConfig` in your `values_override.yaml` file:

| Parameter                                 |   | Description                                                                                                   | Default     |
|:------------------------------------------|---|:--------------------------------------------------------------------------------------------------------------|:------------|
| `proxyConfig.HTTP_PROXY`                  |   | Proxy URL for HTTP requests unless overridden by NO_PROXY.                                                    | ""          |
| `proxyConfig.HTTPS_PROXY`                 |   | Proxy URL for HTTPS requests unless overridden by NO_PROXY.                                                   | ""          |
| `proxyConfig.NO_PROXY`                    |   | Hosts to exclude from proxying. Provide as a string of comma-separated values.                                | ""          |

## Forward SHRA Container Logs to LogScale

[Falcon LogScale](https://www.crowdstrike.com/platform/next-gen-siem/falcon-logscale/) is part of CrowdStrike's Next-Gen SIEM for central log management. 
The LogScale Kubernetes Collector can be deployed in the SHRA namespace within Kubernetes for forwarding log messages from the applications used in registry assessment. 

By forwarding logs from the SHRA up to LogScale, you can more easily monitor and alert on the health of your registry assessments. 

Setting up this log collector is optional, but highly recommended. 
The best time to set up the log collector is before you deploy the Helm Chart.
Your SHRA container logs are important diagnostic and troubleshooting tools.

> [!NOTE]
> The SHRA logs collected through LogScale count towards your daily third-party data ingestion limit. 
> To optimize data collection and avoid exceeding this limit, you can adjust SHRA's default logging level. See instructions below. 
> For more details on managing your data ingestion and understanding limits,  see About Falcon Next-Gen SIEM.

Configure LogScale by completing the following tasks:
* Optional. Set the SHRA default log levels
* Create the HEC Ingest Connector
* Start the Kubernetes LogScale Collector in your SHRA namespace
* Review logs in the UI
* Configure saved searches to monitor SHRA

> [!NOTE]  
> If you need assistance with SHRA deployment or ongoing activity with your self-hosted registry scans, CrowdStrike will request that you add the log collector to your installation.

### Configure SHRA log levels

SHRA logs at the info level (3) by default. You can adjust this to optimize your data collection:
* Error (1): Captures critical issues only
* Warning (2): Includes errors and potential problems
* Info (3): Adds general operational information
* Debug (4): Provides detailed diagnostic data

Each level includes all previous levels. For example, level 2 captures both warning and error logs.

In your `values_override.yaml` file, set `executor.logLevel` and `jobController.logLevel` to your chosen log levels. 
We recommend warn level (2) for both executor and job controller. 
```yaml
executor:
  logLevel: 2
jobController:
  logLevel: 2
```

| Parameter                  |   | Description                                                                                                   | Default     |
|:---------------------------|---|:--------------------------------------------------------------------------------------------------------------|:------------|
| `executor.logLevel`        |   | Log level for the executor service (1:error, 2:warning, 3:info, 4:debug).                                                    | ""          |
| `jobController.logLevel`   |   | Log level for the job controller service (1:error, 2:warning, 3:info, 4:debug).                                                  | ""          |


### Create the HEC Ingest Connector

The Kubernetes Collector sends logs over HTTP.
Therefore, the first step is to create a Data Connector in the Falcon console, configured to accept HTTP Event Connector (HEC) source logs. 
Perform the following steps to set up your Data Collector. 
If neeeded, see our complete documentation on [setup and configuration of the HEC Data Connector](https://falcon.crowdstrike.com/documentation/page/bdded008/hec-http-event-connector-guide). 

1. In the Falcon console go to go to [**Next-Gen SIEM** > **Data sources**](https://falcon.crowdstrike.com/data-connectors/).
2. Select **HEC / HTTP Event Connector**.
3. On the **Add new connector** page, fill the following fields:
   * **Data details**:
     * **Data source**: `<Provide a name such as Self-hosted Registry Assessment Containers>`
     * **Data type**: `JSON`
   * **Connector details**:
     * **Connector name**: `<Provide a name such as SHRA Log Connector>`
     * **Description**: `<Provide a description such as Logs to use for monitoring and alerts>`
   * **Parser details**: `json (Generic Source)`
4. Agree to the terms for third party data sources and click **Save**.
5. When the connector is created and ready to receive data, a message box appears at the top of the screen. 
Click **Generate API key**. 
6. From the **Connection setup** dialog, copy the **API key** and **API URL** to a password management or secret management service. 

   Modify the API URL by removing `/services/collector` from the end. Your value will look like: `https://123abc.ingest.us-1.crowdstrike.com` where the first subdomain (`123abc` in this example) is specific to your connector.

> [!IMPORTANT]  
> The API Key will not be presented again, so don't close the dialog until you have it safely saved. 

7. Export these variables for use in later steps:
   ```sh
   export LOGSCALE_URL=<your-logscale-api-url without /services/collector>
   export LOGSCALE_KEY=<your-logscale-key>
   ```

### Start the Kubernetes LogScale Collector in your SHRA namespace

LogScale provides a [Kubernetes Log Collector](https://library.humio.com/falcon-logscale-collector/log-collector-kubernetes-helm-config.html) that can be configured with Helm. 

1. Create a secret for your LogScale API key within Kubernetes.
   ```sh
   kubectl create secret generic logscale-collector-token \
         --from-literal=ingestToken=${LOGSCALE_KEY} \
         --namespace falcon-self-hosted-registry-assessment
   ```

1. Add the LogScale Helm repository.
   ```sh
   helm repo add logscale-collector-helm https://registry.crowdstrike.com/log-collector-us1-prod 
   ```

1. Install the collector in your SHRA namespace. 
   ```sh
   helm install -g logscale-collector-helm/logscale-collector \
         --create-namespace \
         --namespace falcon-self-hosted-registry-assessment \
         --set humioAddress=${LOGSCALE_URL},humioIngestTokenSecretName=logscale-collector-token
   ```

#### Review logs in the UI

The LogScale Collector should now be shipping logs to LogScale within the Falcon console. 

To verify that the Connector is receiving data:
1. From the Falcon console go to go to [**Data connectors** > **My connectors**](https://falcon.crowdstrike.com/data-connectors/connectors).
1. In the list, find the connector you created and check its status. If it's receiving data, the status is **Active**.

To view the logs from this connector:
1. Go to [**Next-Gen SEIM** > **Log management ** > **Advanced event search**](https://falcon.crowdstrike.com/investigate/search?end=&query=kubernetes.namespace%20%3D%20%22falcon-self-hosted-registry-assessment%22&repo=all&start=30m).  
1. Filter by the Kubernetes namespace by adding the following to the query box (adjust if you chose a different namespace)
   `kubernetes.namespace = "falcon-self-hosted-registry-assessment"`. 
1. Keep this window open to monitor for results. Click **Run** once SHRA is installed.

### Configure saved searches to monitor SHRA

Now that your SHRA logs are ingested by LogScale, you can configure scheduled searches to be notified of any issues your SHRA may have in connecting to registries or performing assessment. 

1. Go to [**Next-Gen SEIM** > **Log management ** > **Advanced event search**](https://falcon.crowdstrike.com/investigate/search?end=&query=kubernetes.namespace%20%3D%20%22falcon-self-hosted-registry-assessment%22&repo=all&start=30m).  

1. Modify the query to search for errors. We recommend the following broad search filter:

   ```
   kubernetes.namespace = "falcon-self-hosted-registry-assessment" @source=PlatformEvents @error=true
   ```

1. Follow our NG-SEIM instuctions to [Schedule your search](https://falcon.crowdstrike.com/documentation/page/a4275adf/scheduled-searches-for-edr). You'll be notified when any issues arise that you need to correct regarding registry connections. 


## Install the SHRA Helm Chart

Before you install, follow the configuration steps above to prepare your accounts and create a `values_override.yaml` file with your customizations.

1. Add the CrowdStrike Falcon Helm repository.

   ```sh
   helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
   ```

1. Update the local Helm repository cache.

   ```sh
   helm repo update
   ```

1. Install the Chart, using your configuration file to specify all the variables.

   ```sh
   helm upgrade --install -f </path/to/values_override.yaml> \
         --create-namespace \
         --namespace falcon-self-hosted-registry-assessment \
         --wait \
         falcon-shra \
         crowdstrike/falcon-self-hosted-registry-assessment
   ```

   For more details, see the [falcon-helm](https://github.com/CrowdStrike/falcon-helm) repository.

1. Verify your installation.

   ```sh
   helm show values crowdstrike/falcon-self-hosted-registry-assessment
   ```

The job controller and executor are now live, and the first registry scans will begin according to your configured cron schedules associated with each registry.
For more information on setting your scanning schedule, see [Configure your scanning schedules](#configure-your-scanning-schedules).

## Update SHRA

As needed, you can change your configuration values or replace the SHRA container images with new releases.

After making changes to your `values_override.yaml` file, use the `helm upgrade` command shown in [Install the SHRA Helm Chart](#install-the-shra-helm-chart).

## Uninstall SHRA

To uninstall, run the following command:
```sh
helm uninstall falcon-shra --namespace falcon-self-hosted-registry-assessment \
      && kubectl delete namespace falcon-self-hosted-registry-assessment
```

## Falcon Chart configuration options
The Chart's `values.yaml` file includes more comments and descriptions in-line for additional configuration options.

| Parameter                                                                      |                                          | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Default                      |
|:-------------------------------------------------------------------------------|:-----------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:-----------------------------|
| `nameOverride`                                                                 |                                          | override generated name for k8bernetes labels                                                                                                                                                                                                                                                                                                                                                                                                                    | ""                           |
| `fullnameOverride`                                                             |                                          | override generated name prefix for deployed Kubernetes objects                                                                                                                                                                                                                                                                                                                                                                                                   | ""                           |
| `executor.replicaCount`                                                        |                                          | The number of executor pods. This value can be increased for greater concurrency if CPU is the bottleneck.                                                                                                                                                                                                                                                                                                                                                       | 1                            |
| `executor.image.registry`                                                      | required                                 | The registry to pull the executor image from. We recommend that you store this image in your registry. See [Copy the SHRA images to your Registry](#option-1-copy-the-shra-images-to-your-registry).                                                                                                                                                                                                                                                             | ""                           |
| `executor.image.repository`                                                    | required                                 | The repository for the executor image file.                                                                                                                                                                                                                                                                                                                                                                                                                      | "falcon-registryassessmentexecutor" |
| `executor.image.digest`                                                        | required or `executor.image.tag`         | The sha256 digest designating the executor image to pull. This value overrides the `executor.image.tag` field.                                                                                                                                                                                                                                                                                                                                                   | ""                           |
| `executor.image.tag`                                                           | required or `executor.image.digest`      | Tag designating the executor image to pull. Ignored if `executor.image.digest` is supplied. We recommend use of `digest` instead of `tag`.                                                                                                                                                                                                                                                                                                                       | ""                           |
| `executor.image.pullPolicy`                                                    |                                          | Policy for determining when to pull the executor image.                                                                                                                                                                                                                                                                                                                                                                                                          | "IfNotPresent"               |
| `executor.image.pullSecret`                                                    |                                          | Use this to specify an existing secret in the `falcon-self-hosted-registry-assessment` namespace.                                                                                                                                                                                                                                                                                                                                                                | ""                           |
| `executor.image.registryConfigJSON`                                            |                                          | The base64 encoded Docker secret for your private registry.                                                                                                                                                                                                                                                                                                                                                                                                      | ""                           |
| `executor.dbStorage.create`                                                    | required                                 | `true` to create a persistent volume claim (PVC) storage for the executor's db cache file. `false` to use existing storage.                                                                                                                                                                                                                                                                                                                                      | true                         |
| `executor.dbStorage.storageClass`                                              | required                                 | Storage class to use when creating a persistent volume claim for the `executor` db cache. Examples include "ebs-sc" in AKS and "standard" in GKE.                                                                                                                                                                                                                                                                                                                | ""                           |
| `executor.dbStorage.existingClaimName`                                         |                                          | Name of existing storage to use instead of creating one. Required if `executor.dbStorage.create` is `false`.                                                                                                                                                                                                                                                                                                                                                     | ""                           |
| `executor.dbStorage.size`                                                      |                                          | Size of the storage claim to create for the executor's database.                                                                                                                                                                                                                                                                                                                                                                                                 | "1Gi"                        |
| `executor.dbStorage.accessModes`                                               |                                          | Array of access modes for the executor's database claim.                                                                                                                                                                                                                                                                                                                                                                                                         | "- ReadWriteOnce"            |
| `executor.assessmentStorage.type`                                              | required                                 | The type of storage volume to use for downloading and unpacking images. One of `local` or `PVC`. `local` creates an emptyDir mount. `PVC` creates a persistent volume claim. Ignored if `executor.assessmentStorage.pvc.existingClaimName` is provided.                                                                                                                                                                                                          | "PVC"                        |
| `executor.assessmentStorage.size`                                              |                                          | Size of claim to create. Required when the `assessmentStorage.type` is `PVC`. Setting this too small causes issues including skipped image assesments. Min recommended size is 3x your largest compressed image. See [Configure temporary storage](#configure-temporary-storage).                                                                                                                                                                                | "100Gi"                      |
| `executor.assessmentStorage.pvc.create`                                        |                                          | If `true`, creates the persistent volume claim for assessment storage. Default setting is to create a PVC unless you modify the config.                                                                                                                                                                                                                                                                                                                          | true                         |
| `executor.assessmentStorage.pvc.existingClaimName`                             |                                          | An existing storage claim name you wish to use instead of the one created above. Required if `executor.assessmentStorage.pvc.create` is `false`.                                                                                                                                                                                                                                                                                                                 | ""                           |
| `executor.assessmentStorage.pvc.storageClass`                                  | required                                 | Storage class to use when creating a persistent volume claim for the assessment storage. Examples include "ebs-sc" in AKS and "standard" in GKE.                                                                                                                                                                                                                                                                                                                 | ""                           |
| `executor.assessmentStorage.pvc.accessModes`                                   |                                          | Array of access modes for the assessment storage volume claim.                                                                                                                                                                                                                                                                                                                                                                                                   | "- ReadWriteOnce"            |
| `executor.logLevel`                                                            |                                          | Log level for the `executor` service (1:error, 2:warning, 3:info, 4:debug)                                                                                                                                                                                                                                                                                                                                                                                       | 3                            |
| `executor.labels`                                                              |                                          | Additional labels to apply to the executor pods.                                                                                                                                                                                                                                                                                                                                                                                                                 | {}                           |
| `executor.podAnnotations`                                                      |                                          | Additional pod annotations to apply to the executor pods.                                                                                                                                                                                                                                                                                                                                                                                                        | {}                           |
| `executor.nodeSelector`                                                        |                                          | Node selector to apply to the executor pods.                                                                                                                                                                                                                                                                                                                                                                                                                     | {}                           |
| `executor.resources`                                                           |                                          | Resource limits and requests to set for the executor pods.                                                                                                                                                                                                                                                                                                                                                                                                       | {}                           |
| `executor.tolerations`                                                         |                                          | Kubernetes pod scheduling tolerations.                                                                                                                                                                                                                                                                                                                                                                                                                           | []                           |
| `executor.affinity`                                                            |                                          | Node affinity for the executor pods.                                                                                                                                                                                                                                                                                                                                                                                                                             | []                           |
| `executor.priorityClassName`                                                   |                                          | Set to system-node-critical or system-cluster-critical to avoid pod evictions due to resource limits.                                                                                                                                                                                                                                                                                                                                                            | ""                           |
| `executor.additionalEnv`                                                       |                                          | Additional environment variables to set for the executor pods.                                                                                                                                                                                                                                                                                                                                                                                                   | []                           |
| `executor.additionalCMEEnvFrom`                                                |                                          | Additional environment variables set from an existing config map.                                                                                                                                                                                                                                                                                                                                                                                                | []                           |
| `executor.additionalSecretEnvFrom`                                             |                                          | Additional environment variables set from an existing secret.                                                                                                                                                                                                                                                                                                                                                                                                    | []                           |
| `jobController.image.registry`                                                 | required                                 | The registry to pull the job controller image from. We recommend that you store this image in your registry.                                                                                                                                                                                                                                                                                                                                                     | ""                           |
| `jobController.image.repository`                                               | required                                 | The repository for the job controller image.                                                                                                                                                                                                                                                                                                                                                                                                                     | "falcon-jobcontroller"       |
| `jobController.image.digest`                                                   | required or `jobController.image.tag`    | The sha256 digest for the job controller image to pull. This value overrides the `jobController.image.tag` field.                                                                                                                                                                                                                                                                                                                                                | ""                           |
| `jobController.image.tag`                                                      | required or `jobController.image.digest` | Tag designating the job controller image to pull. Ignored if `jobController.image.digest` is supplied. We recommend use of `digest` instead of `tag`.                                                                                                                                                                                                                                                                                                            | ""                           |
| `jobController.image.pullPolicy`                                               |                                          | Policy for determining when to pull the job controller image.                                                                                                                                                                                                                                                                                                                                                                                                    | "IfNotPresent"               |
| `jobController.image.pullSecret`                                               |                                          | Use this to specify an existing secret in the `falcon-self-hosted-registry-assessment` namespace.                                                                                                                                                                                                                                                                                                                                                                | ""                           |
| `jobController.image.registryConfigJSON`                                       |                                          | The base64 encoded Docker secret for your private registry.                                                                                                                                                                                                                                                                                                                                                                                                      | ""                           |
| `jobController.service.type`                                                   |                                          | Job Controller and Executor(s) communicate over IP via gRPC. This value sets the service type for executor(s) to communicate with Job Controller.                                                                                                                                                                                                                                                                                                                | "ClusterIP"                  |
| `jobController.service.port`                                                   |                                          | The port that job-controller uses for its gRPC server with the executor(s)                                                                                                                                                                                                                                                                                                                                                                                       | "9000"                       |
| `jobController.dbStorage.create`                                               | required                                 | `true` to create a persistent volume (PVC) storage for the job controller sqlite database file.                                                                                                                                                                                                                                                                                                                                                                  | true                         |
| `jobController.dbStorage.existingClaimName`                                    |                                          | Name of existing storage to use instead of creating one. Required if `jobController.dbStorage.create` is `false`.                                                                                                                                                                                                                                                                                                                                                | ""                           |
| `jobController.dbStorage.size`                                                 |                                          | Size of the storage claim to create for the job controller's database.                                                                                                                                                                                                                                                                                                                                                                                           | "1Gi"                        |
| `jobController.dbStorage.storageClass`                                         | required                                 | Storage class to use when creating a persistent volume claim for the job controller database. Examples include "ebs-sc" in AKS and "standard" in GKE.                                                                                                                                                                                                                                                                                                            | ""                           |
| `jobController.dbStorage.accessModes`                                          |                                          | Array of access modes for the job controller's database claim.                                                                                                                                                                                                                                                                                                                                                                                                   | "- ReadWriteOnce"            |
| `jobController.logLevel`                                                       |                                          | Log level for the job controller service (1:error, 2:warning, 3:info, 4:debug)                                                                                                                                                                                                                                                                                                                                                                                   | 3                            |
| `jobController.labels`                                                         |                                          | Additional labels to apply to the job-controller pod.                                                                                                                                                                                                                                                                                                                                                                                                            | {}                           |
| `jobController.podAnnotations`                                                 |                                          | Additional pod annotations to apply to the job-controller pod.                                                                                                                                                                                                                                                                                                                                                                                                   | {}                           |
| `jobController.nodeSelector`                                                   |                                          | Node selector to apply to the job-controller pod.                                                                                                                                                                                                                                                                                                                                                                                                                | {}                           |
| `jobController.resources`                                                      |                                          | Resource limits and requests to set for the job-controller pod.                                                                                                                                                                                                                                                                                                                                                                                                  | {}                           |
| `jobController.tolerations`                                                    |                                          | Kubernetes pod scheduling tolerations.                                                                                                                                                                                                                                                                                                                                                                                                                           | []                           |
| `jobController.affinity`                                                       |                                          | Node affinity for the job-controller pod.                                                                                                                                                                                                                                                                                                                                                                                                                        | []                           |
| `jobController.priorityClassName`                                              |                                          | Set to system-node-critical or system-cluster-critical to avoid pod evictions due to resource limits.                                                                                                                                                                                                                                                                                                                                                            | ""                           |
| `jobController.additionalEnv`                                                  |                                          | Additional environment variables to set for the job-controller pod.                                                                                                                                                                                                                                                                                                                                                                                              | []                           |
| `jobController.additionalCMEEnvFrom`                                           |                                          | Additional environment variables set from an existing config map.                                                                                                                                                                                                                                                                                                                                                                                                | []                           |
| `jobController.additionalSecretEnvFrom`                                        |                                          | Additional environment variables set from an existing secret.                                                                                                                                                                                                                                                                                                                                                                                                    | []                           |
| `crowdstrikeConfig.region`                                                     |                                          | The region for this CID in CrowdStrike's cloud. Valid values are "autodiscover", "us-1", "us-2", "eu-1", "gov1", and "gov2".                                                                                                                                                                                                                                                                                                                                     | "autodiscover"               |
| `crowdstrikeConfig.clientID`                                                   | required                                 | The client id used to authenticate the self-hosted registry assessment service with CrowdStrike.                                                                                                                                                                                                                                                                                                                                                                 | ""                           |
| `crowdstrikeConfig.clientSecret`                                               | required                                 | The client secret used to authenticate the self-hosted registry assessment service with CrowdStrike.                                                                                                                                                                                                                                                                                                                                                             | ""                           |
| `crowdstrikeConfig.jobTypeConfigs.registryCollection.threadsPerPod`            |                                          | The number of threads working on registry collection jobs. This job type is IO bound. Increasing this value allows collecting repositories from multiple registries concurrently. Increase this number if you have a significant number (100+) of registries.                                                                                                                                                                                                    | 1                            |
| `crowdstrikeConfig.jobTypeConfigs.registryCollection.allowConcurrentIdentical` |                                          | We strongly recommend you leave this set to the default `false`. Set to `true` to allow the same registry to be scraped by multiple worker threads simultaneously.                                                                                                                                                                                                                                                                                               | false                        |
| `crowdstrikeConfig.jobTypeConfigs.registryCollection.runtimeMax`               |                                          | The maximum amount of seconds an executor is allowed for scraping the list of repositories from a registry.                                                                                                                                                                                                                                                                                                                                                      | 480                          |
| `crowdstrikeConfig.jobTypeConfigs.registryCollection.retriesMax`               |                                          | The maximum number of attempts at scraping the list of repositories from a registry.                                                                                                                                                                                                                                                                                                                                                                             | 0                            |
| `crowdstrikeConfig.jobTypeConfigs.registryCollection.jobRetentionMax`          |                                          | Time in seconds to retain a registry scan job before deleting. Keeping these job records longer may facilitate debugging potential registry assessment issues.                                                                                                                                                                                                                                                                                                   | 604800                       |
| `crowdstrikeConfig.jobTypeConfigs.tagScrape.threadsPerPod`                     |                                          | The number of threads working on repository scrape jobs. This job is responsible for determining the tags associated with an individual repository. This job type is IO bound. Increasing this value allows scraping multiple repositories within the same registry concurrently. Increasing this number puts additional load on your registry with concurrent Docker API calls.                                                                                 | 1                            |
| `crowdstrikeConfig.jobTypeConfigs.tagScrape.allowConcurrentIdentical`          |                                          | We strongly recommend you leave this set to the default `false`. Set to `true`  to allow the same repository to be scraped by multiple worker threads simultaneously.                                                                                                                                                                                                                                                                                            | false                        |
| `crowdstrikeConfig.jobTypeConfigs.tagScrape.runtimeMax`                        |                                          | The maximum amount of seconds an executor is allowed for scraping the list of tags from a repository                                                                                                                                                                                                                                                                                                                                                             | 480                          |
| `crowdstrikeConfig.jobTypeConfigs.tagScrape.retriesMax`                        |                                          | The maximum number of attempts at scraping the list of tags from a repository                                                                                                                                                                                                                                                                                                                                                                                    | 0                            |
| `crowdstrikeConfig.jobTypeConfigs.tagScrape.jobRetentionMax`                   |                                          | Time in seconds to retain a repository scan / tag scrape job before deleting. Keeping these job records longer may facilitate debugging potential registry assessment issues.                                                                                                                                                                                                                                                                                    | 604800                       |
| `crowdstrikeConfig.jobTypeConfigs.tagAssessment.threadsPerPod`                 |                                          | The number of threads working on tag assessment jobs. This job is responsible downloading an image, unpacking it, and creating the inventory for what is in the image. This job type is IO and disk bound so increasing this allows concurrent image donwloading and unpacking. Increasing this number puts additional load on your registry with concurrent Docker API calls. See the `executor.assessmentStorage` settings to address disk bottlenecks.        | 8                            |
| `crowdstrikeConfig.jobTypeConfigs.tagAssessment.allowConcurrentIdentical`      |                                          | We strongly recommend you leave this set to the default `false`. Set to `true`  to allow the same image tag to be downloaded, unpacked and inventoried by multiple worker threads simultaneously.                                                                                                                                                                                                                                                                | false                        |
| `crowdstrikeConfig.jobTypeConfigs.tagAssessment.runtimeMax`                    |                                          | The maximum amount of seconds an executor is allowed for downloading, unpacking, creating an inventory and sending it to the cloud.                                                                                                                                                                                                                                                                                                                              | 480                          |
| `crowdstrikeConfig.jobTypeConfigs.tagAssessment.retriesMax`                    |                                          | The maximum number of attempts at assessing a tag image.                                                                                                                                                                                                                                                                                                                                                                                                         | 0                            |
| `crowdstrikeConfig.jobTypeConfigs.tagAssessment.jobRetentionMax`               |                                          | Time in seconds to retain a completed tag assessment job before deleting. Keeping these job records longer may facilitate debugging potential registry assessment issues.                                                                                                                                                                                                                                                                                        | 604800                       |
| `registryConfigs`                                                              |                                          | An array of registries to be assessed.                                                                                                                                                                                                                                                                                                                                                                                                                           | ""                           |
| `registryConfigs.*.type`                                                       |                                          | The registry type being assessed. See [Supported registries](#supported-registries) for options.                                                                                                                                                                                                                                                                                                                                                                 | ""                           |
| `registryConfigs.*.credentials.username`                                       | required without `kubernetesSecretName`  | The username used to authenticate to the registry.                                                                                                                                                                                                                                                                                                                                                                                                               | ""                           |
| `registryConfigs.*.credentials.password`                                       | required without `kubernetesSecretName`  | The password used to authenticate to the registry.                                                                                                                                                                                                                                                                                                                                                                                                               | ""                           |
| `registryConfigs.*.credentials.kubernetesSecretName`                           | required with `kubernetesSecretNamespace` | The Kubernetes secret name that contains registry credentials. [secret type](https://kubernetes.io/docs/concepts/configuration/secret/#secret-types) must be a [kubernetes.io/dockercfg](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret_docker-registry/) or a kubernetes.io/dockerconfigjson type secret.                                                                                                                                                                                                                                                                                                                                                                                                 | ""                           |
| `registryConfigs.*.credentials.kubernetesSecretNamespace`                      | required with `kubernetesSecretName`     | The namespace containing the Kubernetes secret with credentials.    | ""    |
| `registryConfigs.[*].credentials.aws_iam_role`        |   | Specify the assumed role, if any, when connectin to ECR.                 |         |
| `registryConfigs.[*].credentials.aws_external_id` |   | Specify the External ID for the connecting to the assumed role specified in `registryConfigs.[*].credentials.aws_iam_role` for the associated registry config. |         |
| `registryConfigs.*.port`                                                       |                                          | The port for connecting to the registry. Unless you specify a value here, SHRA uses port 80 for http and 443 for https.                                                                                                                                                                                                                                                                                                                                          | ""                           |
| `registryConfigs.*.allowedRepositories`                                        |                                          | A comma separated list of repositories to assess. No regex or wildcard support. If this value is not set, all repositories within the registry are assessed.                                                                                                                                                                                                                                                                                                     | ""                           |
| `registryConfigs.*.host`                                                       |                                          | The host for connecting to the registry.                                                                                                                                                                                                                                                                                                                                                                                                                         | ""                           |
| `registryConfigs.*.cronSchedule`                                               |                                          | A cron schedule that controls how often the top level registry collection job is created.                                                                                                                                                                                                                                                                                                                                                                        | ""                           |
| `tls.enable`                                                                   |                                          | Set to `true` to enforce TLS communication between the executor pods and job-controller as they communicate job information over gRPC.                                                                                                                                                                                                                                                                                                                           | false                        |
| `tls.useCertManager`                                                           |                                          | When `tls.enable` is `true`, this field determines if cert manager should be used to create and control certificates. See [tls configuration](#optional-configure-grpc-over-tls) for more information.                                                                                                                                                                                                                                                           | true                         |
| `tls.existingSecret`                                                           |                                          | Specify an existing Kubernetes secret instead of cert manager.                                                                                                                                                                                                                                                                                                                                                                                                   | ""                           |
| `tls.issuer`                                                                   |                                          | Reference to an existing cert manager Issuer or ClusterIssuer, used for creating the TLS certificates.                                                                                                                                                                                                                                                                                                                                                           | {}                           |
| `proxyConfig.HTTP_PROXY`                                                       |                                          | Proxy URL for HTTP requests unless overridden by NO_PROXY.                                                                                                                                                                                                                                                                                                                                                                                                       | ""                           |
| `proxyConfig.HTTPS_PROXY`                                                      |                                          | Proxy URL for HTTPS requests unless overridden by NO_PROXY.                                                                                                                                                                                                                                                                                                                                                                                                      | ""                           |
| `proxyConfig.NO_PROXY`                                                         |                                          | Hosts to exclude from proxying. Provide as a string of comma-separated values.                                                                                                                                                                                                                                                                                                                                                                                   | ""                           |
