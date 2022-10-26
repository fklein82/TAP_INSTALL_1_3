python3 -m pip install --upgrade lastversion
PIVNET_CLI_URL=$(lastversion pivotal-cf/pivnet-cli --assets --filter ^pivnet-linux-amd64)
echo "Pivnet CLI latest release URL: $PIVNET_CLI_URL"
sudo wget -O /usr/local/bin/pivnet "$PIVNET_CLI_URL"
sudo chmod +x /usr/local/bin/pivnet
pivnet version

## pivnet Login 
pivnet login --api-token='TYPE_YOUR_TANZUNET_TOKEN_HERE'

## Download tanzu-cli-tap-1.3.0

# Create a temporary directory
TANZU_TMP_DIR=/tmp/tanzu
mkdir -p "$TANZU_TMP_DIR"

# Define variables
TAP_VERSION='1.3.1-build.4'
PRODUCT_FILE_ID=1310085

# Download bundle
pivnet download-product-files \
--product-slug="tanzu-application-platform" \
--release-version="$TAP_VERSION" \
--product-file-id="$PRODUCT_FILE_ID" \
--download-dir="$TANZU_TMP_DIR"

## Extract and install Tanzu CLI
tar -xvf "$TANZU_TMP_DIR/tanzu-framework-linux-amd64.tar" -C "$TANZU_TMP_DIR"
export TANZU_CLI_NO_INIT=true
TANZU_FRAMEWORK_VERSION=v0.25.0
sudo install "$TANZU_TMP_DIR/cli/core/$TANZU_FRAMEWORK_VERSION/tanzu-core-linux_amd64" /usr/local/bin/tanzu
tanzu plugin install --local "$TANZU_TMP_DIR/cli" all
tanzu version
tanzu plugin list

## Carvel tools
curl -L https://carvel.dev/install.sh | sudo bash

# Define credentials
TANZU_REGISTRY_USERNAME='TYPE_YOUR_VMWARE_LOGIN_HERE'
TANZU_REGISTRY_PASSWORD='TYPE_YOUR_VMWARE_PASSWORD_HERE'

# Login
sudo docker login registry.tanzu.vmware.com \
-u "$TANZU_REGISTRY_USERNAME" \
-p "$TANZU_REGISTRY_PASSWORD"

# Define variables

export IMGPKG_ENABLE_IAAS_AUTH=false
export IMGPKG_REGISTRY_HOSTNAME='TYPE_YOUR_PERSONAL_REGISTRY_URL_HERE'
export IMGPKG_REGISTRY_USERNAME='TYPE_YOUR_LOGIN_USERNAME_PERSONAL_REGISTRY_HERE'
export IMGPKG_REGISTRY_PASSWORD='TYPE_YOUR_PASSWORD_PERSONAL_REGISTRY_HERE'
export TAP_VERSION='1.3.1-build.4'
export TAP_REPO='tap'


## Login to private registry
docker login "$IMGPKG_REGISTRY_HOSTNAME" \
-u "$IMGPKG_REGISTRY_USERNAME" \
-p "$IMGPKG_REGISTRY_PASSWORD"


# Create project
curl -k -H "Content-Type: application/json" \
-u "$IMGPKG_REGISTRY_USERNAME:$IMGPKG_REGISTRY_PASSWORD" \
-X POST "https://$IMGPKG_REGISTRY_HOSTNAME/api/v2.0/projects" \
-d '{"project_name": '\"${TAP_REPO}\"', "public": false}'


## Relocate image
imgpkg copy --registry-verify-certs=false --registry-username='TYPE_YOUR_VMWARE_LOGIN_HERE' --registry-password='TYPE_YOUR_VMWARE_PASSWORD_HERE' \
-b "registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION" \
--to-repo "$IMGPKG_REGISTRY_HOSTNAME/$TAP_REPO/tap-packages"


## Prepare AKS Cluster

# Azure login
az login --use-device-code

# Set your default subscription
az account list --output table
az account set --subscription 'TYPE_YOUR_AZURE_SUBSCRIPTION'
az account show --output table

# Preprare
# Add pod security policies support preview (required for learningcenter)
az extension add --name aks-preview
az feature register --name PodSecurityPolicyPreview --namespace Microsoft.ContainerService

# Wait until the status is "Registered"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/PodSecurityPolicyPreview')].{Name:name,State:properties.state}"
az provider register --namespace Microsoft.ContainerService

