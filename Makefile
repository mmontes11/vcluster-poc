# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

.PHONY: all
all: help

##@ General

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

TRAEFIK_IP ?= 172.18.0.200
.PHONY: network
network: ## Configure network.
	@./hack/add_host.sh $(TRAEFIK_IP) traefik.local
	@./hack/add_host.sh $(TRAEFIK_IP) tenant-a.traefik.local
	@./hack/add_host.sh $(TRAEFIK_IP) tenant-b.traefik.local

GITHUB_USER ?= mmontes11
GITHUB_REPO ?= vcluster-poc
.PHONY: deploy
deploy: flux cluster-ctx ## Deploy PoC.
	$(FLUX) bootstrap github \
		--owner=$(GITHUB_USER) \
		--repository=$(GITHUB_REPO) \
		--private=false \
		--personal=true \
		--path=clusters/host-cluster

VCLUSTER_A ?= vcluster-a
VCLUSTER_B ?= vcluster-b

.PHONY: vctx
vctx: vcluster cluster-ctx ## Configure vcluster contexts.
	$(VCLUSTER) connect $(VCLUSTER_A) -n $(VCLUSTER_A)
	$(VCLUSTER) connect $(VCLUSTER_B) -n $(VCLUSTER_B)

# TODO:
# vcluster disconnect does not delete the vcluster current context, you have to vcluster delete if you want to do so.
# Support vcluster disconnect --delete-current upstream to have a simetric behaviour between subcommands. 
.PHONY: vcluster-delete
vcluster-delete: vcluster cluster-ctx ## Delete vclusters.
	$(VCLUSTER) delete $(VCLUSTER_A) -n $(VCLUSTER_A)
	$(VCLUSTER) delete $(VCLUSTER_B) -n $(VCLUSTER_B)

.PHONY: install
install: network cluster deploy ## Install cluster and PoC.

.PHONY: uninstall
uninstall: vcluster-delete cluster-delete ## Tear down vcluster and cluster.

##@ Cluster

CLUSTER ?= host-cluster
KIND_CONFIG ?= hack/config/kind.yaml

.PHONY: cluster
cluster: kind ## Provision kind cluster.
	$(KIND) create cluster --name $(CLUSTER) --config $(KIND_CONFIG)

.PHONY: cluster-delete
cluster-delete: kind ## Delete kind cluster.
	$(KIND) delete cluster --name $(CLUSTER)

.PHONY: cluster-ctx
cluster-ctx: ## Set cluster context.
	@kubectl config use-context kind-$(CLUSTER)

##@ Tooling

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool Binaries
KIND ?= $(LOCALBIN)/kind
FLUX ?= $(LOCALBIN)/flux
VCLUSTER ?= $(LOCALBIN)/vcluster

## Tool Versions
KIND_VERSION ?= v0.20.0
FLUX_VERSION ?= 2.0.1
VCLUSTER_VERSION ?= v0.15.2

.PHONY: kind
kind: $(KIND) ## Download kind locally if necessary.
$(KIND): $(LOCALBIN)
	GOBIN=$(LOCALBIN) go install sigs.k8s.io/kind@$(KIND_VERSION)

.PHONY: flux
flux: ## Download flux locally if necessary.
ifeq (,$(wildcard $(FLUX)))
ifeq (,$(shell which flux 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(FLUX)) ;\
	curl -sSLo - https://github.com/fluxcd/flux2/releases/download/v$(FLUX_VERSION)/flux_$(FLUX_VERSION)_linux_amd64.tar.gz| \
	tar xzf - -C bin/ ;\
	}
else
FLUX = $(shell which flux)
endif
endif

.PHONY: vcluster
vcluster: ## Download vcluster locally if necessary.
ifeq (,$(wildcard $(VCLUSTER)))
ifeq (,$(shell which vcluster 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(VCLUSTER)) ;\
	curl -sSLo $(VCLUSTER) https://github.com/loft-sh/vcluster/releases/download/$(VCLUSTER_VERSION)/vcluster-linux-amd64 ;\
	chmod +x $(VCLUSTER) ;\
	}
else
VCLUSTER = $(shell which vcluster)
endif
endif