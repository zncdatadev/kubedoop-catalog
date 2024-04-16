

IMG ?= quay.io/zncdata/catalog:latest


.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: opm
OPM = ./bin/opm
opm: ## Download opm locally if necessary.
ifeq (,$(wildcard $(OPM)))
ifeq (,$(shell which opm 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(OPM)) ;\
	OS=$(shell go env GOOS) && ARCH=$(shell go env GOARCH) && \
	curl -sSLo $(OPM) https://github.com/operator-framework/operator-registry/releases/download/v1.29.0/$${OS}-$${ARCH}-opm ;\
	chmod +x $(OPM) ;\
	}
else
OPM = $(shell which opm)
endif
endif


# https://olm.operatorframework.io/docs/reference/file-based-catalogs/#building-a-composite-catalog
.PHONY: build
build: opm ## Build the project
	@{ \
		set -ex ;\
		NAME=$(shell yq eval '.name' catalog.yaml) ;\
		mkdir -p $$NAME ;\
		yq eval '.name + "/" + .references[].name' catalog.yaml | xargs mkdir -p ;\
		for ref in $(shell yq e '.name as $$catalog | .references[] | .image + "," + $$catalog + "/" + .name + "/index.yaml"' catalog.yaml); do \
			image=`echo $$ref | cut -d',' -f1` ;\
			file=`echo $$ref | cut -d',' -f2` ;\
			$(OPM) render -o yaml "$$image" > "$$file" ;\
		done ;\
	}

.PHONY: docker-build
docker-build: ## Build the docker image.
	docker build --tag ${IMG} .

.PHONY: docker-push
docker-push: ## Push the docker image.
	docker push ${IMG}

PLATFORMS ?= linux/arm64,linux/amd64
.PHONY: docker-buildx
docker-buildx: ## Build the docker image using buildx.
	- docker buildx create --name project-v3-builder
	docker buildx use project-v3-builder
	docker buildx build --platform $(PLATFORMS) --tag ${IMG} --push -f Dockerfile .
	- docker buildx rm project-v3-builder

