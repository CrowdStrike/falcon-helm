package common

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/crowdstrike/gofalcon/falcon"
	"github.com/crowdstrike/gofalcon/falcon/client"
	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/require"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

const (
	FalconSensorChartPath = "../../../helm-charts/falcon-sensor"

	DefaultTimeout   = 5 * time.Minute
	PodReadyTimeout  = 10 * time.Minute
	DaemonSetTimeout = 10 * time.Minute
	CleanupTimeout   = 3 * time.Minute

	ImagePullSecretName = "falcon-test-registry-secret"
)

// enableRealTimeOutput controls whether logs are written to stdout immediately
// Set E2E_REALTIME_OUTPUT=false to disable real-time output
var enableRealTimeOutput = os.Getenv("E2E_REALTIME_OUTPUT") != "false"

// TestingT defines the minimal testing interface needed by TestContext
// This allows compatibility with both *testing.T and Ginkgo's GinkgoT
// It matches terratest's TestingT interface requirements
type TestingT interface {
	Helper()
	Log(args ...any)
	Logf(format string, args ...any)
	Error(args ...any)
	Errorf(format string, args ...any)
	Fatal(args ...any)
	Fatalf(format string, args ...any)
	Fail()
	FailNow()
	Failed() bool
	Name() string
}

// TestContext holds common test context and resources
type TestContext struct {
	T              TestingT
	KubectlOptions *k8s.KubectlOptions
	Namespace      string
	ReleaseName    string
	ChartPath      string
	HelmOptions    *helm.Options
	SecretName     string
	CID            string
	Image          string
	Clientset      *kubernetes.Clientset
	FalconClient   *client.CrowdStrikeAPISpecification
	CloudType      falcon.CloudType
}

// Logf logs a message to both the test framework and stdout for real-time visibility
func (tc *TestContext) Logf(format string, args ...any) {
	msg := fmt.Sprintf(format, args...)

	tc.T.Log(msg)

	if enableRealTimeOutput {
		timestamp := time.Now().Format("15:04:05")
		fmt.Printf("[%s] %s: %s\n", timestamp, tc.Namespace, msg)
	}
}

// SetupFalconClient initializes the Falcon API client once for reuse
func (tc *TestContext) SetupFalconClient() error {
	tc.T.Helper()

	clientID := os.Getenv("FALCON_CLIENT_ID")
	clientSecret := os.Getenv("FALCON_CLIENT_SECRET")
	cloud := os.Getenv("FALCON_CLOUD")

	if clientID == "" || clientSecret == "" {
		return nil
	}

	cloudType, err := falcon.CloudValidate(cloud)
	if err != nil {
		return fmt.Errorf("failed to validate cloud type: %w", err)
	}

	apiConfig := &falcon.ApiConfig{
		ClientId:     clientID,
		ClientSecret: clientSecret,
		Cloud:        cloudType,
		Context:      context.Background(),
	}

	if cloud == "" || cloud == "autodiscover" {
		err = apiConfig.Cloud.Autodiscover(context.Background(), clientID, clientSecret)
		if err != nil {
			return fmt.Errorf("failed to autodiscover Falcon cloud: %w", err)
		}
		cloudType = apiConfig.Cloud
	}

	tc.FalconClient, err = falcon.NewClient(apiConfig)
	if err != nil {
		return fmt.Errorf("failed to create Falcon API client: %w", err)
	}

	tc.CloudType = cloudType
	tc.Logf("Falcon API client initialized for cloud: %s", cloudType.Host())

	return nil
}

// waitUntilNamespaceAvailable waits until the namespace is available
func (tc *TestContext) waitUntilNamespaceAvailable() {
	tc.T.Helper()

	maxRetries := 60
	sleepBetweenRetries := 1 * time.Second

	for range maxRetries {
		ns, err := tc.Clientset.CoreV1().Namespaces().Get(
			context.Background(),
			tc.Namespace,
			metav1.GetOptions{},
		)
		if err == nil && ns.Status.Phase == corev1.NamespaceActive {
			return
		}
		time.Sleep(sleepBetweenRetries)
	}

	require.FailNow(tc.T, "Namespace %s did not become available in time", tc.Namespace)
}

