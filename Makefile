ORG = projectcontour
PROJECT = ir2proxy
MODULE = github.com/$(ORG)/$(PROJECT)
REGISTRY ?= projectcontour
IMAGE := $(REGISTRY)/$(PROJECT)
SRCDIRS := ./cmd

TAG_LATEST ?= false

GIT_REF := $(shell git rev-parse --short=8 --verify HEAD)

export GO111MODULE=on

Check_Targets := \
	check-test \
	check-test-race \
	check-vet \
	check-gofmt \
	check-staticcheck \
	check-misspell \
	check-unconvert \
	check-ineffassign \
	check-unparam \
	check-yamllint \

.PHONY: check
check: install $(Check_Targets) ## Run tests and CI checks

.PHONY: pedantic
pedantic: check check-errcheck ## Run pedantic CI checks

install: ## Build and install the contour binary
	go install -mod=readonly -v -ldflags="-X main.build=$(GIT_REF)" $(MODULE)/cmd/$(PROJECT)

race:
	go install -mod=readonly -ldflags="-X main.build=$(GIT_REF)" g-v $(MODULE)/cmd/$(PROJECT)

download: ## Download Go modules
	go mod download

.PHONY: check-test test
test: check-test
check-test:
	go test -cover -mod=readonly $(MODULE)/...

.PHONY: check-test-race
check-test-race: | check-test
	go test -race -mod=readonly $(MODULE)/...

.PHONY: check-staticcheck
check-staticcheck:
	go install honnef.co/go/tools/cmd/staticcheck
	staticcheck \
		-checks all,-ST1003 \
		$(MODULE)/{cmd,internal}/...

.PHONY: check-misspell
check-misspell:
	go install github.com/client9/misspell/cmd/misspell
	misspell \
		-i clas \
		-locale US \
		-error \
		cmd/* internal/* docs/* design/* site/*.md site/_{guides,posts,resources} *.md

.PHONY: check-unconvert
check-unconvert:
	go install github.com/mdempsky/unconvert
	unconvert -v $(MODULE)/{cmd,internal}/...

.PHONY: check-ineffassign
check-ineffassign:
	go install github.com/gordonklaus/ineffassign
	find $(SRCDIRS) -name '*.go' | xargs ineffassign

.PHONY: check-unparam
check-unparam:
	go install mvdan.cc/unparam
	unparam -exported $(MODULE)/{cmd,internal}/...

.PHONY: check-errcheck
check-errcheck:
	go install github.com/kisielk/errcheck
	errcheck $(MODULE)/...

.PHONY: check-gofmt
check-gofmt:
	@echo Checking code is gofmted
	@test -z "$(shell gofmt -s -l -d -e $(SRCDIRS) | tee /dev/stderr)"

.PHONY: check-vet
check-vet: | check-test
	go vet $(MODULE)/...

.PHONY: check-yamllint
check-yamllint:
	docker run --rm -ti -v $(CURDIR):/workdir giantswarm/yamllint -c /workdir/yamllintcfg.yaml internal/translator/testdata

help: ## Display this help
	@echo Contour high performance Ingress controller for Kubernetes
	@echo
	@echo Targets:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9._-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort
