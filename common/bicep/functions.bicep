@description('Collapses repeated hyphens and trims leading or trailing hyphens.')
func normalizeHyphenatedName(value string) string => join(filter(split(value, '-'), segment => !empty(segment)), '-')

@description('Builds a unique string based on the subscription ID to ensure resource name uniqueness across deployments.')
func getUniqueSuffix(seed string) string => take(uniqueString(seed, subscription().id), 4)

@description('Builds the standard stack prefix with the subscription-scoped uniqueness suffix.')
@export()
func getPrefix(deploymentStackName string) string =>
  normalizeHyphenatedName('${deploymentStackName}-${getUniqueSuffix(deploymentStackName)}')

@description('Builds a shortened stack prefix while preserving the uniqueness suffix within the requested max length.')
@export()
func getShortPrefix(deploymentStackName string, maxLength int) string =>
  normalizeHyphenatedName('${take(deploymentStackName, max(maxLength - length(getUniqueSuffix(deploymentStackName)) - 1, 1))}-${getUniqueSuffix(deploymentStackName)}')

@description('Builds the standard stack prefix for resources that allow only lowercase letters and numbers.')
@export()
func getAlphaNumericPrefix(deploymentStackName string) string =>
  replace(toLower(getPrefix(deploymentStackName)), '-', '')

@description('Builds a shortened lowercase alphanumeric stack prefix while preserving the uniqueness suffix within the requested max length.')
@export()
func getShortAlphaNumericPrefix(deploymentStackName string, maxLength int) string =>
  replace(
    getShortPrefix(deploymentStackName, max(maxLength - length(getUniqueSuffix(deploymentStackName)) - 1, 1)),
    '-',
    ''
  )

@description('Gets the resource group name from a full Azure resource ID.')
@export()
func getResourceGroupName(resourceId string) string => split(resourceId, '/')[4]

@description('Gets the resource name from a full Azure resource ID.')
@export()
func getResourceName(resourceId string) string => last(split(resourceId, '/'))

@description('Gets the immediate parent resource name from a nested Azure resource ID.')
@export()
func getParentResourceName(resourceId string) string => split(resourceId, '/')[length(split(resourceId, '/')) - 3]