// Cleanup removes all test resources
func (tc *TestContext) Cleanup() {
	tc.T.Helper()
	tc.Logf("Cleaning up test resources in namespace: %s", tc.Namespace)

	if tc.isHelmReleaseInstalled() {
		tc.Logf("Uninstalling Helm release: %s", tc.ReleaseName)
		helm.Delete(tc.T, tc.HelmOptions, tc.ReleaseName, true)

		tc.WaitForCleanupDaemonSetComplete()
		tc.WaitForAllDaemonSetsDeleted()
	}

	tc.Logf("Deleting namespace: %s", tc.Namespace)
	k8s.DeleteNamespace(tc.T, tc.KubectlOptions, tc.Namespace)
}

// isHelmReleaseInstalled checks if a Helm release is installed
func (tc *TestContext) isHelmReleaseInstalled() bool {
	tc.T.Helper()

	output, err := helm.RunHelmCommandAndGetOutputE(
		tc.T,
		tc.HelmOptions,
		"list",
		"--filter", tc.ReleaseName,
		"--output", "json",
	)
	if err != nil {
		return false
	}

	return len(output) > 2
}

func (tc *TestContext) InstallChart(values map[string]string) {
	tc.T.Helper()
	tc.Logf("Installing Helm chart: %s", tc.ChartPath)

	tc.HelmOptions.SetValues = values

	helm.Install(tc.T, tc.HelmOptions, tc.ChartPath, tc.ReleaseName)
	tc.Logf("Helm chart installed successfully: %s", tc.ReleaseName)
}

func (tc *TestContext) UpgradeChart(values map[string]string) {
	tc.T.Helper()
	tc.Logf("Upgrading Helm release: %s", tc.ReleaseName)

	tc.HelmOptions.SetValues = values

	helm.Upgrade(tc.T, tc.HelmOptions, tc.ChartPath, tc.ReleaseName)
	tc.Logf("Helm chart upgraded successfully: %s", tc.ReleaseName)
}

func (tc *TestContext) RolloutRestart(resourceType, name string) {
	tc.T.Helper()
	tc.Logf("Triggering rollout restart for %s/%s", resourceType, name)

	k8s.RunKubectl(tc.T, tc.KubectlOptions, "rollout", "restart", resourceType+"/"+name)

	tc.Logf("Rollout restart triggered for %s/%s", resourceType, name)
}

func (tc *TestContext) GetDaemonSet(name string) *appsv1.DaemonSet {
	tc.T.Helper()

	daemonset, err := tc.Clientset.AppsV1().DaemonSets(tc.Namespace).Get(
		context.Background(),
		name,
		metav1.GetOptions{},
	)
	require.NoError(tc.T, err, "Failed to get DaemonSet %s", name)

	return daemonset
}

func (tc *TestContext) GetDaemonSetPods(daemonsetName string) *corev1.PodList {
	tc.T.Helper()

	daemonset := tc.GetDaemonSet(daemonsetName)

	labelSelector := metav1.FormatLabelSelector(daemonset.Spec.Selector)
	pods, err := tc.Clientset.CoreV1().Pods(tc.Namespace).List(
		context.Background(),
		metav1.ListOptions{
			LabelSelector: labelSelector,
		},
	)
	require.NoError(tc.T, err, "Failed to list pods for DaemonSet %s", daemonsetName)

	return pods
}

func (tc *TestContext) GetNodeCount() int {
	tc.T.Helper()

	nodes, err := tc.Clientset.CoreV1().Nodes().List(
		context.Background(),
		metav1.ListOptions{},
	)
	require.NoError(tc.T, err, "Failed to list nodes")

	schedulableCount := 0
	for _, node := range nodes.Items {
		if !node.Spec.Unschedulable {
			schedulableCount++
		}
	}

	tc.Logf("Found %d schedulable node(s) in cluster", schedulableCount)
	return schedulableCount
}

// GetImageConfig returns the image repository and tag from TestContext or environment variables
func (tc *TestContext) GetImageConfig() (repository, tag string) {
	img := tc.Image
	if img == "" {
		img = os.Getenv("IMG")
	}
	if img == "" {
		panic("Image not set in TestContext and IMG environment variable is not set. Expected format: repository:tag")
	}

	parts := strings.Split(img, ":")
	if len(parts) != 2 {
		panic(fmt.Sprintf("Invalid image format: %s. Expected format: repository:tag", img))
	}

	return parts[0], parts[1]
}

