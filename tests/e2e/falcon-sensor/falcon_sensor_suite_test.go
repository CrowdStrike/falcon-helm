package falcon_sensor_test

import (
	"context"
	"fmt"
	"math/rand/v2"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"github.com/crowdstrike/falcon-helm/tests/e2e/common"
	"github.com/crowdstrike/gofalcon/falcon"
	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

var (
	activeTests   = make(map[*common.TestContext]bool)
	activeTestsMu sync.Mutex
)

func TestFalconSensor(t *testing.T) {
	RegisterFailHandler(Fail)

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-sigChan
		GinkgoWriter.Println("\n\nReceived interrupt signal, cleaning up test resources...")
		cleanupAllActiveTests()
		os.Exit(130)
	}()

	RunSpecs(t, "Falcon Sensor E2E Suite")
}

func registerTestContext(tc *common.TestContext) {
	activeTestsMu.Lock()
	defer activeTestsMu.Unlock()
	activeTests[tc] = true
}

func unregisterTestContext(tc *common.TestContext) {
	activeTestsMu.Lock()
	defer activeTestsMu.Unlock()
	delete(activeTests, tc)
}

func cleanupAllActiveTests() {
	activeTestsMu.Lock()
	defer activeTestsMu.Unlock()

	for tc := range activeTests {
		GinkgoWriter.Println("Cleaning up test namespace:", tc.Namespace)
		tc.Cleanup()
	}
}

func setupTest() *common.TestContext {
	ginkgoT := GinkgoT()

	namespaceName := fmt.Sprintf("falcon-test-%s", strings.ToLower(randomString(8)))
	releaseName := fmt.Sprintf("falcon-test-%s", strings.ToLower(randomString(8)))

	kubeconfigPath := os.Getenv("KUBECONFIG")
	if kubeconfigPath == "" {
		homeDir, err := os.UserHomeDir()
		Expect(err).NotTo(HaveOccurred(), "Failed to get home directory")
		kubeconfigPath = filepath.Join(homeDir, ".kube", "config")
	}

	kubectlOptions := k8s.NewKubectlOptions("", kubeconfigPath, namespaceName)

	tc := &common.TestContext{
		T:              ginkgoT,
		KubectlOptions: kubectlOptions,
		Namespace:      namespaceName,
		ReleaseName:    releaseName,
		ChartPath:      common.FalconSensorChartPath,
		HelmOptions: &helm.Options{
			KubectlOptions: kubectlOptions,
			Logger:         logger.Discard,
		},
	}

	tc.Logf("Creating test namespace: %s", tc.Namespace)

	clientset, err := k8s.GetKubernetesClientFromOptionsE(ginkgoT, tc.KubectlOptions)
	Expect(err).NotTo(HaveOccurred(), "Failed to get Kubernetes client")
	tc.Clientset = clientset

	k8s.CreateNamespace(ginkgoT, tc.KubectlOptions, tc.Namespace)

	tc.Logf("Waiting for namespace to become available")
	Eventually(func() bool {
		ns, err := tc.Clientset.CoreV1().Namespaces().Get(
			context.Background(),
			tc.Namespace,
			metav1.GetOptions{},
		)
		return err == nil && ns.Status.Phase == corev1.NamespaceActive
	}).WithTimeout(60*time.Second).
		WithPolling(1*time.Second).
		Should(BeTrue(), "Namespace should become available")

	tc.Logf("Test namespace %s created successfully", tc.Namespace)

	err = tc.SetupFalconClient()
	if err != nil {
		tc.Logf("Falcon API client not configured: %v", err)
	} else {
		tc.Logf("Falcon API client initialized successfully")
	}

	cid := os.Getenv("FALCON_CID")
	if cid == "" {
		cid, err = common.GetFalconCID(context.Background())
		Expect(err).NotTo(HaveOccurred(), "Failed to get Falcon CID")
	}
	tc.CID = cid

	secretName := tc.CreateImagePullSecret()
	tc.SecretName = secretName
	if secretName != "" {
		tc.Logf("Image pull secret created: %s", secretName)
	}

	img := os.Getenv("IMG")
	if img == "" && tc.FalconClient != nil && tc.CID != "" {
		tc.Logf("IMG not set, attempting to auto-discover latest node sensor image...")

		username, err := common.GenerateUsername(tc.CID)
		if err != nil {
			tc.Logf("Failed to generate username: %v", err)
		} else {
			tc.Logf("Generated registry username: %s", username)
			token, err := common.GetRegistryToken(context.Background(), tc.FalconClient)
			if err != nil {
				tc.Logf("Failed to get registry token: %v", err)
			} else {
				tc.Logf("Retrieved registry token (length: %d)", len(token))
				tc.Logf("Using cloud type: %s", tc.CloudType.Host())
				discoveredImg, err := common.GetLatestSensorImage(context.Background(), username, token, tc.CloudType, falcon.NodeSensor)
				if err != nil {
					tc.Logf("Failed to auto-discover image: %v", err)
				} else {
					img = discoveredImg
					tc.Logf("Auto-discovered image: %s", discoveredImg)
				}
			}
		}
	}
	tc.Image = img

	registerTestContext(tc)

	DeferCleanup(func() {
		unregisterTestContext(tc)
		tc.Cleanup()
	})

	return tc
}

func randomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyz0123456789"
	result := make([]byte, length)
	for i := range result {
		result[i] = charset[rand.IntN(len(charset))]
	}
	return string(result)
}
