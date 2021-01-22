# falcon-helm

# Installation

## Using Helm Charts

### Using Helm from the Git Repository:

To install using Helm, run the following command replacing
`<Your_CrowdStrike_CID>` with your CrowdStrike Customer ID:

```
helm install --set falcon.cid=<Your_CrowdStrike_CID> falcon-helm ./helm-charts/falcon-sensor
```

You can use multiple `--set` arguments for configuring the Falcon Helm Chart
according to your environment. See the [values yaml file for more configuration options](helm-charts/falcon-sensor/values.yaml).

Alternatively instead of using multiple `--set` arguments, you can create a yaml
file that customizes the default Helm Chart configurations.

For example changing the default image repository using a yaml customization
file called `custom_repo.yaml`:

1. Create `custom_repo.yaml`:

```
falcon:
  cid: <Your_CrowdStrike_CID>
image:
  repository: 192.168.2.3:5000/falcon-sensor
```

2. Run the `helm install` command specifying using `custom_repo.yaml`:

```
helm install -f `custom_repo.yaml` falcon-helm ./helm-charts/falcon-sensor
```

### Using Make from the Git Repository:

To install using a Makefile (assumes Helm is installed on your system), run the
following command replacing `<Your_CrowdStrike_CID>` with your CrowdStrike
Customer ID:

```
make helm-install CID=<Your_CrowdStrike_CID>
```

# Uninstalling

## Using Helm Charts

### Uninstalling with Helm

Assuming the Falcon helm chart is the same and has not been customized, run the
following command:

```
helm uninstall falcon-helm
```

### Uninstalling with Make from the Git Repository:

```
make helm-uninstall
```