func (tc *TestContext) SetImageValues(values map[string]string, prefix ...string) {
	repository, tag := tc.GetImageConfig()

	p := ""
	if len(prefix) > 0 {
		p = prefix[0]
		if p != "" {
			p = p + "."
		}
	}

	values[p+"image.repository"] = repository
	values[p+"image.tag"] = tag
}

// dockerAuthConfig represents a Docker registry authentication entry
type dockerAuthConfig struct {
	Auth string `json:"auth,omitempty"`
}

// dockerConfigFile represents the structure of .docker/config.json
type dockerConfigFile struct {
	Auths map[string]dockerAuthConfig `json:"auths"`
}

// GetRegistryConfig returns registry authentication configuration from environment
// Priority: 1. FALCON_CLIENT_ID+FALCON_CLIENT_SECRET, 2. REGISTRY_USERNAME+REGISTRY_PASSWORD, 3. DOCKER_CONFIG_JSON
func GetRegistryConfig() (server, username, password, dockerConfigJSON string, hasAuth bool) {
	clientID := os.Getenv("FALCON_CLIENT_ID")
	clientSecret := os.Getenv("FALCON_CLIENT_SECRET")
	cloud := os.Getenv("FALCON_CLOUD")

	if clientID != "" && clientSecret != "" {
		ctx := context.Background()
		server, username, token, err := GetFalconRegistryCredentials(ctx, clientID, clientSecret, cloud)
		if err == nil && server != "" && username != "" && token != "" {
			return server, username, token, "", true
		}
		fmt.Printf("Warning: Failed to get registry credentials from Falcon API: %v\n", err)
	}

	username = os.Getenv("REGISTRY_USERNAME")
	password = os.Getenv("REGISTRY_PASSWORD")
	server = os.Getenv("REGISTRY_SERVER")

	if username != "" && password != "" && server != "" {
		return server, username, password, "", true
	}

	dockerConfigJSON = os.Getenv("DOCKER_CONFIG_JSON")
	if dockerConfigJSON != "" {
		return "", "", "", dockerConfigJSON, true
	}

	return "", "", "", "", false
}

// CreateImagePullSecret creates a Kubernetes image pull secret in the test namespace
func (tc *TestContext) CreateImagePullSecret() string {
	tc.T.Helper()

	var server, username, password, dockerConfigJSON string
	var hasAuth bool

	if tc.FalconClient != nil {
		ctx := context.Background()

		token, err := GetRegistryToken(ctx, tc.FalconClient)
		if err == nil && token != "" {
			if tc.CID != "" {
				username, err = GenerateUsername(tc.CID)
				if err == nil {
					server = "registry.crowdstrike.com"
					password = token
					hasAuth = true
				}
			}
		}

		if err != nil {
			tc.Logf("Warning: Failed to get registry credentials from cached Falcon API client: %v", err)
		}
	}

	if !hasAuth {
		server, username, password, dockerConfigJSON, hasAuth = GetRegistryConfig()
	}

	if !hasAuth {
		return ""
	}

	tc.Logf("Creating image pull secret: %s", ImagePullSecretName)

	var secretData []byte

	if dockerConfigJSON != "" {
		secretData = []byte(dockerConfigJSON)
	} else {
		auths := dockerConfigFile{
			Auths: map[string]dockerAuthConfig{},
		}

		creds := base64.StdEncoding.EncodeToString([]byte(username + ":" + password))
		auths.Auths[server] = dockerAuthConfig{Auth: creds}

		configJSON, err := json.MarshalIndent(auths, "", "\t")
		require.NoError(tc.T, err, "Failed to marshal Docker config JSON")
		secretData = configJSON
	}

	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      ImagePullSecretName,
			Namespace: tc.Namespace,
		},
		Type: corev1.SecretTypeDockerConfigJson,
		Data: map[string][]byte{
			".dockerconfigjson": secretData,
		},
	}

	_, err := tc.Clientset.CoreV1().Secrets(tc.Namespace).Create(
		context.Background(),
		secret,
		metav1.CreateOptions{},
	)
	require.NoError(tc.T, err, "Failed to create image pull secret")

	tc.Logf("Image pull secret %s created successfully", ImagePullSecretName)
	return ImagePullSecretName
}

