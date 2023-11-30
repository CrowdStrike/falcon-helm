# Kubernetes Protection Agent

## Overview

The Kubernetes Protection Agent allows for the discovery of Kubernetes objects by the Falcon Platform. The agent collects info about Kubernetes objects, their state, and identifies Kubernetes clusters protected by Falcon sensors. This information is available in the Kubernetes Cluster section.

## Requirements

‌**Subscription:**

- Falcon Cloud Workload Protection (FCWP)
- Falcon Cloud Security with Containers (FCSC)
- Falcon Managed Containers (FMC)

**Roles** (for details, see The Falcon console documentation: [Roles for Kubernetes Protection](https://falcon.crowdstrike.com/documentation/330/default-roles-reference#roles-for-kubernetes-protection)):

*   Kubernetes Protection Administrator
*   Kubernetes Protection Analyst
*   Kubernetes Protection Read-Only Analyst

‌**Clouds**:‌ Available in all clouds

## Installing the Kubernetes Protection Agent

The KPA is installed on the Kubernetes cluster, and it provides visibility into the cluster by collecting event information from the Kubernetes layer. These events are correlated to sensor events and cloud events to provide complete cluster visibility.

Events collected by the KPA:

*   K8SCluster
*   EksCluster
*   AksCluster
*   K8SNode
*   K8SPod
*   K8SRunningContainer
*   K8SRunningContainerStatus
*   K8SInitContainerStatus
*   K8SNodeAks
*   K8SInitContainer
*   AksAgentPool
*   AksCluster
*   AzureVMSS

## Kubernetes cluster registration

If you’re hosting Kubernetes clusters on your cloud account and using CSPM, you only need to register your account once. For example, if you are running an AWS EKS cluster, you can register your cloud account using AWS registration. When your AWS account is registered, CSPM will discover your Kubernetes clusters and populate the Kubernetes clusters table. Click **Rescan** to update the cluster list and check for your new Kubernetes clusters.

> **Note**: Depending on how many Kubernetes clusters you have, discovery can take an hour or more.

If you are:

*   A new CSPM user:

    1.  [Register your cloud account in the Falcon console](https://falcon.crowdstrike.com/documentation/294/registering-accounts).

        **Note**: CSPM will discover your Kubernetes cluster. Do not register your accounts again as Kubernetes clusters.

    2.  For each discovered Kubernetes cluster, [install the Kubernetes Protection Agent](#installing-the-agent).

*   An existing CSPM user who wants to add Kubernetes Protection:

    1.  [Install the agent](#installing-the-agent) on your discovered Kubernetes clusters.

*   A new CSPM user who has already registered Kubernetes clusters:

    1.  [Deprovision your Kubernetes clusters in the Falcon console](https://falcon.crowdstrike.com/documentation/177/kubernetes-protection#deprovisioning-account) in the Falcon console.
    2.  [Register your cloud account in the Falcon console](https://falcon.crowdstrike.com/documentation/177/kubernetes-protection) as needed.


### Installing the agent

Download a YAML file and run Helm commands to register your clusters.

1.  In the Falcon console accounts list, click the **Kubernetes** tab.

2.  Click the **Inactive Clusters** tab.

3.  In the list, click **Setup agent** for the cluster you’re setting up.

4.  Click **Download** to download the config\_value.yml file to /Downloads.

5.  Update \<client id> and \<client secret> with your API client ID and secret.

6.  Click **Copy to clipboard**, then run the copied command to add the Kubernetes Protection Helm repository.

7.  Click **Copy to clipboard**, then run the copied command to install the agent.

8.  Click **Finish: Go back to Clusters**.

9.  Verify that your agent is running in either of these ways:

    *   In the **Active Clusters** tab of the accounts registration list, confirm that the status is **Agent Running**. You might need to click **Refresh List**.
    *   In your terminal, run this command: `kubectl -n falcon-kubernetes-protection get pods`


## Kubernetes Protection Agent memory consumption

Kubernetes Protection Agent (KPA) memory consumption is directly proportional to the number of resources running on the cluster at startup. At startup, the KPA waits for the cluster to be in a steady state and then it caches the state of the cluster. The KPA consumes approximately 1GB of memory for every 800 to 1000 resources on the cluster. Knowing this, you can set your resource constraints to fit the number of resources running on your cluster.

> **Tip**: It is good practice to allocate the required resource constraints so resources don’t consume more memory than they are allocated.

**Add resource constraints**

Use the following kubectl command to patch resource constraints to the KPA:

```bash
kubectl patch deployment -n falcon-kubernetes-protection kpagent-cs-k8s-protection-agent --type=json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/resources", "value":{"limits":{"cpu":"250m","memory":"1Gi"},"requests":{"cpu":"250m","memory":"1Gi"}} }]'
```

**Remove resources**

Use the following kubectl command to remove resource constraints from the KPA:

```bash
kubectl patch deployment -n falcon-kubernetes-protection kpagent-cs-k8s-protection-agent --type=json -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/resources" }]'
```

## Kubernetes Protection Agent support for proxy servers

Kubernetes clusters can operate behind a proxy server. A Kubernetes Protection Agent (KPA) deployed on a cluster behind a proxy must be configured to allow the KPA to connect to specific services.

The KPA communicates with:

*   Kubernetes API server: the KPA monitors some Kubernetes resources by communicating with the Kubernetes API server on the cluster where the KPA is deployed.
*   CrowdStrike cloud services: the KPA sends some Kubernetes resources to the cloud to detect and collect info about indicators of misconfiguration (IOM).

### Proxy server communication

HTTP and HTTPS proxy servers are configured to route communication through a proxy server in one of two ways:

*   The proxy server is configured for both internal and external cluster communication.
*   The proxy server is configured only for external cluster communication.

#### Internal proxy configuration

When internal cluster communication is routed through a proxy server, the following environment variables must be set:

*   `HTTP_PROXY,` `HTTPS_PROXY` (or both): the variables must contain the URL and port of the proxy server.\
    For example: `HTTP_PROXY: http://100.10.10.10:8080`

#### External proxy configuration

When external cluster communication is routed through a proxy server, the following environment variables must be set:

*   `HTTP_PROXY`, `HTTPS_PROXY` (or both): the variables must contain the URL and port of the proxy server.\
    For example: `HTTP_PROXY: http://100.10.10.10:8080`
*   `NO_PROXY`: the variable must be set to the Kubernetes Pod network, service network, and localhost.\
    For example: `NO_PROXY: “localhost, 10.0.0.0/8”`

#### Supported proxy modes

*   Simple mode: where `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` are required.
*   Transparent mode: where all client requests are routed through the proxy. There are no requirements to set any environment variables.

#### Proxy server limitations

*   Custom proxy server configuration using environment variables beyond those mentioned in the previous section is not supported.
*   Proxy server configuration requiring basic authentication (username and password) for all communication is not supported.

### Enable a proxy configuration for the Kubernetes Protection Agent

#### Enabling proxy support at install time

#####  Using set commands to specify `proxyConfig` values
* Example using set commands - special characters need to be escaped
    ```
    helm upgrade --install kpagent crowdstrike/cs-k8s-protection-agent \
    -n falcon-kubernetes-protection --create-namespace -f values.yaml \
    --set proxyConfig.HTTP_PROXY="http:\/\/100.10.10.10:8080" \
    --set proxyConfig.HTTPS_PROXY="http:\/\/100.10.10.10:8080" \
    --set proxyConfig.NO_PROXY="localhost\,10.0.0.0\/8"
    ```

##### Adding to values file
* Example appending proxy values to the values file
```
crowdstrikeConfig:
  ...
  ...
proxyConfig:
  HTTP_PROXY: http://100.10.10.10:8080
  HTTP_PROXY: http://100.10.10.10:8080
  NO_PROXY: localhost,10.0.0.0/8
```

#### Manually modifying an existing install

If a proxy configuration is required for the KPA, follow these steps to enable proxy server support.

1.  Install the KPA using the Helm chart following the specific Kubernetes service instructions.

    *   [Register AWS accounts for Kubernetes Protection](https://falcon.crowdstrike.com/documentation/177/kubernetes-protection##register-aws-accounts-for-kubernetes-protection)
    *   [Register AKS accounts for Kubernetes Protection](https://falcon.crowdstrike.com/documentation/177/kubernetes-protection##register-aks-accounts-for-kubernetes-protection)
    *   [Register self-managed clusters for Kubernetes Protection](https://falcon.crowdstrike.com/documentation/177/kubernetes-protection##register-self-managed-clusters-for-kubernetes-protection)

2.  Open the KPA ConfigMap with the following command:

    ```bash
    kubectl edit cm -n falcon-kubernetes-protection kpagent-cs-k8s-protection-agent
    ```

3.  Add the following environment variables to the ConfigMap:

    ```yaml
    HTTP_PROXY: http://100.10.10.10:8080
    HTTPS_PROXY: http://100.10.10.10:8080
    NO_PROXY: localhost,10.0.0.0/8
    ```

    **Note**: `NO_PROXY` enables the KPA pod to communicate directly with the Kubernetes API server.

4.  Restart the KPA pod with the following command:

    ```bash
    kubectl rollout restart deploy kpagent-cs-k8s-protection-agent -n falcon-kubernetes-protection
    ```

### Disable a proxy configuration for the Kubernetes Protection Agent

If a proxy configuration is no longer required for the KPA, follow these steps to disable proxy server support:

1.  Open the KPA ConfigMap with the following command:

    ```bash
    kubectl edit cm -n falcon-kubernetes-protection kpagent-cs-k8s-protection-agent
    ```

2.  Remove the following environment variables from the ConfigMap:

    ```yaml
    HTTP_PROXY: http://100.10.10.10:8080
    HTTPS_PROXY: http://100.10.10.10:8080
    NO_PROXY: localhost,10.0.0.0/8
    ```

3.  Restart the KPA pod with the following command:

    ```bash
    kubectl rollout restart deploy kpagent-cs-k8s-protection-agent -n falcon-kubernetes-protection
    ```

