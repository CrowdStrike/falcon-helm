# CrowdStrike Falcon Kubernetes Admission Controller Helm Chart
The Falcon Kubernetes Admission Controller (KAC) is a custom plugin that you can deploy to your Kubernetes cluster to monitor and review Kubernetes objects when they are created. It’s deployed to a worker node in a cluster, and when enabled, it listens to post-authenticated API requests from the control plane.

Admission control policies tell the Falcon KAC what to do when it observes an Indicator of Misconfiguration (IOM) on a Kubernetes object. You can customize policies to apply to different areas of the cluster by namespace or object label. You can configure the action that the Falcon KAC takes when it encounters a misconfiguration. It can take no action, generate an alert, or prevent the object from being deployed.

Together, the Falcon KAC and the admission control policies provide continuous visibility and protection across your Kubernetes cluster.


# Getting Started
To install and deploy the Falcon Kubernetes Admission Controller, your cluster environment must meet these requirements:

- Helm 3.x is installed and available in PATH
- Helm 3.x is supported by your Kubernetes distribution
- Your cluster is running on a supported x86_64 Kubernetes environment

The Falcon Kubernetes Admission Controller has been deployed and tested on these Kubernetes distributions:

- Amazon Elastic Kubernetes Service (EKS)
- Google Kubernetes Engine (GKE)
- Microsoft Azure Kubernetes Service (AKS)
- Red Hat OpenShift Container Platform 4.6 and later

Depending on your network environment, you might need to allow TLS traffic on port 443 between your network and our cloud's network addresses:

| CrowdStrike cloud | Network address                                                          |
|-------------------|--------------------------------------------------------------------------|
| US-1              | ts01-b.cloudsink.net<br/>lfodown01-b.cloudsink.net                       |
| US-2              | ts01-gyr-maverick.cloudsink.net<br/>lfodown01-gyr-maverick.cloudsink.net |
| EU-1              | ts01-lanner-lion.cloudsink.net<br/>lfodown01-lanner-lion.cloudsink.net   |
| US-GOV-1          | ts01-laggar-gcw.cloudsink.net<br/>lfodown01-laggar-gcw.cloudsink.net     |

# Falcon Kubernetes Admission Controller Architecture Overview 
The Falcon KAC runs as a pair of containers in a pod on the worker node. It listens to the Kubernetes API to monitor Kubernetes objects. When a new object is created, the Falcon KAC evaluates the new object against the admission control policy to identify IOMs. The admission control policy tells the Falcon KAC how to respond to new objects: do nothing, create an alert in the Falcon console, or prevent the object from being deployed.
The Falcon KAC comprises two containers:

- **Kubernetes Client (falcon-client)**  
This is the validating webhook that is responsible for listening to events from the Kubernetes API and forwarding them to the admission control process.
- **Admission controller (falcon-ac)**  
This is the controller process that is responsible for admission control policy management, cloud communication, and event handling.

The Falcon KAC does not monitor these namespaces:
- falcon-kac
- falcon-system
- kube-system
- kube-public

# Install Falcon Kubernetes Admission Controller


- Add the Crowdstrike Falcon Helm Repository:  
  ```
  helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
  ```
- Update the Falcon Helm Repository Cache
   ```
   helm repo update
   ```
- Set a variable for the Falcon KAC image repository:  
   ```
   export KAC_IMAGE_REPO=<registry_name>/falcon-kac
   ``` 
- Set a variable for the Falcon KAC image tag:    
   ```
   export KAC_IMAGE_TAG=<KAC_version>.container.x86_64.Release.<cloud_region>
   ```
   Example: The Falcon KAC image tag has this format `7.01.0-103.container.x86_64.Release.US-1`
   
- Set a Falcon CID variable:  
   ```
   export FALCON_CID=<your_CID_with_checksum>
   ```
**Tip**: To find your CID with checksum, go to the CrowdStrike Sensor download page. At the top of the page, locate your CID checksum, and then click **Copy your Customer ID checksum to the clipboard**.

## Install Falcon KAC Helm chart

- Install the Falcon KAC Helm chart to a new namespace:  
  ```
   helm install falcon-kac crowdstrike/falcon-kac \
    -n falcon-kac --create-namespace \
    --set falcon.cid=$FALCON_CID \
    --set image.repository=$KAC_IMAGE_REPO \
    --set image.tag=$KAC_IMAGE_TAG
  ```  
  **Tip**: Use the --set flag to pass individual values to the values file when running helm install. For a complete list and description of configurable parameters, run  
  ```
  helm show values crowdstrike/falcon-kac
  ```
