GITHUB_SERVER            := $(shell delivery/scripts/github.sh get_server)
GITHUB_USER              := $(shell delivery/scripts/github.sh get_user)
GITHUB_REPO              := $(shell delivery/scripts/github.sh get_repo)
GITHUB_API               := $(shell delivery/scripts/github.sh get_api)
GITHUB_TOKEN             ?= 06161df89a5435488d6ac4e7de1d5c492a014637

DOCKER_REGISTRY_AUTH     ?=
DOCKER_REGISTRY          ?= dockerhub.hi.inet
DOCKER_ORG               ?= $(shell echo "$(GITHUB_USER)" | tr '[:upper:]' '[:lower:]')
DOCKER_PROJECT           ?= $(shell echo "$(GITHUB_REPO)" | tr '[:upper:]' '[:lower:]')
DOCKER_API_VERSION       ?=
DOCKER_IMAGE             ?= $(if $(DOCKER_REGISTRY),$(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_PROJECT),$(DOCKER_ORG)/$(DOCKER_PROJECT))

DOCKER_COMPOSE_PROJECT   := $(shell echo "$(DOCKER_PROJECT)" | sed -e 's/[^a-z0-9]//g')
DOCKER_COMPOSE_SERVICE   := develenv
DOCKER_COMPOSE_FILE      := delivery/docker/dev/docker-compose.yml
DOCKER_COMPOSE_GOPATH    := /home/contint/go
DOCKER_COMPOSE_PORT      ?= 9000
DOCKER_COMPOSE_GOPROJECT := $(GITHUB_SERVER)/$(GITHUB_USER)/$(GITHUB_REPO)
DOCKER_COMPOSE_ENV       := GOPATH="$(DOCKER_COMPOSE_GOPATH)" GOPROJECT="$(DOCKER_COMPOSE_GOPROJECT)" PORT="$(DOCKER_COMPOSE_PORT)"
DOCKER_COMPOSE           := $(DOCKER_COMPOSE_ENV) docker-compose -p "$(DOCKER_COMPOSE_PROJECT)" -f "$(DOCKER_COMPOSE_FILE)"

PRODUCT_VERSION          ?= $(shell delivery/scripts/github.sh get_version)
PRODUCT_REVISION         ?= $(shell delivery/scripts/github.sh get_revision)
BUILD_VERSION            ?= $(PRODUCT_VERSION)-$(PRODUCT_REVISION)
LDFLAGS_OPTIMIZATION     ?= -w -s
LDFLAGS_VERSION          ?= -X main.Version=$(BUILD_VERSION)
LDFLAGS                  ?= $(LDFLAGS_OPTIMIZATION) $(LDFLAGS_VERSION)

# Get the environment and import the settings.
# If the make target is pipeline-xxx, the environment is obtained from the target.
ifeq ($(patsubst pipeline-%,%,$(MAKECMDGOALS)),$(MAKECMDGOALS))
	ENVIRONMENT ?= pull
else
	override ENVIRONMENT := $(patsubst pipeline-%,%,$(MAKECMDGOALS))
endif
include delivery/env/$(ENVIRONMENT)

define help
Usage: make <command>
Commands:
  help:            Show this help information
  clean-build:     Clean the project (remove build directory and clean golang packages)
  clean-vendor:    Remove vendor directory
  clean:           Clean the project (both clean-build and clean-vendor)
  build-deps:      Install the golang dependencies with deps
  build-config:    Copy the configuration into build/bin directory
  build-install:   Build the application into build/bin directory
  build-test:      Pass unit tests
  build-cover:     Create the coverage report (in build/cover)
  build:           Build the application. Launches: build-install, build-test and build-cover
  test-e2e-local:  Pass e2e tests locally (launching the service, passing e2e tests, and stopping the service)
  test-e2e:        Pass e2e tests
  package:         Create the docker image
  publish:         Publish the docker image
  deploy:          Deploy the service (see delivery/deploy/docker-compose.yml)
  undeploy:        Undeploy the service (see delivery/deploy/docker-compose.yml)
  promote:         Promote a docker image using the environment DOCKER_PROMOTION_TAG
  release:         Create a new release (tag and release notes)
  run:             Launch the service with docker-compose (for testing purposes)
  pipeline-pull:   Launch pipeline to handle a pull request
  pipeline-dev:    Launch pipeline to handle the merge of a pull request
  pipeline:        Launch the pipeline for the selected environment
  develenv-up:     Launch the development environment with a docker-compose of the service
  develenv-sh:     Access to a shell of a launched development environment
  develenv-down:   Stop the development environment
endef
export help

.PHONY: help clean-build clean-vendor clean build-deps build-config build \
		test-e2e-local test-e2e \
		package publish deploy undeploy promote release-deps release run \
		pipeline-pull pipeline-dev pipeline \
		develenv-up develenv-sh develenv-down

help:
	@echo "$$help"

clean-build:
	$(info) "Cleaning the project"
	go clean
	rm -rf build/

clean-vendor:
	$(info) "Cleaning the vendor directory"
	rm -rf vendor/

clean: clean-build clean-vendor

build-deps:
	$(info) "Installing golang dependencies"
	go get -v github.com/golang/lint/golint \
	          github.com/golang/dep/cmd/dep \
			  github.com/t-yuki/gocover-cobertura
	dep ensure -v

