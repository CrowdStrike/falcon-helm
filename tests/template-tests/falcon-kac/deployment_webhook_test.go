package falcon_kac

import (
	"fmt"
	"strings"
	"testing"

	"github.com/crowdstrike/falcon-helm/tests/template-tests/common"
	"github.com/google/go-cmp/cmp"
	"github.com/gruntwork-io/terratest/modules/helm"
	appsv1 "k8s.io/api/apps/v1"
)

func TestKACDeploymentImageManagement(t *testing.T) {
	var deployment appsv1.Deployment

	values := map[string]string{
		"falcon.cid":       common.CID,
		"image.digest":     common.ImageDigest,
		"image.repository": common.Repository,
	}
	options := &helm.Options{
		SetValues: values,
	}

	output := helm.RenderTemplate(
		t, options, common.FalconKACChartPath, common.ReleaseName,
		[]string{"templates/deployment_webhook.yaml"})

	allRange := strings.Split(output, "---")

	helm.UnmarshalK8SYaml(t, allRange[2], &deployment)

	want := fmt.Sprintf("%s@%s", common.Repository, common.ImageDigest)
	got := deployment.Spec.Template.Spec.Containers[0].Image
	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("Mismatch when using image digest (-want +got): %s", diff)
	}
}