- Optional: Install the Falcon KAC Helm from a private registry that requires authentication:If your registry requires authentication, you must create a Kubernetes secret that can fetch the image from the registry.
  - Log into your Docker registry.
  - Fetch the base64 encoded pull secret:
    ```
     cat ~/.docker/config.json | base64 -w 0
    ```
  - Save the base64 string as a variable for the pull secret:
    ```
     export IMAGE_PULL_TOKEN=<base64_encoded_string>
    ```

  ```
   helm install falcon-kac crowdstrike/falcon-kac \
      -n falcon-kac --create-namespace \
      --set falcon.cid=$FALCON_CID \
      --set image.repository=$KAC_IMAGE_REPO \
      --set image.tag=$KAC_IMAGE_TAG \
      --set image.registryConfigJSON=$IMAGE_PULL_TOKEN
    ```

- Verify that the Falcon KAC deployment is ready and the corresponding pod has a Running status:

  ```
   kubectl get deployments,pods -n falcon-kac
   NAME         READY   UP-TO-DATE   AVAILABLE   AGE
   falcon-kac   1/1     1            1           7d2h

   NAME                          READY   STATUS    RESTARTS         AGE
   falcon-kac-7cc7dd57fc-pvzzf   2/2     Running   0                7d2h
  ```
- Verify that the Falcon KAC has an AID: 
  ```
   kubectl exec deployment/falcon-kac -n falcon-kac -c falcon-ac -- falconctl -g --aid
  ```
  **Tip**: An AID is assigned to the Falcon KAC when it communicates with the Falcon cloud. If the Falcon KAC has an AID that is not all zeros, it is installed and running properly.

## Update Falcon KAC
When a new container image is available, you can update your Falcon KAC by passing the new container image to the Helm chart and then running a `helm upgrade` command. In general, Helm charts do not support auto-updating running resources. Falcon KAC does not support auto-update. You must manually update the Falcon KAC on your cluster or update through a GitOps or CI/CD pipeline per Kubernetes Best Operational and Security practices.
- Set a new variable for the Falcon KAC container image tag:
  ```
  export KAC_IMAGE_TAG=<KAC_version>.container.x86_64.Release.<cloud_region>
  ```

- Update your Helm chart with the new container image:
  ``` 
    helm upgrade --install falcon-kac $KAC_HELM_REPO \
       -n falcon-kac --create-namespace \
       --set falcon.cid=$FALCON_CID \
       --set image.repository=$KAC_IMAGE_REPO \
       --set image.tag=$KAC_IMAGE_TAG
  ```
  **Note**: Your deployment will update only when you change the inputs for helm upgrade, for example by changing the image reference. 

- Verify that the new version of the Falcon KAC is running on the falcon-kac pods:  
  ```
  kubectl get pods -n falcon-kac -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}'
  ```

   The output looks similar to the example below and shows that version  
   falcon-kac:7.01.0-103.container.x86_64.Release.US-1 is running on both Falcon KAC pods.
   ```
   falcon-kac-5bd6986f6f-x86vw: falcon-kac:7.01.0-103.container.x86_64.Release.US-1, falcon-kac:7.01.0-103.container.x86_64.Release.US-1,
   ```

## Uninstall Falcon KAC
- Uninstall the admission controller from the falcon-kac namespace:
  ```
  helm uninstall falcon-kac -n falcon-kac
  ```
  <br/>
- Delete the namespace:
  ```
  kubectl delete ns falcon-kac
  ```
# Falcon Configuration Options

The following tables lists the Falcon KAC  configurable parameters and their default values.

| Parameter                   | Description                                           | Default               |
|:----------------------------|:------------------------------------------------------|:----------------------|
| `falcon.cid`                | CrowdStrike Customer ID (CID)                         | None       (Required) |
| `falcon.apd`                | App Proxy Disable (APD)                               | None                  |
| `falcon.aph`                | App Proxy Hostname (APH)                              | None                  |
| `falcon.app`                | App Proxy Port (APP)                                  | None                  |
| `falcon.trace`              | Set trace level. (`none`,`err`,`warn`,`info`,`debug`) | `none`                |
| `falcon.feature`            | Sensor Feature options                                | None                  |
| `falcon.billing`            | Utilize default or metered billing                    | None                  |
| `falcon.tags`               | Comma separated list of tags for sensor grouping      | None                  |
| `falcon.provisioning_token` | Provisioning token value                              | None                  |
