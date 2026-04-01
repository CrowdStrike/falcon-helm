package common

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sort"
	"strings"

	"github.com/containers/image/v5/docker"
	"github.com/containers/image/v5/docker/reference"
	"github.com/containers/image/v5/types"
	"github.com/crowdstrike/gofalcon/falcon"
	"github.com/crowdstrike/gofalcon/falcon/client"
	"github.com/crowdstrike/gofalcon/falcon/client/falcon_container"
	"github.com/crowdstrike/gofalcon/falcon/client/sensor_download"
	version "github.com/hashicorp/go-version"
)

// GetFalconRegistryCredentials retrieves Docker registry credentials from the Falcon API
// Returns registry server, username, password/token, and error
func GetFalconRegistryCredentials(ctx context.Context, clientID, clientSecret, cloud string) (server, username, token string, err error) {
	if clientID == "" || clientSecret == "" {
		return "", "", "", errors.New("FALCON_CLIENT_ID and FALCON_CLIENT_SECRET must be set")
	}

	cloudType, err := falcon.CloudValidate(cloud)
	if err != nil {
		return "", "", "", err
	}

	apiConfig := &falcon.ApiConfig{
		ClientId:     clientID,
		ClientSecret: clientSecret,
		Cloud:        cloudType,
		Context:      ctx,
	}

	if cloud == "" || cloud == "autodiscover" {
		err = apiConfig.Cloud.Autodiscover(ctx, clientID, clientSecret)
		if err != nil {
			return "", "", "", fmt.Errorf("failed to autodiscover Falcon cloud: %w", err)
		}
		cloudType = apiConfig.Cloud
	}

	client, err := falcon.NewClient(apiConfig)
	if err != nil {
		return "", "", "", fmt.Errorf("failed to authenticate with CrowdStrike API: %w", err)
	}

	token, err = GetRegistryToken(ctx, client)
	if err != nil {
		return "", "", "", fmt.Errorf("failed to fetch registry token: %w", err)
	}
	if token == "" {
		return "", "", "", errors.New("empty registry token received from CrowdStrike API")
	}

	ccid := os.Getenv("FALCON_CID")
	if ccid == "" {
		ccid, err = getCCID(ctx, client)
		if err != nil {
			return "", "", "", fmt.Errorf("failed to fetch CCID: %w", err)
		}
		if ccid == "" {
			return "", "", "", errors.New("empty CCID received from CrowdStrike API")
		}
	}

	username, err = GenerateUsername(ccid)
	if err != nil {
		return "", "", "", err
	}

	server = "registry.crowdstrike.com"

	return server, username, token, nil
}

func GetRegistryToken(ctx context.Context, client *client.CrowdStrikeAPISpecification) (string, error) {
	res, err := client.FalconContainer.GetCredentials(&falcon_container.GetCredentialsParams{
		Context: ctx,
	})
	if err != nil {
		return "", err
	}

	payload := res.GetPayload()
	if err = falcon.AssertNoError(payload.Errors); err != nil {
		return "", err
	}

	resources := payload.Resources
	if len(resources) != 1 {
		return "", fmt.Errorf("expected to receive exactly one token, but got %d", len(resources))
	}

	valueString := *resources[0].Token
	if valueString == "" {
		return "", errors.New("received empty token from API")
	}

	return valueString, nil
}

func getCCID(ctx context.Context, client *client.CrowdStrikeAPISpecification) (string, error) {
	response, err := client.SensorDownload.GetSensorInstallersCCIDByQuery(&sensor_download.GetSensorInstallersCCIDByQueryParams{
		Context: ctx,
	})
	if err != nil {
		return "", fmt.Errorf("could not get CCID from CrowdStrike Falcon API: %w", err)
	}

	payload := response.GetPayload()
	if err = falcon.AssertNoError(payload.Errors); err != nil {
		return "", fmt.Errorf("error reported when getting CCID from CrowdStrike Falcon API: %w", err)
	}

	if len(payload.Resources) != 1 {
		return "", fmt.Errorf("failed to get CCID: unexpected API response: %v", payload.Resources)
	}

	return payload.Resources[0], nil
}

// GenerateUsername creates the Docker registry username from CCID
// Format: fc-<lowercased-checksum> where CCID is <CHECKSUM>-<CC>
func GenerateUsername(ccid string) (string, error) {
	parts := strings.Split(ccid, "-")
	if len(parts) != 2 {
		return "", fmt.Errorf("invalid CCID format, expected '<checksum>-<cc>' but got: %s", ccid)
	}
	lowerChecksum := strings.ToLower(parts[0])
	return fmt.Sprintf("fc-%s", lowerChecksum), nil
}

// GetFalconCID retrieves the Falcon CID from environment or API
func GetFalconCID(ctx context.Context) (string, error) {
	cid := os.Getenv("FALCON_CID")
	if cid != "" {
		return cid, nil
	}

	clientID := os.Getenv("FALCON_CLIENT_ID")
	clientSecret := os.Getenv("FALCON_CLIENT_SECRET")
	cloud := os.Getenv("FALCON_CLOUD")

	if clientID == "" || clientSecret == "" {
		return "", errors.New("FALCON_CID not set and FALCON_CLIENT_ID/FALCON_CLIENT_SECRET not available to fetch from API")
	}

	cloudType, err := falcon.CloudValidate(cloud)
	if err != nil {
		return "", err
	}

	apiConfig := &falcon.ApiConfig{
		ClientId:     clientID,
		ClientSecret: clientSecret,
		Cloud:        cloudType,
		Context:      ctx,
	}

	if cloud == "" || cloud == "autodiscover" {
		err = apiConfig.Cloud.Autodiscover(ctx, clientID, clientSecret)
		if err != nil {
			return "", fmt.Errorf("failed to autodiscover Falcon cloud: %w", err)
		}
	}

	client, err := falcon.NewClient(apiConfig)
	if err != nil {
		return "", fmt.Errorf("failed to authenticate with CrowdStrike API: %w", err)
	}

	cid, err = getCCID(ctx, client)
	if err != nil {
		return "", fmt.Errorf("failed to fetch CID from API: %w", err)
	}

	return cid, nil
}

// GetLatestSensorImage retrieves the latest sensor image tag from CrowdStrike registry
// Returns the full image URI with the latest tag
func GetLatestSensorImage(ctx context.Context, username, token string, cloudType falcon.CloudType, sensorType falcon.SensorType) (string, error) {
	if username == "" || token == "" {
		return "", errors.New("username and token are required for registry authentication")
	}

	imageURI := falcon.FalconContainerSensorImageURI(cloudType, sensorType)

	systemContext := &types.SystemContext{
		DockerAuthConfig: &types.DockerAuthConfig{
			Username: username,
			Password: token,
		},
		OSChoice:           "linux",
		ArchitectureChoice: "amd64",
	}

	ref, err := reference.ParseNormalizedNamed(imageURI)
	if err != nil {
		return "", fmt.Errorf("failed to parse image URI '%s': %w", imageURI, err)
	}

	imgRef, err := docker.NewReference(reference.TagNameOnly(ref))
	if err != nil {
		return "", fmt.Errorf("failed to create image reference from '%s': %w", imageURI, err)
	}

	tags, err := docker.GetRepositoryTags(ctx, systemContext, imgRef)
	if err != nil {
		return "", fmt.Errorf("failed to list repository tags (username=%s, image=%s): %w", username, imageURI, err)
	}

	if len(tags) == 0 {
		return "", fmt.Errorf("no tags found in registry for image: %s", imageURI)
	}

	// Filter tags that start with a digit (version tags)
	versionTags := []string{}
	for _, tag := range tags {
		if len(tag) > 0 && tag[0] >= '0' && tag[0] <= '9' {
			versionTags = append(versionTags, tag)
		}
	}

	if len(versionTags) == 0 {
		return "", fmt.Errorf("no version tags found in registry (found %d total tags)", len(tags))
	}

	// Sort tags by semantic version
	sort.Slice(versionTags, func(i, j int) bool {
		v1, err1 := version.NewVersion(versionTags[i])
		v2, err2 := version.NewVersion(versionTags[j])
		if err1 != nil || err2 != nil {
			// Fallback to string comparison if version parsing fails
			return versionTags[i] < versionTags[j]
		}
		return v1.LessThan(v2)
	})

	latestTag := versionTags[len(versionTags)-1]
	return fmt.Sprintf("%s:%s", imageURI, latestTag), nil
}
