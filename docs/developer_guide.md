# Developer Guide

## Requirements

The following need to be installed to develop and test the Helm Operator and the Helm Chart.

* [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
* [Helm 3.x](https://helm.sh/docs/intro/install/)
* A working Kubernetes cluster

## Helm Operator

## Helm Charts

### Updating the Chart.yaml

The `Chart.yaml` file requires a version bump for any changes that take place in any helm chart.
Both `version` and `appVersion` need to be changed.

* The `PATCH` version field should be changed whenever there is documentation or typo changes made.
* The `MINOR` version field should be changed whenever there are values add/changed, minor functionality changes in the templates, etc.
* The `MAJOR` version field should be changed whenever there is a new sensor or product enhancement.

## Releases

As part of modern cloud native architecture and development, Helm charts will automatically be updated and released when a pull request is merged.
