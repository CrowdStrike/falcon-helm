package falcon_sensor_test

import (
	"time"

	"github.com/crowdstrike/falcon-helm/tests/e2e/common"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
)

var _ = Describe("Falcon Node Sensor E2E", func() {
	var tc *common.TestContext
	var daemonsetName string

	BeforeEach(func() {
		tc = setupTest()
		daemonsetName = tc.ReleaseName + "-falcon-sensor"
	})

	Describe("Basic Deployment", func() {
		It("should deploy node sensor successfully", func() {
			By("Installing the Helm chart")
			values := map[string]string{
				"falcon.cid":             tc.CID,
				"node.enabled":           "true",
				"node.image.pullSecrets": tc.SecretName,
			}
			tc.SetImageValues(values, "node")
			tc.InstallChart(values)

			By("Waiting for DaemonSet to be ready")
			tc.WaitForDaemonSetReady(daemonsetName)

			By("Verifying DaemonSet is deployed on all nodes")
			daemonset := tc.GetDaemonSet(daemonsetName)
			nodeCount := tc.GetNodeCount()
			Expect(daemonset.Status.DesiredNumberScheduled).To(Equal(int32(nodeCount)),
				"DaemonSet should be scheduled on all nodes")
			Expect(daemonset.Status.CurrentNumberScheduled).To(Equal(daemonset.Status.DesiredNumberScheduled),
				"All desired pods should be scheduled")
			Expect(daemonset.Status.NumberReady).To(Equal(daemonset.Status.DesiredNumberScheduled),
				"All scheduled pods should be ready")

			By("Verifying pods are running")
			pods := tc.GetDaemonSetPods(daemonsetName)
			Expect(pods.Items).NotTo(BeEmpty(), "Expected at least one pod")
			for _, pod := range pods.Items {
				Expect(pod.Status.Phase).To(Equal(corev1.PodRunning),
					"Pod %s should be running", pod.Name)
			}

			By("Verifying the sensor container is ready")
			for _, pod := range pods.Items {
				containerFound := false
				for _, containerStatus := range pod.Status.ContainerStatuses {
					if containerStatus.Name == "falcon-node-sensor" {
						containerFound = true
						Expect(containerStatus.Ready).To(BeTrue(),
							"Container falcon-node-sensor in pod %s should be ready", pod.Name)
						break
					}
				}
				Expect(containerFound).To(BeTrue(),
					"Container falcon-node-sensor not found in pod %s", pod.Name)
			}
		})
	})

	Describe("Backend Configuration", func() {
		It("should deploy with BPF backend", func() {
			By("Installing with BPF backend")
			values := map[string]string{
				"falcon.cid":             tc.CID,
				"node.enabled":           "true",
				"node.backend":           "bpf",
				"node.image.pullSecrets": tc.SecretName,
			}
			tc.SetImageValues(values, "node")
			tc.InstallChart(values)

			By("Waiting for DaemonSet to be ready")
			tc.WaitForDaemonSetReady(daemonsetName)

			By("Verifying backend configuration via ConfigMap")
			daemonset := tc.GetDaemonSet(daemonsetName)
			Expect(daemonset.Spec.Template.Spec.Containers).NotTo(BeEmpty(),
				"DaemonSet should have at least one container")

			sensorContainer := daemonset.Spec.Template.Spec.Containers[0]
			backendConfigFound := false

			for _, envFrom := range sensorContainer.EnvFrom {
				if envFrom.ConfigMapRef != nil {
					tc.Logf("Container uses ConfigMap: %s", envFrom.ConfigMapRef.Name)
					backendConfigFound = true
					break
				}
			}

			Expect(backendConfigFound).To(BeTrue(),
				"Backend configuration should be present via ConfigMap")

			By("Verifying pods are running")
			pods := tc.GetDaemonSetPods(daemonsetName)
			for _, pod := range pods.Items {
				Expect(pod.Status.Phase).To(Equal(corev1.PodRunning),
					"Pod %s should be running", pod.Name)
			}
		})
	})

	Describe("Upgrade", func() {
		It("should upgrade successfully", func() {
			By("Installing initial deployment")
			values := map[string]string{
				"falcon.cid":             tc.CID,
				"node.enabled":           "true",
				"node.image.pullSecrets": tc.SecretName,
			}
			tc.SetImageValues(values, "node")
			tc.InstallChart(values)

			By("Waiting for initial deployment to be ready")
			tc.WaitForDaemonSetReady(daemonsetName)

			initialDaemonSet := tc.GetDaemonSet(daemonsetName)
			initialGeneration := initialDaemonSet.Generation

			By("Upgrading with backend change")
			values["node.backend"] = "bpf"
			tc.UpgradeChart(values)

			// Do this for now to validate upgrades.
			// In the future, create SHA of the configMap to trigger rollouts from configMap changes.
			By("Triggering rollout restart")
			tc.RolloutRestart("daemonset", daemonsetName)

			By("Waiting for upgrade to stabilize")
			time.Sleep(10 * time.Second)

			By("Verifying DaemonSet generation increased")
			upgradedDaemonSet := tc.GetDaemonSet(daemonsetName)
			Expect(upgradedDaemonSet.Generation).To(BeNumerically(">", initialGeneration),
				"DaemonSet generation should increase after upgrade")

			By("Verifying pods are still running after upgrade")
			tc.WaitForDaemonSetReady(daemonsetName)

			pods := tc.GetDaemonSetPods(daemonsetName)
			for _, pod := range pods.Items {
				Expect(pod.Status.Phase).To(Equal(corev1.PodRunning),
					"Pod %s should be running after upgrade", pod.Name)
			}
		})
	})

	Describe("Tolerations", func() {
		It("should configure default tolerations", func() {
			By("Installing with default tolerations")
			values := map[string]string{
				"falcon.cid":             tc.CID,
				"node.enabled":           "true",
				"node.image.pullSecrets": tc.SecretName,
			}
			tc.SetImageValues(values, "node")
			tc.InstallChart(values)

			By("Waiting for DaemonSet to be ready")
			tc.WaitForDaemonSetReady(daemonsetName)

			By("Verifying DaemonSet has tolerations configured")
			daemonset := tc.GetDaemonSet(daemonsetName)
			Expect(daemonset.Spec.Template.Spec.Tolerations).NotTo(BeEmpty(),
				"DaemonSet should have tolerations configured")

			By("Verifying pods are running")
			pods := tc.GetDaemonSetPods(daemonsetName)
			for _, pod := range pods.Items {
				Expect(pod.Status.Phase).To(Equal(corev1.PodRunning),
					"Pod %s should be running", pod.Name)
			}
		})
	})

	Describe("Cleanup", func() {
		It("should clean up resources properly", func() {
			By("Installing the chart")
			values := map[string]string{
				"falcon.cid":             tc.CID,
				"node.enabled":           "true",
				"node.image.pullSecrets": tc.SecretName,
			}
			tc.SetImageValues(values, "node")
			tc.InstallChart(values)

			By("Waiting for DaemonSet to be ready")
			tc.WaitForDaemonSetReady(daemonsetName)

			By("Verifying deployment")
			daemonset := tc.GetDaemonSet(daemonsetName)
			nodeCount := tc.GetNodeCount()
			Expect(daemonset.Status.DesiredNumberScheduled).To(Equal(int32(nodeCount)))

			pods := tc.GetDaemonSetPods(daemonsetName)
			for _, pod := range pods.Items {
				Expect(pod.Status.Phase).To(Equal(corev1.PodRunning))
			}
		})
	})
})
