# CrowdStrike Falcon Helm Repository

<br><br>
### Add the CrowdStrike Falcon Helm repository

```
helm repo add crowdstrike https://crowdstrike.github.io/falcon-helm
```

<br>
### Install CrowdStrike Falcon Helm Chart

```
helm upgrade --install falcon-helm crowdstrike/falcon-sensor \
    --set falcon.cid="<CrowdStrike_CID>" \
    --set node.image.repository="<Your_Registry>/falcon-node-sensor"
```

Above command will install the CrowdStrike Falcon Helm Chart with the release name `falcon-helm` in the namespace your `kubectl` context is currently set to.
You can install also install into a customized namespace by running the following:

```
helm upgrade --install falcon-helm crowdstrike/falcon-sensor \
    -n falcon-system --create-namespace \
    --set falcon.cid="<CrowdStrike_CID>" \
    --set node.image.repository="<Your_Registry>/falcon-node-sensor"
``` 

For more details please see the [falcon-helm](https://github.com/CrowdStrike/falcon-helm) repository.