build-config:
	$(info) "Copying configuration and JSON schemas"
	rm -rf build/bin
	mkdir -p build/bin
	cp -r seed/cmd/seed/config.json \
	      seed/cmd/seed/schemas \
		  build/bin/

build-install: clean-build build-deps build-config
	$(info) "Building version: $(BUILD_VERSION)"
	GOBIN=$$PWD/build/bin/ go install -ldflags="$(LDFLAGS)" $(get_packages)
	golint -set_exit_status $(get_packages)
	go vet $(get_packages)

build-test:
	# Unit tests
	go test $(get_packages)
	# Data race detector (commented because it is not passing in dcip)
	# go test -race $(get_packages)

build-cover:
	mkdir -p build/cover
	echo "mode: count" > build/cover/cover.cov
	@for package in $(get_packages); do \
    	go test -v -covermode=count -coverprofile build/cover/cover_tmp.cov "$$package"; \
		[ -f build/cover/cover_tmp.cov ] && tail -n +2 build/cover/cover_tmp.cov >> build/cover/cover.cov \
			&& rm build/cover/cover_tmp.cov \
			|| echo "No unit test for package $$package"; \
	done
	go tool cover -func=build/cover/cover.cov
	go tool cover -html=build/cover/cover.cov -o build/cover/cover.html
	gocover-cobertura < build/cover/cover.cov > build/cover/cover.xml

build: build-install build-test build-cover

test-e2e-local:
	$(info) "Passing e2e tests locally"
	ENVIRONMENT=pull test/e2e/test-e2e.sh

test-e2e:
	$(info) "Passing e2e tests"
	# Need a method to get the public IP address for seed service after deploy
	#test/e2e/test-e2e.sh

package:
	$(info) "Creating the docker image $(DOCKER_IMAGE):$(BUILD_VERSION)"
	docker $(DOCKER_ARGS) build -f delivery/docker/release/Dockerfile -t $(DOCKER_IMAGE):$(BUILD_VERSION) .
	docker $(DOCKER_ARGS) tag $(DOCKER_IMAGE):$(BUILD_VERSION) $(DOCKER_IMAGE):$(PRODUCT_VERSION)

publish:
	$(info) "Publishing the docker image $(DOCKER_IMAGE):$(BUILD_VERSION)"
	docker $(DOCKER_ARGS) push $(DOCKER_IMAGE):$(BUILD_VERSION)
	docker $(DOCKER_ARGS) push $(DOCKER_IMAGE):$(PRODUCT_VERSION)

deploy:
	$(info) "Deploying the service $(DOCKER_IMAGE):$(BUILD_VERSION) in environment $(ENVIRONMENT)"
	docker-compose $(DOCKER_ARGS) -p "$(DOCKER_PROJECT)$(ENVIRONMENT)" -f delivery/deploy/docker-compose.yml up

undeploy:
	$(info) "Undeploying the service $(DOCKER_IMAGE):$(BUILD_VERSION) in environment $(ENVIRONMENT)"
	docker-compose $(DOCKER_ARGS) -p "$(DOCKER_PROJECT)$(ENVIRONMENT)" -f delivery/deploy/docker-compose.yml down

promote:
	$(info) "Promoting the docker image $(DOCKER_IMAGE):$(BUILD_VERSION) to $(DOCKER_IMAGE):$(DOCKER_PROMOTION_TAG)"
	docker $(DOCKER_ARGS) tag $(DOCKER_IMAGE):$(BUILD_VERSION) $(DOCKER_IMAGE):$(DOCKER_PROMOTION_TAG)
	docker $(DOCKER_ARGS) push $(DOCKER_IMAGE):$(DOCKER_PROMOTION_TAG)

release-deps:
	$(info) "Installing golang release dependencies"
	go get github.com/aktau/github-release

release: release-deps
ifeq ($(RELEASE),true)
	$(info) "Creating release: $(PRODUCT_VERSION)"
	GITHUB_API="$(GITHUB_API)" GITHUB_TOKEN="$(GITHUB_TOKEN)" github-release release \
		--user $(GITHUB_USER) \
		--repo $(GITHUB_REPO) \
		--tag $(PRODUCT_VERSION) \
		--name $(PRODUCT_VERSION) \
		--description "$(get_release_notes)"
endif

run: build
	$(info) "Launching the service"
	cd build/bin && ./seed 

pipeline-pull: build test-e2e-local
	$(info) "Completed successfully pipeline-pull"

pipeline-dev:  build test-e2e-local package publish deploy test-e2e undeploy promote release
	$(info) "Completed successfully pipeline-dev"

pipeline:      pipeline-$(ENVIRONMENT)

develenv-up:
	$(info) "Launching the development environment"
	$(DOCKER_COMPOSE) build
	$(DOCKER_COMPOSE) up -d

develenv-sh:
	docker exec -it "$(DOCKER_COMPOSE_PROJECT)_$(DOCKER_COMPOSE_SERVICE)_1" bash

develenv-down:
	$(info) "Shutting down the development environment"
	$(DOCKER_COMPOSE) down

# Functions
info := @printf "\033[32;01m%s\033[0m\n"
get_packages := $$(go list ./... | grep -v /vendor/)
get_release_notes := $$(delivery/scripts/github.sh get_release_notes)
