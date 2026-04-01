package falcon_sensor

import (
	"fmt"
	"testing"

	"github.com/crowdstrike/falcon-helm/tests/template-tests/common"
	"github.com/google/go-cmp/cmp"
	"github.com/gruntwork-io/terratest/modules/helm"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
)

func TestNodeDaemonsetImageManagement(t *testing.T) {
	values := map[string]string{
		"falcon.cid":            common.CID,
		"node.image.digest":     common.ImageDigest,
		"node.image.repository": common.Repository,
	}
	options := &helm.Options{
		SetValues: values,
	}

	output := helm.RenderTemplate(
		t, options, common.FalconSensorChartPath, common.ReleaseName,
		[]string{"templates/daemonset.yaml"})

	var daemonset appsv1.DaemonSet
	helm.UnmarshalK8SYaml(t, output, &daemonset)

	want := fmt.Sprintf("%s@%s", common.Repository, common.ImageDigest)
	got := daemonset.Spec.Template.Spec.Containers[0].Image
	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("Mismatch when using image digest (-want +got): %s", diff)
	}
}

func TestDaemonsetAutopilotEnabled(t *testing.T) {
	values := map[string]string{
		"falcon.cid":         common.CID,
		"node.gke.autopilot": "true",
	}
	options := &helm.Options{
		SetValues: values,
	}

	output := helm.RenderTemplate(
		t, options, common.FalconSensorChartPath, common.ReleaseName,
		[]string{"templates/daemonset.yaml"})

	var daemonset appsv1.DaemonSet
	helm.UnmarshalK8SYaml(t, output, &daemonset)

	want := &corev1.Capabilities{
		Add: []corev1.Capability{
			"SYS_ADMIN",
			"SYS_PTRACE",
			"SYS_CHROOT",
			"DAC_READ_SEARCH",
		},
	}

	got := daemonset.Spec.Template.Spec.InitContainers[0].SecurityContext.Capabilities
	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("GKE Autopilot Init Container security context capabilities mismatch (-want +got): %s", diff)
	}

	want = &corev1.Capabilities{
		Add: []corev1.Capability{
			"SYS_ADMIN",
			"SETGID",
			"SETUID",
			"SYS_PTRACE",
			"SYS_CHROOT",
			"DAC_OVERRIDE",
			"SETPCAP",
			"DAC_READ_SEARCH",
			"BPF",
			"PERFMON",
			"SYS_RESOURCE",
			"NET_RAW",
			"CHOWN",
			"NET_ADMIN",
		},
	}

	got = daemonset.Spec.Template.Spec.Containers[0].SecurityContext.Capabilities
	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("GKE Autopilot Sensor Container security context capabilities mismatch (-want +got): %s", diff)
	}
}