func (tc *TestContext) WaitForCleanupDaemonSetComplete() {
	tc.T.Helper()

	tc.Logf("Waiting for cleanup DaemonSet to appear (if any)...")
	cleanupDaemonSetName := ""
	maxWaitForAppearance := 30
	for range maxWaitForAppearance {
		daemonsets, err := tc.Clientset.AppsV1().DaemonSets(tc.Namespace).List(
			context.Background(),
			metav1.ListOptions{},
		)
		if err == nil && len(daemonsets.Items) > 0 {
			for _, ds := range daemonsets.Items {
				if strings.Contains(strings.ToLower(ds.Name), "cleanup") {
					cleanupDaemonSetName = ds.Name
					tc.Logf("Found cleanup DaemonSet: %s", cleanupDaemonSetName)
					break
				}
			}
			if cleanupDaemonSetName != "" {
				break
			}
		}
		time.Sleep(1 * time.Second)
	}

	if cleanupDaemonSetName == "" {
		tc.Logf("No cleanup DaemonSet found, skipping cleanup wait")
		return
	}

	tc.Logf("Waiting for cleanup DaemonSet %s to complete...", cleanupDaemonSetName)
	maxRetries := 120
	sleepBetweenRetries := 1 * time.Second

	for i := 0; i < maxRetries; i++ {
		daemonset, err := tc.Clientset.AppsV1().DaemonSets(tc.Namespace).Get(
			context.Background(),
			cleanupDaemonSetName,
			metav1.GetOptions{},
		)
		if err != nil {
			tc.Logf("Cleanup DaemonSet %s has been deleted, cleanup complete", cleanupDaemonSetName)
			return
		}

		if daemonset.Status.DesiredNumberScheduled > 0 {
			if daemonset.Status.NumberReady == daemonset.Status.DesiredNumberScheduled {
				tc.Logf("Cleanup DaemonSet %s: All pods ready (%d/%d), waiting for completion...",
					cleanupDaemonSetName,
					daemonset.Status.NumberReady,
					daemonset.Status.DesiredNumberScheduled)
			} else {
				tc.Logf("Cleanup DaemonSet %s: Progress (%d/%d ready)",
					cleanupDaemonSetName,
					daemonset.Status.NumberReady,
					daemonset.Status.DesiredNumberScheduled)
			}
		}

		time.Sleep(sleepBetweenRetries)
	}

	tc.Logf("Warning: Cleanup DaemonSet %s still exists after timeout, proceeding anyway", cleanupDaemonSetName)
}

func (tc *TestContext) WaitForAllDaemonSetsDeleted() {
	tc.T.Helper()
	tc.Logf("Waiting for all DaemonSets to be deleted from namespace: %s", tc.Namespace)

	maxRetries := 120
	sleepBetweenRetries := 1 * time.Second

	for i := 0; i < maxRetries; i++ {
		daemonsets, err := tc.Clientset.AppsV1().DaemonSets(tc.Namespace).List(
			context.Background(),
			metav1.ListOptions{},
		)
		if err == nil && len(daemonsets.Items) == 0 {
			tc.Logf("All DaemonSets deleted successfully")
			return
		}

		if err == nil && len(daemonsets.Items) > 0 {
			daemonsetNames := make([]string, 0, len(daemonsets.Items))
			for _, ds := range daemonsets.Items {
				daemonsetNames = append(daemonsetNames, ds.Name)
			}
			tc.Logf("Waiting for DaemonSets to be deleted: %v", daemonsetNames)
		}

		time.Sleep(sleepBetweenRetries)
	}

	tc.Logf("Warning: Some DaemonSets still exist after timeout, proceeding with namespace deletion anyway")
}

func (tc *TestContext) WaitForDaemonSetReady(daemonsetName string) {
	tc.T.Helper()
	Eventually(func() bool {
		daemonset, err := tc.Clientset.AppsV1().DaemonSets(tc.Namespace).Get(
			context.Background(),
			daemonsetName,
			metav1.GetOptions{},
		)
		if err != nil {
			return false
		}
		return daemonset.Status.DesiredNumberScheduled > 0 &&
			daemonset.Status.NumberReady == daemonset.Status.DesiredNumberScheduled &&
			daemonset.Status.UpdatedNumberScheduled == daemonset.Status.DesiredNumberScheduled
	}).WithTimeout(10*time.Minute).
		WithPolling(10*time.Second).
		Should(BeTrue(), "DaemonSet should become ready")
}
