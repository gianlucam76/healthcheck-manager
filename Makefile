
# Image URL to use all building/pushing image targets
IMG ?= controller:latest
# KUBEBUILDER_ENVTEST_KUBERNETES_VERSION refers to the version of kubebuilder assets to be downloaded by envtest binary.
KUBEBUILDER_ENVTEST_KUBERNETES_VERSION = 1.30.0

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif
GO_INSTALL := ./scripts/go_install.sh

# Setting SHELL to bash allows bash commands to be executed by recipes.
# This is a requirement for 'setup-envtest.sh' in the test target.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

# Define Docker related variables.
REGISTRY ?= projectsveltos
IMAGE_NAME ?= healthcheck-manager
ARCH ?= amd64
OS ?= $(shell uname -s | tr A-Z a-z)
K8S_LATEST_VER ?= $(shell curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
export CONTROLLER_IMG ?= $(REGISTRY)/$(IMAGE_NAME)
TAG ?= main

.PHONY: all
all: build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# Directories.
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
TOOLS_DIR := hack/tools
BIN_DIR := bin
TOOLS_BIN_DIR := $(abspath $(TOOLS_DIR)/$(BIN_DIR))
GOBUILD=go build

GENERATED_FILES:=./manifest/manifest.yaml

## Tool Binaries
CONTROLLER_GEN := $(TOOLS_BIN_DIR)/controller-gen
ENVSUBST := $(TOOLS_BIN_DIR)/envsubst
GOIMPORTS := $(TOOLS_BIN_DIR)/goimports
GOLANGCI_LINT := $(TOOLS_BIN_DIR)/golangci-lint
GINKGO := $(TOOLS_BIN_DIR)/ginkgo
SETUP_ENVTEST := $(TOOLS_BIN_DIR)/setup_envs
CLUSTERCTL := $(TOOLS_BIN_DIR)/clusterctl
KIND := $(TOOLS_BIN_DIR)/kind
KUBECTL := $(TOOLS_BIN_DIR)/kubectl

GOLANGCI_LINT_VERSION := "v1.57.2"
CLUSTERCTL_VERSION := "v1.7.2"


KUSTOMIZE_VER := v5.3.0
KUSTOMIZE_BIN := kustomize
KUSTOMIZE := $(abspath $(TOOLS_BIN_DIR)/$(KUSTOMIZE_BIN)-$(KUSTOMIZE_VER))
KUSTOMIZE_PKG := sigs.k8s.io/kustomize/kustomize/v5
$(KUSTOMIZE): # Build kustomize from tools folder.
	CGO_ENABLED=0 GOBIN=$(TOOLS_BIN_DIR) $(GO_INSTALL) $(KUSTOMIZE_PKG) $(KUSTOMIZE_BIN) $(KUSTOMIZE_VER)

SETUP_ENVTEST_VER := v0.0.0-20240522175850-2e9781e9fc60
SETUP_ENVTEST_BIN := setup-envtest
SETUP_ENVTEST := $(abspath $(TOOLS_BIN_DIR)/$(SETUP_ENVTEST_BIN)-$(SETUP_ENVTEST_VER))
SETUP_ENVTEST_PKG := sigs.k8s.io/controller-runtime/tools/setup-envtest
setup-envtest: $(SETUP_ENVTEST) ## Set up envtest (download kubebuilder assets)
	@echo KUBEBUILDER_ASSETS=$(KUBEBUILDER_ASSETS)

$(SETUP_ENVTEST_BIN): $(SETUP_ENVTEST) ## Build a local copy of setup-envtest.

$(SETUP_ENVTEST): # Build setup-envtest from tools folder.
	GOBIN=$(TOOLS_BIN_DIR) $(GO_INSTALL) $(SETUP_ENVTEST_PKG) $(SETUP_ENVTEST_BIN) $(SETUP_ENVTEST_VER)

$(CONTROLLER_GEN): $(TOOLS_DIR)/go.mod # Build controller-gen from tools folder.
	cd $(TOOLS_DIR); $(GOBUILD) -tags=tools -o $(subst $(TOOLS_DIR)/hack/tools/,,$@) sigs.k8s.io/controller-tools/cmd/controller-gen

$(ENVSUBST): $(TOOLS_DIR)/go.mod # Build envsubst from tools folder.
	cd $(TOOLS_DIR); $(GOBUILD) -tags=tools -o $(subst $(TOOLS_DIR)/hack/tools/,,$@) github.com/a8m/envsubst/cmd/envsubst

$(GOLANGCI_LINT): # Build golangci-lint from tools folder.
	cd $(TOOLS_DIR); ./get-golangci-lint.sh $(GOLANGCI_LINT_VERSION)

$(GOIMPORTS):
	cd $(TOOLS_DIR); $(GOBUILD) -tags=tools -o $(subst $(TOOLS_DIR)/hack/tools/,,$@) golang.org/x/tools/cmd/goimports

$(GINKGO): $(TOOLS_DIR)/go.mod
	cd $(TOOLS_DIR) && $(GOBUILD) -tags tools -o $(subst $(TOOLS_DIR)/hack/tools/,,$@) github.com/onsi/ginkgo/v2/ginkgo

$(KIND): $(TOOLS_DIR)/go.mod
	cd $(TOOLS_DIR) && $(GOBUILD) -tags tools -o $(subst $(TOOLS_DIR)/hack/tools/,,$@) sigs.k8s.io/kind

$(CLUSTERCTL): $(TOOLS_DIR)/go.mod ## Build clusterctl binary
	curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/$(CLUSTERCTL_VERSION)/clusterctl-$(OS)-$(ARCH) -o $@
	chmod +x $@
	mkdir -p $(HOME)/.cluster-api # create cluster api init directory, if not present	

$(KUBECTL):
	curl -L https://storage.googleapis.com/kubernetes-release/release/$(K8S_LATEST_VER)/bin/$(OS)/$(ARCH)/kubectl -o $@
	chmod +x $@

.PHONY: tools
tools: $(CONTROLLER_GEN) $(ENVSUBST) $(KUSTOMIZE) $(GOLANGCI_LINT) $(SETUP_ENVTEST) $(GOIMPORTS) $(GINKGO) $(CLUSTERCTL) $(KIND) $(KUBECTL) ## build all tools

.PHONY: clean
clean: ## Remove all built tools
	rm -rf $(TOOLS_BIN_DIR)/*
	rm -rf $(GENERATED_FILES)
	rm -rf version.txt

##@ Development

.PHONY: manifests
manifests: $(CONTROLLER_GEN) $(KUSTOMIZE) $(ENVSUBST) fmt generate ## Generate WebhookConfiguration, ClusterRole and CustomResourceDefinition objects.
	$(CONTROLLER_GEN) rbac:roleName=manager-role crd webhook paths="./..." output:crd:artifacts:config=config/crd/bases
	MANIFEST_IMG=$(CONTROLLER_IMG) MANIFEST_TAG=$(TAG) $(MAKE) set-manifest-image
	$(KUSTOMIZE) build config/default | $(ENVSUBST) > manifest/manifest.yaml
	./scripts/extract_deployment.sh manifest/manifest.yaml manifest/deployment-shard.yaml

.PHONY: generate
generate: $(CONTROLLER_GEN) ## Generate code containing DeepCopy, DeepCopyInto, and DeepCopyObject method implementations.
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

.PHONY: fmt
fmt: $(GOIMPORTS) ## Run go fmt against code.
	$(GOIMPORTS) -local github.com/projectsveltos -w .
	go fmt ./...

.PHONY: vet
vet: ## Run go vet against code.
	go vet ./...

.PHONY: lint
lint: $(GOLANGCI_LINT) generate ## Lint codebase
	$(GOLANGCI_LINT) run -v --fast=false --max-issues-per-linter 0 --max-same-issues 0 --timeout 5m	

.PHONY: check-manifests
check-manifests: manifests ## Verify manifests file is up to date
	test `git status --porcelain $(GENERATED_FILES) | grep -cE '(^\?)|(^ M)'` -eq 0 || (echo "The manifest file changed, please 'make manifests' and commit the results"; exit 1)

ifeq ($(shell go env GOOS),darwin) # Use the darwin/amd64 binary until an arm64 version is available
KUBEBUILDER_ASSETS ?= $(shell $(SETUP_ENVTEST) use --use-env -p path --arch amd64 $(KUBEBUILDER_ENVTEST_KUBERNETES_VERSION))
else
KUBEBUILDER_ASSETS ?= $(shell $(SETUP_ENVTEST) use --use-env -p path $(KUBEBUILDER_ENVTEST_KUBERNETES_VERSION))
endif

##@ TESTING

# K8S_VERSION for the Kind cluster can be set as environment variable. If not defined,
# this default value is used
ifndef K8S_VERSION
K8S_VERSION := v1.30.0
endif

KIND_CONFIG ?= kind-cluster.yaml
CONTROL_CLUSTER_NAME ?= sveltos-management
WORKLOAD_CLUSTER_NAME ?= clusterapi-workload
TIMEOUT ?= 10m
KIND_CLUSTER_YAML ?= test/$(WORKLOAD_CLUSTER_NAME).yaml
NUM_NODES ?= 5

.PHONY: test
test: | check-manifests generate fmt vet $(SETUP_ENVTEST) ## Run uts.
	KUBEBUILDER_ASSETS="$(KUBEBUILDER_ASSETS)" go test $(shell go list ./... |grep -v test/fv |grep -v test/helpers) $(TEST_ARGS) -coverprofile cover.out 

.PHONY: kind-test
kind-test: test create-cluster fv ## Build docker image; start kind cluster; load docker image; install all cluster api components and run fv

.PHONY: fv
fv: $(GINKGO) ## Run Sveltos Controller tests using existing cluster
	cd test/fv; $(GINKGO) -nodes $(NUM_NODES) --label-filter='FV' --v --trace --randomize-all

.PHONY: fv-sharding
fv-sharding: $(KUBECTL) $(GINKGO) ## Run Sveltos Controller tests using existing cluster
	$(KUBECTL) patch cluster clusterapi-workload  -n default --type json -p '[{ "op": "add", "path": "/metadata/annotations/sharding.projectsveltos.io~1key", "value": "shard1" }]'
	sed -e "s/{{.SHARD}}/shard1/g"  manifest/deployment-shard.yaml > test/hc-deployment-shard.yaml
	$(KUBECTL) apply -f test/hc-deployment-shard.yaml
	rm -f test/hc-deployment-shard.yaml
	cd test/fv; $(GINKGO) -nodes $(NUM_NODES) --label-filter='FV' --v --trace --randomize-all

.PHONY: create-cluster
create-cluster: $(KIND) $(CLUSTERCTL) $(KUBECTL) $(ENVSUBST) ## Create a new kind cluster designed for development
	$(MAKE) create-control-cluster

	@echo wait for capd-system pod
	$(KUBECTL) wait --for=condition=Available deployment/capd-controller-manager -n capd-system --timeout=$(TIMEOUT)

	@echo wait for capi-kubeadm-bootstrap-system pod
	$(KUBECTL) wait --for=condition=Available deployment/capi-kubeadm-bootstrap-controller-manager -n capi-kubeadm-bootstrap-system --timeout=$(TIMEOUT)

	@echo wait for capi-kubeadm-control-plane-system pod
	$(KUBECTL) wait --for=condition=Available deployment/capi-kubeadm-control-plane-controller-manager -n capi-kubeadm-control-plane-system --timeout=$(TIMEOUT)

	@echo "sleep allowing webhook to be ready"
	sleep 10

	@echo "Create a workload cluster"
	$(KUBECTL) apply -f $(KIND_CLUSTER_YAML)

	@echo "Start projectsveltos"
	$(MAKE) deploy-projectsveltos

	@echo "wait for cluster to be provisioned"
	$(KUBECTL) wait cluster $(WORKLOAD_CLUSTER_NAME) -n default --for=jsonpath='{.status.phase}'=Provisioned --timeout=$(TIMEOUT)

	@echo "sleep allowing control plane to be ready"
	sleep 60

	@echo "get kubeconfig to access workload cluster"
	$(KIND) get kubeconfig --name $(WORKLOAD_CLUSTER_NAME) > test/fv/workload_kubeconfig

	@echo "install calico on workload cluster"
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml

	@echo "wait for calico pod"
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig wait --for=condition=Available deployment/calico-kube-controllers -n kube-system --timeout=$(TIMEOUT)

	@echo "install sveltos-agent"
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_debuggingconfigurations.yaml
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_classifiers.yaml
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_healthchecks.yaml
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_healthcheckreports.yaml
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_reloaderreports.yaml
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_reloaders.yaml
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_eventsources.yaml
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_eventreports.yaml
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig apply -f https://raw.githubusercontent.com/projectsveltos/sveltos-agent/$(TAG)/manifest/manifest.yaml

	@echo "wait for sveltos-agent"
	$(KUBECTL) --kubeconfig=./test/fv/workload_kubeconfig wait --for=condition=Available deployment/sveltos-agent-manager  -n projectsveltos --timeout=$(TIMEOUT)


.PHONY: delete-cluster
delete-cluster: $(KIND) ## Deletes the kind cluster $(CONTROL_CLUSTER_NAME)
	$(KIND) delete cluster --name $(CONTROL_CLUSTER_NAME)
	$(KIND) delete cluster --name $(WORKLOAD_CLUSTER_NAME)

### fv helpers

# In order to avoid this error
# Error: failed to read "cluster-template-development.yaml" from provider's repository "infrastructure-docker": failed to get GitHub release v1.2.0: rate limit for github api has been reached. 
# Please wait one hour or get a personal API token and assign it to the GITHUB_TOKEN environment variable
#
# add this target. It needs to be run only when changing cluster-api version. create-cluster target uses the output of this command which is stored within repo
# It requires control cluster to exist. So first "make create-control-cluster" then run this target before any workload cluster is created.
# Once generated, remove
#      enforce: "{{ .podSecurityStandard.enforce }}"
#      enforce-version: "latest"
create-clusterapi-kind-cluster-yaml: $(CLUSTERCTL) 
	ENABLE_POD_SECURITY_STANDARD="true" KUBERNETES_VERSION=$(K8S_VERSION) SERVICE_CIDR=["10.225.0.0/16"] POD_CIDR=["10.220.0.0/16"] $(CLUSTERCTL) generate cluster $(WORKLOAD_CLUSTER_NAME) --flavor development \
		--control-plane-machine-count=1 \
		--worker-machine-count=2 > $(KIND_CLUSTER_YAML)

create-control-cluster: $(KIND) $(CLUSTERCTL)
	sed -e "s/K8S_VERSION/$(K8S_VERSION)/g"  test/$(KIND_CONFIG) > test/$(KIND_CONFIG).tmp
	$(KIND) create cluster --name=$(CONTROL_CLUSTER_NAME) --config test/$(KIND_CONFIG).tmp
	@echo "Create control cluster with docker as infrastructure provider"
	CLUSTER_TOPOLOGY=true $(CLUSTERCTL) init --infrastructure docker

deploy-projectsveltos: $(KUSTOMIZE) $(KUBECTL) 
	# Load projectsveltos image into cluster
	@echo 'Load projectsveltos image into cluster'
	$(MAKE) load-image

	@echo 'Install libsveltos CRDs'
	$(KUBECTL) apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_debuggingconfigurations.yaml
	$(KUBECTL) apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_sveltosclusters.yaml
	$(KUBECTL) apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_clusterhealthchecks.yaml
	$(KUBECTL) apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_healthchecks.yaml
	$(KUBECTL) apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_healthcheckreports.yaml
	$(KUBECTL) apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_reloaderreports.yaml
	$(KUBECTL) apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_clustersets.yaml
	$(KUBECTL) apply -f https://raw.githubusercontent.com/projectsveltos/libsveltos/$(TAG)/config/crd/bases/lib.projectsveltos.io_sets.yaml	
	
	# Install projectsveltos addon-controller
	$(KUBECTL) apply -f https://raw.githubusercontent.com/projectsveltos/addon-controller/$(TAG)/manifest/manifest.yaml
	curl https://raw.githubusercontent.com/projectsveltos/addon-controller/$(TAG)/manifest/deployment-shard.yaml -o ac-deployment-shard.yaml
	sed -e "s/{{.SHARD}}/shard1/g"  ac-deployment-shard.yaml > tmp-ac-deployment-shard.yaml
	$(KUBECTL) apply -f tmp-ac-deployment-shard.yaml
	rm ac-deployment-shard.yaml
	rm tmp-ac-deployment-shard.yaml

	@echo "Waiting for projectsveltos addon-controller to be available..."
	$(KUBECTL) wait --for=condition=Available deployment/addon-controller -n projectsveltos --timeout=$(TIMEOUT)

	# Install projectsveltos healthcheck-manager components
	@echo 'Install projectsveltos controller-manager components'
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default | $(ENVSUBST) | $(KUBECTL) apply -f-

	@echo "Waiting for projectsveltos controller-manager to be available..."
	$(KUBECTL) wait --for=condition=Available deployment/addon-controller -n projectsveltos --timeout=$(TIMEOUT)

	@echo "Waiting for projectsveltos hc-manager to be available..."
	$(KUBECTL) wait --for=condition=Available deployment/hc-manager -n projectsveltos --timeout=$(TIMEOUT)

set-manifest-image:
	$(info Updating kustomize image patch file for manager resource)
	sed -i'' -e 's@image: .*@image: '"${MANIFEST_IMG}:$(MANIFEST_TAG)"'@' ./config/default/manager_image_patch.yaml

set-manifest-pull-policy:
	$(info Updating kustomize pull policy file for manager resource)
	sed -i'' -e 's@imagePullPolicy: .*@imagePullPolicy: '"$(PULL_POLICY)"'@' ./config/default/manager_pull_policy.yaml

##@ Build

.PHONY: build
build: generate fmt vet ## Build manager binary.
	go build -o bin/manager cmd/main.go

.PHONY: run
run: manifests generate fmt vet ## Run a controller from your host.
	go run ./main.go

.PHONY: docker-build
docker-build: ## Build docker image with the manager.
	docker build --load --build-arg BUILDOS=linux --build-arg TARGETARCH=amd64 -t $(CONTROLLER_IMG):$(TAG) .
	MANIFEST_IMG=$(CONTROLLER_IMG) MANIFEST_TAG=$(TAG) $(MAKE) set-manifest-image
	$(MAKE) set-manifest-pull-policy

.PHONY: docker-push
docker-push: ## Push docker image with the manager.
	docker push $(CONTROLLER_IMG):$(TAG)

.PHONY: docker-buildx
docker-buildx: ## docker build for multiple arch and push to docker hub
	docker buildx build --push --platform linux/amd64,linux/arm64 -t $(CONTROLLER_IMG):$(TAG) .

.PHONY: load-image
load-image: docker-build $(KIND)
	$(KIND) load docker-image $(CONTROLLER_IMG):$(TAG) --name $(CONTROL_CLUSTER_NAME)

##@ Deployment

ifndef ignore-not-found
  ignore-not-found = false
endif

.PHONY: install
install: manifests $(KUSTOMIZE) ## Install CRDs into the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/crd | kubectl apply -f -

.PHONY: uninstall
uninstall: manifests $(KUSTOMIZE) ## Uninstall CRDs from the K8s cluster specified in ~/.kube/config. Call with ignore-not-found=true to ignore resource not found errors during deletion.
	$(KUSTOMIZE) build config/crd | kubectl delete --ignore-not-found=$(ignore-not-found) -f -

.PHONY: deploy
deploy: manifests $(KUSTOMIZE) $(KUBECTL) ## Deploy controller to the K8s cluster specified in ~/.kube/config.
	cd config/manager && ../../$(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default | $(ENVSUBST) | $(KUBECTL)  apply -f -

.PHONY: undeploy
undeploy: s $(KUSTOMIZE) $(KUBECTL) ## Undeploy controller from the K8s cluster specified in ~/.kube/config. Call with ignore-not-found=true to ignore resource not found errors during deletion.
	$(KUSTOMIZE) build config/default | kubectl delete --ignore-not-found=$(ignore-not-found) -f -
