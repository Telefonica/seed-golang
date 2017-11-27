[![Build Status](https://dcip.hi.inet/buildStatus/icon?job=jorgelg/seed-golang/pipeline-02-dev)](https://dcip.hi.inet/job/jorgelg/job/seed-golang/job/pipeline-02-dev/)
[![DockerHub](https://img.shields.io/docker/automated/jrottenberg/ffmpeg.svg)](http://artifactory.hi.inet/artifactory/webapp/#/artifacts/browse/tree/General/docker/telefonica/seed-golang)

# seed-golang

Seed project for Go language.

This project aims to provide an archetype of Go project, with a common scheleton that includes a development environment and a continuous delivery pipeline (integrated with dcip). It also builds the service with [govice](https://github.com/Telefonica/govice) to generate JSON logs, manage the configuration, handle errors and alarms, and validate JSON documents.

## Building the project

### Makefile usage

```
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
```

### Building the project locally

The source code of golang projects needs to be downloaded under `GOPATH`. Otherwise, the project packages cannot be found.

Prerequirements:
 - Golang 1.9
 - GNU Make

```sh
git clone git@github.com:Telefonica/seed-golang.git "$GOPATH/src/github.com/Telefonica/seed-golang"
cd "$GOPATH/src/github.com/Telefonica/seed-golang"
make build
```

### Building the project with the development environment

This project provides a development environment based on docker. It provides some benefits:
 - Common environment with required dependencies already installed
 - Pipelines to build the source code, pass the acceptance tests, package a docker image and publish the docker image.

Prerequirements:
 - Docker v17
 - GNU Make

```sh
# Launch the development environment
make develenv-up
# Access to the development environment
make develenv-sh
# Now you can launch any make task (e.g. pipeline-pull)
make pipeline-pull
```

### Pipelines

| Pipeline | Description |
| -------- | ----------- |
| pipeline-pull | Pipeline triggered by a pull request. |
| pipeline-dev | Pipeline triggered by a merge to master branch. It will publish a docker image in dockerhub.hi.inet |

### Make a release

A release will generate:

 - A new git tag. The tag is increased automatically taking the previous existing tag as reference and incrementing the second number. For example, if the latest tag is 0.3, a release would create a new tag 0.4.
 - A docker image versioned with this tag.
 - Release notes in github.

```sh
make pipeline-dev RELEASE=true
```

## Configuration

| Json Parameter | Env Parameter | Default value | Description |
|---|---|---|---|
| address | ADDRESS | :9000 | Address `ip:port` (ip is optional) where the service is listening |
| basePath | BASE_PATH | /seed | API base path. |
| logLevel | LOG_LEVEL | INFO | Log level. Possible values are: `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL` |
| mongoUrl | MONGO_URL | 127.0.0.1 | Mongo URL |
| mongoDatabase | MONGO_DATABASE | seed | Mongo database |

The default configuration is:

```json
{
  "address": ":9000",
  "basePath": "/seed",
  "logLevel": "INFO",
  "mongoUrl": "127.0.0.1",
  "mongoDatabase": "seed"
}
```

## Logs

Logs are written to console using a JSON format to make easier that log aggregators process them.

It is possible to override the default log level `INFO` by using the environment variable `LOG_LEVEL`.

The following log entries are written when the service is started up with default configuration:

```json
{"time":"2017-11-26T10:44:38.2435417Z","lvl":"INFO","op":"init","svc":"seed","msg":"Configuration: {\"address\":\":9000\",\"basePath\":\"/seed\",\"logLevel\":\"INFO\",\"mongoUrl\":\"127.0.0.1\",\"mongoDatabase\":\"seed\"}"}
{"time":"2017-11-26T10:44:38.2548223Z","lvl":"INFO","op":"init","svc":"seed","msg":"Starting server at :9000"}
```

The following log entries correspond to a user creation flow. Note that this flow includes a patch to niji backend (`updateBundle` operation to update the line_id in the bundle) and a post to nijiHome backend to create the user (`createUser` operation):

```json
{"time":"2017-11-26T10:45:56.0756457Z","lvl":"INFO","trans":"fb471406-d296-11e7-a2a4-0242ac1a0002","corr":"fb471406-d296-11e7-a2a4-0242ac1a0002","op":"createUser","svc":"seed","method":"POST","path":"/seed/users","remoteaddr":"172.26.0.1:39802","msg":"Request"}
{"time":"2017-11-26T10:45:56.0773839Z","lvl":"INFO","trans":"fb471406-d296-11e7-a2a4-0242ac1a0002","corr":"fb471406-d296-11e7-a2a4-0242ac1a0002","op":"createUser","svc":"seed","status":201,"latency":1,"location":"/seed/users/5a1a9b64edde3709d1feef8d","msg":"Response"}
```

Relevant log entry fields:

 - **svc**. It is the service name. All the log entries generated by the service are identified with `seed` service.
 - **op**. There are several operations: `createUser`, `getUser`, `deleteUser`, `updateUser`, `notAllowed`, and `notFound`.

## Alarms

| Alarm ID | Start condition | Stop condition | Description |
|---|---|---|---|
| SEED_INIT_01 | Log entry with **alarm** field to `SEED_INIT_01` | Log entry with **op** to `init`, and **msg** starts with `Starting service at` | The service cannot be initialised by a configuration issue or because the port is already used. Review the configuration. |

The following log traces correspond to a conflict with a port that is already in use when the service is launched. It generates an alarm `SEED_INIT_01`:

```json
{"time":"2017-11-26T10:49:06.6620696Z","lvl":"INFO","op":"init","svc":"seed","msg":"Configuration: {\"address\":\":9000\",\"basePath\":\"/seed\",\"logLevel\":\"DEBUG\",\"mongoUrl\":\"127.0.0.1\",\"mongoDatabase\":\"seed\"}"}
{"time":"2017-11-26T10:49:06.6775121Z","lvl":"INFO","op":"init","svc":"seed","msg":"Starting server at :9000"}
{"time":"2017-11-26T10:49:06.6862503Z","lvl":"FATAL","op":"init","svc":"seed","alarm":"SEED_INIT_01","msg":"Error starting server. listen tcp :9000: bind: address already in use"}
```

## DCIP configuration

### DCIP jobs

- Create a component to host the project jobs by executing `_component-setup`
- Build `_docker-slave-setup` (with branch: "master" and RAM: 2048)
- Configure `_docker-slave-builder`:
  - Disable automatic hook. Avoid creating the docker image whenever there is a merge in master branch.
  - Configure the location to the Dockerfile for development. Set as `Build Context` in `Docker Build and Publish`: **delivery/docker/dev**.
- Execute `_docker-slave-builder` job to create the dockerhub.hi.inet/dcip/seed-golang image that is going to be used in all the dcip jobs.
- Create `pipeline-01-pull`. This pipeline is triggered by pull requests:
  - Github project: https://github.com/Telefonica/seed-golang
  - Restrict project to: seed-golang
  - Use a custom workspace directory: /home/contint/go/src/github.com/Telefonica/seed-golang
  - Git:
    - Repository URL: git@github.com:Telefonica/seed-golang.git
      - Refspec: +refs/pull/*:refs/remotes/origin/pr/*
    - Branches to build: ${sha1}
  - Trigger:
    - Check "GitHub Pull Request Builder"
      - GitHub API credentials: https://api.github.com
      - Check "Use github hooks for build triggering"
      - Trigger phrase: "\Qtest\E"
      - Check: "Build every pull request automatically without asking (Dangerous!)."
  - Execution environment:
    - Check "Color ANSI Console Output"
  - Add execute step: "Execute command line (shell)" with:
      ```sh
      #!/bin/bash
      source /home/contint/.bashrc
      delivery/docker/dev/entrypoint.sh
      make pipeline-pull
      ```
  - Actions:
    - Add "Set build status on Github commit"
    - Publish Cobertura report:
      - Pattern: build/cover/cover.xml
- Create `pipeline-02-dev` by cloning `pipeline-01-pull`. This pipeline is trigger after a merge in master branch.
  - Execution is parameterized:
    - Add boolean value. Name: RELEASE.
    - Add text parameter. Name: GIT_REVISION. Default: master.
    - Add password parameter. Name: GITHUB_TOKEN. Default: Token generated with all repo permissions.
  - Git:
    - Empty Refspec
    - Branches to build: ${GIT_REVISION}
  - Trigger:
    - Uncheck: "GitHub Pull Request Builder"
    - Check: "GitHub hook trigger for GITScm polling"
  - Update execute step: "Execute command line (shell)" with:
      ```sh
      #!/bin/bash
      source /home/contint/.bashrc
      delivery/docker/dev/entrypoint.sh
      make pipeline-dev
      ```
  - Actions:
    - Remove "Set build status on Github commit"

### GitHub Configuration

See [Git WebHooks in DCIP](https://wikis.hi.inet/epg/index.php/DCIP#Git_webhooks).

- Add team `CI (w+r)` with "write" permissions
- Generate a [personal access token](https://github.com/settings/tokens) with all the repo permissions. Note that this token is required to generate the tag and publish the release notes. This is configured with environment variable `GITHUB_TOKEN`.
- Add webhook for Pull request:
  - Payload URL: "http://dcip.tid.es/ghprbhook/"
  - Content type: "application/x-www-form-urlencoded"
  - Let me select individual events:
    - Check "Issue comment" and "Pull request"
    - Uncheck "Push"
- Add webhook for merge:
  - Payload URL: "http://dcip.tid.es/github-webhook/"
  - Content type: "application/json"
  - Just the push event

## License

Copyright 2017 [Telefónica Investigación y Desarrollo, S.A.U](http://www.tid.es)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