# Deploy Cluster AKS
az group create --location northeurope --name 'tap-demo1-3'
### Next step will deploy the Cluster - Take 30 min to complete
az aks create --resource-group 'tap-demo1-3' --name 'tap-demo1-3' --node-count 3 --node-vm-size Standard_DS3_v2 --node-osdisk-size 500 --enable-pod-security-policy --generate-ssh-keys
az aks get-credentials --resource-group 'tap-demo1-3' --name 'tap-demo1-3'

# RBAC
kubectl create clusterrolebinding tap-psp-rolebinding --group=system:authenticated --clusterrole=psp:privileged

## Install TAP 1.3b4

# Create Namespace
kubectl create ns tap-install
kubectl create ns dev


# Install cluster Essential
pivnet download-product-files --product-slug='tanzu-cluster-essentials' --release-version='1.3.0' --product-file-id=1330470


mkdir $HOME/tanzu-cluster-essentials
tar -xvf tanzu-cluster-essentials-linux-amd64-1.3.0.tgz -C $HOME/tanzu-cluster-essentials

export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:54bf611711923dccd7c7f10603c846782b90644d48f1cb570b43a082d18e23b9
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME='TYPE_YOUR_LOGIN_USERNAME_PERSONAL_REGISTRY_HERE'
export INSTALL_REGISTRY_PASSWORD='TYPE_YOUR_PASSWORD_PERSONAL_REGISTRY_HERE'
cd $HOME/tanzu-cluster-essentials
./install.sh --yes


# Create TAP Registry
tanzu secret registry add tap-registry \
--server "$IMGPKG_REGISTRY_HOSTNAME" \
--username "$IMGPKG_REGISTRY_USERNAME" \
--password "$IMGPKG_REGISTRY_PASSWORD" \
--export-to-all-namespaces --yes --namespace tap-install

# Create TAP package repository
tanzu package repository add tanzu-tap-repository \
--url "$IMGPKG_REGISTRY_HOSTNAME/$TAP_REPO/tap-packages:$TAP_VERSION" \
--namespace tap-install

# Create TAP GUI Catalog Git Repository
TANZU_TMP_DIR=/tmp/tanzu
mkdir -p "$TANZU_TMP_DIR"

# Define variables
TAP_VERSION='1.3.1-build.4'
PRODUCT_FILE_ID=1099786

# Download bundle
pivnet download-product-files \
--product-slug="tanzu-application-platform" \
--release-version="$TAP_VERSION" \
--product-file-id="$PRODUCT_FILE_ID" \
--download-dir="$TANZU_TMP_DIR"


# Check
tanzu package repository get tanzu-tap-repository --namespace tap-install
tanzu package available list --namespace tap-install

## INSTALL TAP

tanzu package install tap -p tap.tanzu.vmware.com -v '1.3.1-build.4' --values-file /home/azureuser/vmware-tap/linuxbox/tap-values-OK.yaml -n tap-install

# Check
tanzu package installed get tap -n tap-install
tanzu package installed list -A
kubectl describe PackageInstall <package-name> -n tap-install

# Check the NETWORK endpoint
kubectl get service envoy -n tanzu-system-ingress

# ADD the wildcard to your DNS and check it.
dig @8.8.8.8 tap-gui.tanzu.fklein.me

# publish API Portal and Accelerator (for vsCode)
k apply -f /home/azureuser/vmware-tap/linuxbox/api-portal.yaml
k apply -f /home/azureuser/vmware-tap/linuxbox/accelerator-vscode.yaml

# Check the ep
k get httpproxy -A

## Set up developer Namespaces 

tanzu secret registry add registry-credentials --server 'TYPE_YOUR_PERSONAL_REGISTRY_URL_HERE' --username 'TYPE_YOUR_LOGIN_USERNAME_PERSONAL_REGISTRY_HERE' --password 'TYPE_YOUR_PASSWORD_PERSONAL_REGISTRY_HERE' --namespace dev

# Secret & SA to execute Supplychain

cat <<EOF | kubectl -n dev apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-deliverable
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deliverable
subjects:
  - kind: ServiceAccount
    name: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-workload
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workload
subjects:
  - kind: ServiceAccount
    name: default
EOF

# INSTALL ootb-testing-supply-chain

tanzu package install tap -p tap.tanzu.vmware.com -v '1.3.1-build.4' --values-file /home/azureuser/vmware-tap/linuxbox/tap-values-testing.yaml -n tap-install
k apply -f tekton-pipeline.yaml -n dev