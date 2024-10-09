# CrowdStrike Self-hosted Registry Assessment (SHRA) Helm Chart 

[Falcon](https://www.crowdstrike.com/) is the [CrowdStrike](https://www.crowdstrike.com/)
platform purpose-built to stop breaches via a unified set of cloud-delivered
technologies.

This Helm Chart helps you deploy CrowdStrike's self-hosted registry scanner to create inventories of the container images in your registries. The software sends the inventories up to the CrowdStrike cloud where they are analyzed for vulnerabilities and reported in your Falcon console. With this scanner, your images stay in your environment. This approach is an alternative to CrowdStrike's cloud-based [Cloud Workload Protection](https://www.crowdstrike.com/platform/cloud-security/cwpp/) registry assessment options, where images are copied into the CrowdStrike registry to create the image inventories. 

Choosing to use the self-hosted approach vs CrowdStrike's cloud-based Cloud Workload Protection solution has a cost implication.
For example, running these services in your environment requires additional storage and computing time.
These costs may or may not be offset by the savings for data egress costs incurred with the cloud-based Cloud Workload Protection solution. 

## Table of Contents

- [Supported registries](#supported-registries)
- [How it works](#how-it-works)
- [Kubernetes cluster compatibility](#kubernetes-cluster-compatibility)
- [Requirements](#requirements)
- [Create a basic config file](#create-a-basic-config-file)
- [Customize your deployment](#customize-your-deployment)
  - [Configure your CrowdStrike credentials](#configure-your-crowdstrike-credentials)
  - [Configure SHRA image download](#configure-shra-image-versions-and-download-registry)
  - [Configure which registries to scan](#configure-which-registries-to-scan-and-how-often-to-scan-them)
  - [Configure persistent data storage](#configure-persistent-data-storage)
  - [Configure temporary storage](#configure-temporary-storage)
  - [Allow traffic to CrowdStrike servers](#allow-traffic-to-crowdstrike-servers)
  - [Optional. Configure CrowdStrike allow list](#optional-configure-crowdstrike-allow-list)
  - [Optional. Configure gRPC over TLS](#optional-configure-grpc-over-tls)
  - [Optional. Configure HTPP Proxy](#optional-configure-http-proxy)
  - [Forward SHRA Container Logs to Logscale](#forward-shra-container-logs-to-logscale)
- [Install the SHRA Helm Chart](#install-the-shra-helm-chart)
- [Update SHRA](#update-shra)
- [Uninstall SHRA](#uninstall-shra)
- [Falcon Chart configuration options](#falcon-chart-configuration-options)

## Supported registries

* Amazon Elastic Container Registry (AWS ECR)
* Docker Hub
* Docker Registry V2
* GitLab
* Google Artifact Registry (GAR)
* Google Container Registry (GCR)
* Harbor
* IBM Cloud
* JFrog Artifactory
* Mirantis Secure Registry (MSR)
* Oracle Container Registry
* Red Hat Quay.io
* Sonatype Nexus

## How it works

The following architecture diagram gives you insight into how SHRA works. 

* Following our [configuration instructions](#customize-your-deployment), you: 
  * Create a `values_override.yaml` file specific to your environment. 
  * Add CrowdStrike's SHRA Helm Chart to your Helm repo or download the Chart from this GitHub repo.
  * Download the SHRA container image files from CrowdStrike's registry and, best practice, save to your own registry.

* You run the Helm install command to deploy the Chart. As the Helm is deployed:
  * Your configured registry connections are validated.
  * A jobs database is initialized in persistent storage.
  * A registry assessment cache is initialized in persistent storage.
  * A **Jobs Controller** Pod spins up.
  * One or more **Executor** Pods spin up.

* Per your configured schedule, the Jobs Controller tells the Executor(s) which registries to scan. 
If multiple registries are configured within your installation, the jobs are worked in a round robin approach to balance between the registries.

* The Executor(s) perform the following three tasks:
   * `Registry scan`: identifies the repositories within your configured registries
   * `Repository scan`: identifies image tags within the repositories
   * `Tag assessment`: downloads and uncompresses images that haven’t previously been scanned, creates a full inventory of what is in each image, then sends that inventory to CrowdStrike's cloud for analysis.

  To streamline work, `Tag assessment` uses a local registry assessment database to keep track of image tags previously scanned. 
  If an image tag is not found in the local database, it asks the CrowdStrike cloud if the image is new. 
  Only images that have not been inventoried before are unpacked and inventoried.

* The CrowdStrike cloud assesses the image inventories.

* Image assessment results are visible to you via the Falcon console. 
Go to [**Cloud security > Vulnerabilities > Image assessments**](https://falcon.crowdstrike.com/cloud-security/cwpp/image-assessment/images), then click the **Images** tab. 
Images scanned by SHRA have **Self-hosted registry** in the optional **Sources** column.

![High level diagram showing the architecture and deployment for the Falcon Self-hosted Registry Assessment tool (SHRA). It depicts a user installing SHRA via the Helm Chart files and a values_override.yaml file. SHRA's two images, the Jobs Controller and Executor, and three related persistent volume claims are created inside the namespace "falcon-self-hosted-registry-assessment". Arrows depict the flow of new image inventories from the Executor's tag assessment component to the CrowdStrike cloud, where analysis results are visible to the user via the Falcon console.](self-hosted-registry-assessment-flow.jpg "Self-hosted Registry Assessment")

Three volume mounts are needed for SHRA:
1. A 1+ GiB persistent volume for a job controller sqlite database.
1. A 1+ GiB persistent volume used by the executor(s) for a registry assessment cache.
1. A working volume to store and expand images for assessment.

**Note**: Performance of the `Registry scan` and `Repository scan` jobs are networking bound, for the most part. 
By contrast, the `Tag assessment` job is mainly constrained by the amount of available disk space to unpack the images and perform the inventory. 
Ensure you provide sufficient disk space. For more information, see Configure temporary storage.

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
* 2 [Persistent Volume](#configure-persistent-data-storage) claims
* 1 Volume (persistent or emptyDir) of [sufficient size](#configure-temporary-storage) for unpacking and assessing images
* Networking sufficient to communicate with CrowdStrike cloud services and your image registries.
* Optional. [Cert Manager - Helm](https://cert-manager.io/docs/installation/helm/) if you wish to use TLS between the containers in this Chart. See [TLS Configuration](#optional-configure-grpc-over-tls).

**Note:** For more information on SHRA's supported persistent volume storage schemes, see [Configure persistent data storage](#configure-persistent-data-storage).

## Create a basic config file

Before you install this Helm Chart, there are several config values to customize for your specific use case.

To start, copy the following code block into a new file called `values_override.yaml`.
Follow the steps in [Customize your deployment](#customize-your-deployment) to configure these values.

**Tip:** If you have experience deploying other CrowdStrike Helm Charts, you can refer to [Falcon Chart configuration options](#falcon-chart-configuration-options) for details on how to customize the fields in this minimal installation example. 

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
    port: "443"
    host: "https://registry-1.docker.io"
    cronSchedule: "* * * * *"
  - type: dockerhub
    credentials:
      username: ""
      password: ""
    port: "443"
    host: "https://registry-2.docker.io"
    cronSchedule: "0 0 * * *"
```

Continue to tailor this file for your environment by following the remaining steps in this guide.

## Customize your deployment

Configure your deployment of the Self-hosted Registry Assessment tool by editing values in your `values_override.yaml` files.

The most commonly used parameters are described in the steps below. 
For other options, refer to the [full set of configurations options](#falcon-chart-configuration-options) and the comments in provided `values.yaml`.

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

**Note:** The API client secret will not be presented again, so don't close the dialog until you have this value safely saved. 

Export these variables for use in later steps:
```sh
export FALCON_CLIENT_ID=<your-falcon-api-client-id>
export FALCON_CLIENT_SECRET=<your-falcon-api-client-secret>
```

Next, get your Customer ID (CID):
1. In the Falcon console, go to [**Host setup and management** > **Deploy** > **Sensor downloads**](https://falcon.crowdstrike.com/host-management/sensor-downloads/all).
1. Copy your Customer ID (CID) from the **How to Install** section and save it as the variable FALCON_CID.
```sh
 export FALCON_CID=0123456789ABCDEFGHIJKLMNOPQRSTUV-WX 
```

Configure the following two parameters in your `values_override.yaml` file.

| Parameter                           |           | Description                                                                                           | Default   |
|:------------------------------------|-----------|:------------------------------------------------------------------------------------------------------|:----------|
| `crowdstrikeConfig.clientID`        | required  | The client id used to authenticate the self-hosted registry assessment service with CrowdStrike.      | ""        |
| `crowdstrikeConfig.clientSecret`    | required  | The client secret used to authenticate the self-hosted registry assessment service with CrowdStrike.  | ""        |

### Configure SHRA image versions and download registry

Our self-hosted registry assessment tool is composed of two OCI images:
* `job-controller` 
* `executor`

You specify what versions of `job-controller` and `executor` that you want to install.
During installation, the SHRA Helm Chart downloads those images from your specified image registry and deploys with your custom configurations.

#### Login to our registry

To download the SHRA images, you need the `FALCON_CLIENT_ID`, `FALCON_CLIENT_SECRET`, and `FALCON_CID` environment variables you exported in earlier steps.
If you're in a new terminal window or if running the commands above causes authentication errors, repeat the variable exports described in [Configure your CrowdStrike credentials](#configure-your-crowdstrike-credentials). 

Run the following commands to get perform an OAuth handshake and log in to our Docker registry:

```bash
ENCODED_CREDENTIALS=$(echo -n "$FALCON_CLIENT_ID:$FALCON_CLIENT_SECRET" | base64)
TOKEN_URL="https://api.crowdstrike.com/oauth2/token"
ACCESS_TOKEN=$(curl -X POST "$TOKEN_URL" \
     -H "Authorization: Basic $ENCODED_CREDENTIALS" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "grant_type=client_credentials" | jq -r '.access_token')
DOCKER_LOGIN_PASSWORD=$(curl -X 'GET' 'https://api.crowdstrike.com/container-security/entities/image-registry-credentials/v1' -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" | jq -r '.resources[0].token')
echo $DOCKER_LOGIN_PASSWORD | docker login -u fc-${FALCON_CID} registry.crowdstrike.com/falcon-selfhostedregistryassessment --password-stdin
```

#### List available images

To see the available SHRA images, use a tool like [skopeo](https://github.com/containers/skopeo) to request a list of available tags.

```bash
skopeo list-tags --creds fc-$FALCON_CID:$DOCKER_LOGIN_PASSWORD docker://registry.crowdstrike.com/falcon-selfhostedregistryassessment/release/falcon-jobcontroller
skopeo list-tags --creds fc-$FALCON_CID:$DOCKER_LOGIN_PASSWORD docker://registry.crowdstrike.com/falcon-selfhostedregistryassessment/release/falcon-registryassessmentexecutor
```

You can expect output from these commands to be similar to this:
``` json
{
    "Repository": "registry.crowdstrike.com/falcon-selfhostedregistryassessment/release/falcon-jobcontroller",
    "Tags": [
        "1.0.0"
    ]
}
{
    "Repository": "registry.crowdstrike.com/falcon-selfhostedregistryassessment/release/falcon-registryassessmentexecutor",
    "Tags": [
        "1.0.0"
    ]
}
```

#### Find your CrowdStrike registry

It's very important to match your configured registry with the CrowdStrike cloud you've been assigned.
A mismatch between your assigned cloud and the CrowdStrike registry used will cause an authorization failure when you try to download the images.

If you access the Falcon console at `falcon.crowdstrike.com`, your assigned CrowdStrike cloud is `us-1`. 
For all other clouds, the cloud location (`us-2`, `eu-1`, `gov-1`, or `gov-2`) is visible in the Falcon console URL.

Determine your assigned cloud and select the matching CrowdStrike registry location from this list:
* `us-1`, `us-2`, and `eu-1` use `registry.crowdstrike.com/falcon-self-hosted-scanner/release/falcon-self-hosted-scanner`
* `gov-1` use `registry.laggar.gcw.crowdstrike.com/falcon-self-hosted-scanner/gov-1/release/falcon-self-hosted-scanner`
* `gov-2` use `registry.us-gov-2.crowdstrike.mil/falcon-self-hosted-scanner/gov-2/release/falcon-self-hosted-scanner`


#### Copy the SHRA images to your repository

We recommend that you pull the two SHRA images from the CrowdStrike registry and store them in your own registry.

**Note**: These steps assume that:
   * you created a container image registry to store the SHRA images
   * you have the required permissions to write to that registry
   * you've configured local authentication to your registry
   * you have environment variables set for `FALCON_CLIENT_ID` and `FALCON_CLIENT_SECRET` as described in [Configure your CrowdStrike credentials](#configure-your-crowdstrike-credentials). 

Pull the jobcontroller and registryassessmentexecutor images. 
Ensure that you use the desired tags rather than the defaults provided in the example below.
```sh
docker pull registry.crowdstrike.com/falcon-selfhostedregistryassessment/release/falcon-jobcontroller:1.0.0
docker pull registry.crowdstrike.com/falcon-selfhostedregistryassessment/release/falcon-registryassessmentexecutor:1.0.0
```

Once you've copied both images, use `docker images | grep falcon` to verify that you see both the `jobcontroller` and `registryassessmentexecutor` images in your registry.

#### Generate a credentials string for your registry

If your private registry requires authentication, the Helm Chart configuration file needs that information. 
For most registries, the needed credentials are a base64 encoded string of your Docker `config.json` file.

Use the following command to get the authentication string (modify as needed if your credentials are not located at ~/.docker/config.json):
``` sh
cat ~/.docker/config.json | base64 -
```

Keep this value handy for the next step, you'll use it to configure `executor.image.registryConfigJSON` and `jobController.image.registryConfigJSON`.

#### Add registry and image details to the configuration

Now that you've gathered the necessary information, verify and adjust image registry location, version tags, and authentication data in your `values_override.yaml` file. 

| Parameter                                |                                         | Description                                                                                                                                      | Default                       |
|:-----------------------------------------|:----------------------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------|:------------------------------|
| `executor.image.registry`                |required                                 | The registry to pull the `executor` image from. We recommend that you store this image in your registry.                                         |                               |
| `executor.image.repository`              |                                         | The repository for the `executor` image file.                                                                                                    | "registryassessmentexecutor"  |
| `executor.image.digest`                  |required or `executor.image.tag`         | The sha256 digest designating the `executor` image to pull. This value overrides the `executor.image.tag` field.                                 | ""                            |
| `executor.image.tag`                     |required or `executor.image.digest`      | Tag designating the `executor` image to pull. Ignored if `executor.image.digest` is supplied. We recommend use of `digest` instead of `tag`.     | ""                            |
| `executor.image.pullPolicy`              |                                         | Policy for determining when to pull the `executor` image.                                                                                        | "IfNotPresent"                |
| `executor.image.pullSecret`              |                                         | Use this to specify an existing secret in the namespace.                                                                                         | ""                            |
| `executor.image.registryConfigJSON`      |                                         | `executor` pull token from CrowdStrike or the base64 encoded Docker secret for your private registry.                                            | ""                            |
| `jobController.image.registry`           |required                                 | The registry to pull the `job-controller` image from. We recommend that you store this image in your registry.                                   | ""                            |
| `jobController.image.repository`         |                                         | The repository for the `job-controller` image.                                                                                                   | "job-controller"              |
| `jobController.image.digest`             |required or `jobController.image.tag`    | The sha256 digest for the `job-controller` image to pull. This value overrides the `jobController.image.tag` field.                              | ""                            |
| `jobController.image.tag`                |required or `jobController.image.digest` | Tag for the `job-controller` image to pull. Ignored if `jobController.image.digest` is supplied. We recommend use of `digest` instead of `tag`.  | ""                            |
| `jobController.image.pullPolicy`         |                                         | Policy for determining when to pull the `job-controller` image.                                                                                  | "IfNotPresent"                |
| `jobController.image.pullSecret`         |                                         | Use this to specify an existing secret in the namespace                                                                                          | ""                            |
| `jobController.image.registryConfigJSON` |                                         | `job-controller` pull token from CrowdStrike or the base64 encoded Docker secret for your private registry.                                      | ""                            |

### Configure which registries to scan and how often to scan them

The Self-hosted Registry Assessment tool watches one or more registries.
When multiple registries are configured, jobs are scheduled round robin to balance between them.

Configure your list by adding an object within the `registryConfigs` array. 

For example, if you have two registries, the first with a weekly scan schedule and the second with a daily scan schedule:
```yaml 
registryConfigs:
  - type: dockerhub
    credentials:
      username: "myuser"
      password: "xxxyyyzzz"
    port: "5000"
    host: "https://registry-1.docker.io"
    cronSchedule: "0 0 * * 6"
  - type: dockerhub
    credentials:
      username: "anotheruser"
      password: "qqqrrrsss"
    port: "5000"
    host: "https://registry-2.docker.io"
    cronSchedule: "0 0 * * *"
```

#### Registry Specific Configuration

Each registry type has specific authentication requirements.
Use the sections below to find your registry type and information on how to configure it.
Depending on the registry type, additional fields may be required.

**Important**: Pay special attention to the `type` field for your given registry. 

Copy the correct registry configuration to your `values_overides.yaml` file and, unless otherwise specified, provide values for each field.

##### ECR

To access ECR the host needs to have direct access to the ECR registry. 

Leave `credentials.aws_iam_role` and `credentials.aws_external_id` as empty strings. 
These are placeholders for future support of role assumption. 

```yaml
 - type: ecr
   credentials:
    aws_iam_role: ""
    aws_external_id: ""
   port: "443"
   host: ""
   cronSchedule: "0 0 * * *"
```

##### Docker Hub

```yaml
  - type: dockerhub
    credentials:
      username: ""
      password: ""
    host: "https://registry-1.docker.io"
    cronSchedule: "0 0 * * *"
```

##### Docker registry V2

```yaml
  - type: docker
    credentials:
      username: ""
      password: ""
    port: ""
    host: ""
    cronSchedule: "0 0 * * *"
```

##### Sonartype Nexus

```yaml
  - type: nexus
    credentials:
      username: ""
      password: ""
    host: ""
    cronSchedule: "0 0 * * *"
```

##### Jfrog Artifactory

```yaml
  - type: artifactory
    credentials:
      username: ""
      password: ""
    port: ""
    host: ""
    cronSchedule: "0 0 * * *"
```

##### Quay

Notes:
- `username` has the format `<organization_name>+<robot_account_name>`
- `domain_url` and `host` should have the same value. For the cloud-hosted solution, use `quay.io`. Otherwise, provide the domain of your self hosted quay installation.

```yaml
  - type: quay.io
    credentials:
      username: ""
      password: ""
      domain_url: ""
    port: "443"
    host: ""
    cronSchedule: "* * * * *"
```

##### Oracle

Notes:
- `username` has the format `tenancy-namespace/user`
- `credentials.compartment_ids` may be required. In the Oracle console, go to **Identity & Security**. Under Identity, click **Compartments**. This shows the list of compartments in your tenancy.
Hover over the **OICD** column to copy the compartment ID that you want to register. If provided, there should be a single value in the list of compartment ids, use that value for this field.
- `credentials.scope_name` required when using a compartment id

```yaml
  - type: oracle
    credentials:
      username: ""
      password: ""
      compartment_ids: [""]
      scope_name: ""
    port: "443"
    host: "https://us-phoenix-1.ocir.io"
    cronSchedule: "0 0 * * *"
    credential_type: "oracle"
```

##### Gitlab

Notes:
* `domain_url` and `host` should both be the fully qualified domain name of your GitLab installation

```yaml
  - type: gitlab
    credentials:
      username: ""
      password: ""
      domain_url: ""
    port: ""
    host: ""
    cronSchedule: "0 0 * * *"
```

##### Mirantis

```yaml
  - type: mirantis
    credentials:
      username: ""
      password: ""
    port: ""
    host: ""
    cronSchedule: "* * * * *"
```

##### Harbor

Notes:
* `domain_url` and `host` should both be the fully qualified domain name of your Harbor installation

```yaml
  - type: harbor
    credentials:
      username: ""
      password: ""
      domain_url: ""
    port: ""
    host: ""
    cronSchedule: "* * * * *"
```

##### Google Artifact Registry

Notes:
* `host` follows this URL format `https://<region>-docker.pkg.dev/` (for regional) or `https://<multi-region>-docker.pkg.dev/` (for multi-regional), using the subdomain for the region or multi-region of your GAR account. You can find the regional or multi-regional info in location column of the repository list in your GAR account.

Authentication to GAR requires a private key

1. In GCP console navigate to **IAM & Admin > Service accounts**.
1. Click **Create Service Account**.
1. Specify a service account name, grant it the **Storage Object Viewer** role, and click **Done**.
1. Within the service accounts table, locate the newly created service account, click the **actions icon**, and select **Manage Keys**.
1. Click the **KEYS** tab.
1. Click the **ADD KEY** dropdown and select **Create new key**.
1. Ensure **JSON** is selected and click **Create**. This downloads the newly created service account in JSON format. Use it to populate the `service_account_json` field below.

```yaml
  - type: gar
    credentials:
      scope_name: ""
      project_id: ""
      service_account_json:
        private_key: ""
        client_email: ""
        project_id: ""
        type: "service_account"
    port: "443"
    host: ""
    cronSchedule: "* * * * *"
```

##### Google Container Registry

Notes:
* `host` follows this URL format `https://gcr.io/` or `https://[REGION].gcr.io/`, using the subdomain for the region of your GCR account. You can find the hostname URL in your GCR image list.

Authentication to GAR requires a private key

1. In GCP console navigate to **IAM & Admin > Service accounts**.
1. Click **Create Service Account**.
1. Specify a service account name, grant it the **Storage Object Viewer** role, and click **Done**.
1. Within the service accounts table, locate the newly created service account, click the **actions icon**, and select **Manage Keys**.
1. Click the **KEYS** tab.
1. Click the **ADD KEY** dropdown and select **Create new key**.
1. Ensure **JSON** is selected and click Create. This downloads the newly created service account in JSON format. Use it to populate the `service_account_json` field below.

```yaml
  - type: gcr
    credentials:
      project_id: ""
      service_account_json:
        project_id: ""
        service_account_email: ""
        private_key_id: ""
        client_email: ""
        private_key: ""
        type: "service_account"
    port: "443"
    host: ""
    cronSchedule: "0 0 * * *"
```

##### IBM Cloud Registry

Notes:
* `host` and `credentials.domain_url` use this URL format: `https://icr.io` (for global) or `https://<region-key>.icr.io` (for regional)

```yaml
  - type: icr
    credentials:
      username: ""
      domain_url: ""
      password: ""
    port: "443"
    host: ""
    cronSchedule: "0 0 * * *"
```

#### Use Kubernetes secrets for registry authentication

We recommend you follow security best practices and avoid saving your registry username and password in plaintext.
To support you in this, our Helm Chart works with [Kubernetes secrets](https://kubernetes.io/docs/concepts/configuration/secret/).

This works whether you pull Docker images with Kubernetes secrets or if you have another method that injects Docker credentials into Kubernetes secrets.

First, create a named secret in the [Kubernetes imagePullsecrets](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry), with a namespace.

Then, in your `values_override.yaml` file, replace the username and password parameters with `registryConfigs.*.credentials.kubernetesSecretName` and `registryConfigs.*.credentials.kubernetesSecretNamespace` (both are required).

#### Configure your scanning schedules

You configure how often you want SHRA to scan each of your configured registries. 
Specify your schedule as a unix-cron string in the `registryConfigs.*.cronSchedule` parameter for each registryConfigs section of your `values_override.yaml` file.

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

**Note**: If you schedule the scans for a registry too closely and the previous scan is still running when it’s time for the next scan, the in-progress scan continues and the upcoming scan is skipped. 

| Parameter                                                 |                                                      | Description                                                                                                             | Default |
|:----------------------------------------------------------|:-----------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------|:--------|
| `registryConfigs.*.type`                                  | required                                             | The registry type being assessed. See [Supported registries](#supported-registries) for options.                        | ""      |
| `registryConfigs.*.credentials.username`                  | required without `kubernetesSecretName`              | The username used to authenticate to the registry.                                                                      | ""      |
| `registryConfigs.*.credentials.password`                  | required without `kubernetesSecretName`              | The password used to authenticate to the registry.                                                                      | ""      |
| `registryConfigs.*.credentials.kubernetesSecretName`      | required with `kubernetesSecretNamespace`            | The Kubernetes secret name that contains registry credentials.                                                          | ""      |
| `registryConfigs.*.credentials.kubernetesSecretNamespace` | required with `kubernetesSecretName`                 | The namespace containing the Kubernetes secret with credentials.                                                        | ""      |
| `registryConfigs.*.port`                                  |                                                      | The port for connecting to the registry. Unless you specify a value here, SHRA uses port 80 for http and 443 for https. | ""      |
| `registryConfigs.*.host`                                  | required                                             | The host for connecting to the registry.                                                                                | ""      |
| `registryConfigs.*.cronSchedule`                          | required                                             | A cron schedule that controls how often the top level registry collection job is created.                               | ""      |


### Configure persistent data storage

SHRA needs 2 persistent volume claims (PVC) for SQLite databases that allow the service to be resilient to down time and upgrades. 

The executor and job controller databases created in the PVCs start small and grow with usage, accumulating job and image information respectively.
We recommend a **minimum of 1 gibibyte of storage** for each database. This size accommodates approximately 2 million image scans. 

If you have multiple registries, or wish to scan registries faster, we recommend you increase the executor database volume size.
You can also adjust job controller retention periods to reduce the footprint of the jobs database.
See [Change persistent storage retention](#change-persistent-storage-retention) for details.

You have 2 options for SHRA’s persistent data storage:
* New persistent volume claims are created
* You provide existing storage claim names

**Important**: At deployment, SHRA tries to create the required storage claims. 
However, since each Kubernetes installation uses different storage classes, SHRA cannot offer default storage classes that work universally. 
**Your deployment will fail unless you configure the storage class type or specify names to existing storage claims.** 

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

You have 3 options for SHRA’s temporary data storage:
* A new Persistent Volume Claim, created during deployment
* You provide an existing storage claim name
* A new temp emptyDir, created during deployment

Persistent Volume Claim is the default storage type and is recommended if your storage provider supports dynamic creation of storage volumes. 

**Important:** At deployment, SHRA will try to create a Persistent Volume Claim. 
However, since each Kubernetes installation uses different storage classes, SHRA cannot offer a default storage class that works universally. 
**Your deployment will fail unless you configure the storage class type, specify `local` for an emptyDir, or specify the name of an existing storage claim.**

To use an existing storage claim, set `executor.assessmentStorage.pvc.create` to `false` and configure `executor.assessmentStorage.pvc.existingClaimName` with your storage class name.

To have a new emptyDir created, set `executor.assessmentStorage.type` to `local` and if your deployment needs more than the default 100 gibibytes of storage, set the emptyDir size in `executor.assessmentStorage.size`. 

To have a new persistent volume claim created, configure `executor.assessmentStorage.pvc.storageClass` with a value from the table of storage class options for SHRA’s supported runtimes in [Configure persistent data storage](#configure-persistent-data-storage).
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

### Configure SHRA scaling meet scanning needs

We've tailored our Helm chart with the performant default values for the majority of situations.
However, you can still scale your cluster to handle more throughput by adjusting the the number of executor pods running.

Each executor pod can inventory approximately 100 images per hour, assuming an average image size of 1 GB. 

To increase or decrease the number of executor pods, edit the `executor.replicaCount` values in your `values_override.yaml` file. 

| Parameter                    |             |Description                                                                                                                  | Default     |
|:-----------------------------|------------:|:----------------------------------------------------------------------------------------------------------------------------|:------------|
| `executor.replicaCount`      |             | The number of executor pods. This value can be increased for greater concurrency if CPU is the bottleneck.                  | 1           |


### Allow traffic to CrowdStrike servers

SHRA requires internet access to your assigned CrowdStrike upload servers. 
If your network requires it, configure your allow lists with your assigned CrowdStrike cloud servers. 
For more info, see [CrowdStrike domains and IP addresses to allow](https://falcon.crowdstrike.com/documentation/page/a2a7fc0e/crowdstrike-oauth2-based-apis#e590c681).

### Optional. Configure CrowdStrike allow list

By default, API access to your CrowdStrike account is not limited by IP address. 
However, we offer the option to restrict access by IP addresses or ranges to ensure your account is only accessed from specific networks.

Note that if your account is already IP address restricted, requests from other IPs (including the one where you're deploying SHRA) will be denied access and result in the error `HTTP 403 "Access denied, authorization failed"`.

To protect your account, or add your SHRA IP details to the CrowdStrike allow list for your CID, see [IP Allowlist Management](https://falcon.crowdstrike.com/documentation/page/a80757b1/ip-allowlist-management).

### Optional. Configure gRPC over TLS

The Job Controller and Executor pods communicate with one another over gRPC. 
If you wish, you can configure TLS for communication between these pods with either [cert-manager](https://cert-manager.io/) or your own certificate files. 

To enable TLS (regardless of the option you choose) add the following line to your `values_override.yaml` file, then follow the steps below.

| Parameter                                   | | Description                                                                                                                             | Default     |
|:--------------------------------------------|-|:----------------------------------------------------------------------------------------------------------------------------------------|:------------|
| `tls.enable`                                | | Set to `true` to enforce TLS communication between the executor pods and job-controller as they communicate job information over gRPC.  | false       |

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

If you have an existing certificate as a Kubernetes secret you wish to use for these pods, provide them as the `tls.existingSecret`.

| Parameter                                 |   | Description                                                                                                    | Default     |
|:------------------------------------------|---|:---------------------------------------------------------------------------------------------------------------|:------------|
| `tls.existingSecret`                      |   | Specify an existing Kubernetes secret instead of cert manager.                                                 | ""          |

#### Option 3. Enable gRPC TLS with custom certificate files

If you have existing certificate files you wish to use for these pods, provide them as the `tls.issuer`.

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

Note: If you need assistance with SHRA deployment or ongoing activity with your self-hosted registry scans, CrowdStrike will request that you add the log collector to your installation.

### Create the HEC Ingest Connector

The Kubernetes Collector sends logs over HTTP.
Therefore, the first step is to create a Data Connector in the Falcon console, configured to accept HTTP Event Connector (HEC) source logs. 
Perform the following steps to set up your Data Collector. 
If neeeded, see our complete documentation on [setup and configuration of the HEC Data Connector](https://falcon.crowdstrike.com/documentation/page/bdded008/hec-http-event-connector-guide). 

1. In the Falcon console go to go to [**Next-Gen SIEM** > **Data sources**](https://falcon.crowdstrike.com/data-connectors/).
1. Select **HEC / HTTP Event Connector**.
1. On the **Add new connector** page, fill the following fields:
   * **Data details**:
     * **Data source**: `<Provide a name such as Self-hosted Registry Assessment Containers>`
     * **Data type**: `JSON`
   * **Connector details**:
     * **Connector name**: `<Provide a name such as SHRA Log Connector>`
     * **Description**: `<Provide a description such as Logs to use for monitoring and alerts>`
   * **Parser details**: `json (Generic Source)`
1. Agree to the terms for third party data sources and click **Save**.
1. When the connector is created and ready to receive data, a message box appears at the top of the screen. 
Click **Generate API key**. 
1. From the **Connection setup** dialog, copy the **API key** and **API URL** to a password management or secret management service. 

   Modify the API URL by removing `/services/collector` from the end. Your value will look like: `https://123abc.ingest.us-1.crowdstrike.com` where the first subdomain (`123abc` in this example) is specific to your connector.

   **Note:** The API Key will not be presented again, so don't close the dialog until you have it safely saved. 

1. Export these variables for use in later steps:
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
1. Go to [**Next-Gen SEIM** > **Log management ** > **Advanced event search**](https://falcon.crowdstrike.com/investigate/search?end=&query=kubernetes.namespace%20%3D%20%22registry-scanner%22&repo=all&start=30m).  
1. Filter by the Kubernetes namespace by adding the following to the query box (adjust if you chose a different namespace)
   `kubernetes.namespace = "registry-scanner"`. 
1. Keep this window open to monitor for results. Click **Run** once SHRA is installed.

### Configure saved searches to monitor SHRA

Now that your SHRA logs are ingested by LogScale, you can configure scheduled searches to be notified of any issues your SHRA may have in connecting to registries or performing assessment. 

1. Go to [**Next-Gen SEIM** > **Log management ** > **Advanced event search**](https://falcon.crowdstrike.com/investigate/search?end=&query=kubernetes.namespace%20%3D%20%22registry-scanner%22&repo=all&start=30m).  

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
         falcon-self-hosted-registry-assessment \
         crowdstrike/falcon-self-hosted-registry-assessment
   ```

   For more details, see the [falcon-helm](https://github.com/CrowdStrike/falcon-helm) repository.

1. Verify your installation.

   ```sh
   helm show values crowdstrike/registry-scanner
   ```

The job controller and executor are now live, and the first registry scans will begin according to your configured cron schedules associated with each registry.
For more information on setting your scanning schedule, see [Configure your scanning schedules](#configure-your-scanning-schedules).

## Update SHRA

As needed, you can change your configuration values or replace the SHRA container images with new releases.

After making changes to your `values_override.yaml` file, use the `helm upgrade` command shown in [Install the SHRA Helm Chart](#install-the-shra-helm-chart).

## Uninstall SHRA

To uninstall, run the following command:
```sh
helm uninstall falcon-self-hosted-registry-assessment --namespace falcon-self-hosted-registry-assessment \
      && kubectl delete namespace falcon-self-hosted-registry-assessment
```

## Falcon Chart configuration options
The Chart's `values.yaml` file includes more comments and descriptions in-line for additional configuration options.

| Parameter                                                                      |                                          | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Default                      |
|:-------------------------------------------------------------------------------|:-----------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:-----------------------------|
| `nameOverride`                                                                 |                                          | override generated name for k8bernetes labels                                                                                                                                                                                                                                                                                                                                                                                                                    | ""                           |
| `fullnameOverride`                                                             |                                          | override generated name prefix for deployed Kubernetes objects                                                                                                                                                                                                                                                                                                                                                                                                   | ""                           |
| `executor.replicaCount`                                                        |                                          | The number of executor pods. This value can be increased for greater concurrency if CPU is the bottleneck.                                                                                                                                                                                                                                                                                                                                                       | 1                            |
| `executor.image.registry`                                                      | required                                 | The registry to pull the `executor` image from. We recommend that you store this image in your registry. See [Copy the SHRA images to your Registry](#option-1-copy-the-shra-images-to-your-registry).                                                                                                                                                                                                                                                           | ""                           |
| `executor.image.repository`                                                    | required                                 | The repository for the `executor` image file.                                                                                                                                                                                                                                                                                                                                                                                                                    | "registryassessmentexecutor" |
| `executor.image.digest`                                                        | required or `executor.image.tag`         | The sha256 digest designating the `executor` image to pull. This value overrides the `executor.image.tag` field.                                                                                                                                                                                                                                                                                                                                                 | ""                           |
| `executor.image.tag`                                                           | required or `executor.image.digest`      | Tag designating the `executor` image to pull. Ignored if `executor.image.digest` is supplied. We recommend use of `digest` instead of `tag`.                                                                                                                                                                                                                                                                                                                     | ""                           |
| `executor.image.pullPolicy`                                                    |                                          | Policy for determining when to pull the `executor` image.                                                                                                                                                                                                                                                                                                                                                                                                        | "IfNotPresent"               |
| `executor.image.pullSecret`                                                    |                                          | Use this to specify an existing secret in the namespace.                                                                                                                                                                                                                                                                                                                                                                                                         | ""                           |
| `executor.image.registryConfigJSON`                                            |                                          | `executor` pull token from CrowdStrike or the base64 encoded Docker secret for your private registry.                                                                                                                                                                                                                                                                                                                                                            | ""                           |
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
| `jobController.image.registry`                                                 | required                                 | The registry to pull the `job-controller` image from. We recommend that you store this image in your registry.                                                                                                                                                                                                                                                                                                                                                   | ""                           |
| `jobController.image.repository`                                               | required                                 | The repository for the `job-controller` image.                                                                                                                                                                                                                                                                                                                                                                                                                   | "job-controller"             |
| `jobController.image.digest`                                                   | required or `jobController.image.tag`    | The sha256 digest for the `job-controller` image to pull. This value overrides the `jobController.image.tag` field.                                                                                                                                                                                                                                                                                                                                              | ""                           |
| `jobController.image.tag`                                                      | required or `jobController.image.digest` | Tag designating the `job-controller` image to pull. Ignored if `jobController.image.digest` is supplied. We recommend use of `digest` instead of `tag`.                                                                                                                                                                                                                                                                                                          | ""                           |
| `jobController.image.pullPolicy`                                               |                                          | Policy for determining when to pull the `job-controller` image.                                                                                                                                                                                                                                                                                                                                                                                                  | "IfNotPresent"               |
| `jobController.image.pullSecret`                                               |                                          | Use this to specify an existing secret in the namespace.                                                                                                                                                                                                                                                                                                                                                                                                         | ""                           |
| `jobController.image.registryConfigJSON`                                       |                                          | `job-controller` pull token from CrowdStrike or the base64 encoded Docker secret for your private registry.                                                                                                                                                                                                                                                                                                                                                      | ""                           |
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
| `registryConfigs.*.credentials.kubernetesSecretName`                           | required with `kubernetesSecretNamespace` | The Kubernetes secret name that contains registry credentials.                                                                                                                                                                                                                                                                                                                                                                                                  | ""                           |
| `registryConfigs.*.credentials.kubernetesSecretNamespace`                      | required with `kubernetesSecretName`     | The namespace containing the Kubernetes secret with credentials.                                                                                                                                                                                                                                                                                                                                                                                                 | ""                           |
| `registryConfigs.*.port`                                                       |                                          | The port for connecting to the registry. Unless you specify a value here, SHRA uses port 80 for http and 443 for https.                                                                                                                                                                                                                                                                                                                                          | ""                           |
| `registryConfigs.*.allowedRepositories`                                        |                                          | A comma separated list of repositories that should be assessed. If this value is not set, the default behavior, then all repositories within a registry will be assessed.                                                                                                                                                                                                                                                                                        | ""                           |
| `registryConfigs.*.host`                                                       |                                          | The host for connecting to the registry.                                                                                                                                                                                                                                                                                                                                                                                                                         | ""                           |
| `registryConfigs.*.cronSchedule`                                               |                                          | A cron schedule that controls how often the top level registry collection job is created.                                                                                                                                                                                                                                                                                                                                                                        | ""                           |
| `tls.enable`                                                                   |                                          | Set to `true` to enforce TLS communication between the executor pods and job-controller as they communicate job information over gRPC.                                                                                                                                                                                                                                                                                                                           | false                        |
| `tls.useCertManager`                                                           |                                          | When `tls.enable` is `true`, this field determines if cert manager should be used to create and control certificates. See [tls configuration](#optional-configure-grpc-over-tls) for more information.                                                                                                                                                                                                                                                           | true                         |
| `tls.existingSecret`                                                           |                                          | Specify an existing Kubernetes secret instead of cert manager.                                                                                                                                                                                                                                                                                                                                                                                                   | ""                           |
| `tls.issuer`                                                                   |                                          | Reference to an existing cert manager Issuer or ClusterIssuer, used for creating the TLS certificates.                                                                                                                                                                                                                                                                                                                                                           | {}                           |
| `proxyConfig.HTTP_PROXY`                                                       |                                          | Proxy URL for HTTP requests unless overridden by NO_PROXY.                                                                                                                                                                                                                                                                                                                                                                                                       | ""                           |
| `proxyConfig.HTTPS_PROXY`                                                      |                                          | Proxy URL for HTTPS requests unless overridden by NO_PROXY.                                                                                                                                                                                                                                                                                                                                                                                                      | ""                           |
| `proxyConfig.NO_PROXY`                                                         |                                          | Hosts to exclude from proxying. Provide as a string of comma-separated values.                                                                                                                                                                                                                                                                                                                                                                                   | ""                           |