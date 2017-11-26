[![Build Status](https://dcip.hi.inet/job/niji/job/niji-orchestrator/job/pipeline-02-dev/badge/icon)](https://dcip.hi.inet/job/niji/job/niji-orchestrator/job/pipeline-02-dev)
[![DockerHub](https://img.shields.io/docker/automated/jrottenberg/ffmpeg.svg)](http://artifactory.hi.inet/artifactory/webapp/#/artifacts/browse/simple/General/docker/awazza/niji-orchestrator)

# niji-orchestrator

Orchestrator of niji and nijiHome backends to expose a single REST API.

![Architecture](doc/architecture.png)

The orchestrator service exposes the same provision API than niji and nijiHome backends. The orchestrator receives provision requests and proxies the request to the appropriate backend.

The niji backend manages all the mobile lines. It also manages fixed lines without HGU. The nijiHome backend only manages fixed lines with HGU.

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
  test-acceptance: Pass component tests
  package:         Create the docker image
  publish:         Publish the docker image
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
git clone git@pdihub.hi.inet:awazza/niji-orchestrator.git "$GOPATH/src/pdihub.hi.inet/awazza/niji-orchestrator"
cd "$GOPATH/src/pdihub.hi.inet/awazza/niji-orchestrator"
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
| address | ADDRESS | :9000 | Address `ip:port` (ip is optional) where the orchestrator service is listening |
| basePath | BASE_PATH | /partner/api/v2 | API base path. Note that currently it is required to have the same basePath for all the APIs (i.e. orchestrator service, niji backend, and nijiHome backend). |
| logLevel | LOG_LEVEL | INFO | Log level. Possible values are: `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL` |
| nijiUrl | NIJI_URL | http://localhost:8080 | Base URL for the niji backend |
| nijiHomeUrl | NIJI_HOME_URL | http://localhost:8181 | Base URL for the nijiHome backend |
| nijiHomeProductPattern | NIJI_HOME_PRODUCT_PATTERN | _hgu$ | Regex pattern to identify nijiHome products |
| fixedLinePattern | FIXED_LINE_PATTERN | ^9\\d{8} | Regex pattern to identify fixed lines |
| httpTimeout | HTTP_TIMEOUT | 5 | Timeout (in seconds) to resolve a HTTP request |
| realm | REALM | es | Realm. Possible values are: `es`, `tu`, `uk`, `br`, `ar`, `pe` |

The default configuration is:

```json
{
  "address": ":9000",
  "basePath": "/partner/api/v2",
  "logLevel": "INFO",
  "nijiUrl": "http://localhost:8080",
  "nijiHomeUrl": "http://localhost:8181",
  "nijiHomeProductPattern": "_hgu$",
  "fixedLinePattern": "^9\\d{8}",
  "httpTimeout": 5,
  "realm": "es"
}
```

## Logs

Logs are written to console using a JSON format to make easier that log aggregators process them.

It is possible to override the default log level `INFO` by using the environment variable `LOG_LEVEL`.

The following log entries are written when the orchestrator service is started up with default configuration:

```json
{"time":"2017-10-15T18:13:19.051869516Z","lvl":"INFO","op":"init","svc":"orch","msg":"Configuration: {\"address\":\":9000\",\"basePath\":\"/partner/api/v2\",\"logLevel\":\"INFO\",\"nijiUrl\":\"http://localhost:8080\",\"nijiHomeUrl\":\"http://localhost:8080\",\"nijiHomeProductPattern\":\"_hgu$\",\"fixedLinePattern\":\"^9\\\\d{8}\",\"httpTimeout\":5,\"realm\":\"es\"}"}
{"time":"2017-10-15T18:13:19.052495272Z","lvl":"INFO","op":"init","svc":"orch","realm":"es","msg":"Starting service at :9000"}
```

The following log entries correspond to a user creation flow. Note that this flow includes a patch to niji backend (`updateBundle` operation to update the line_id in the bundle) and a post to nijiHome backend to create the user (`createUser` operation):

```json
{"time":"2017-10-15T20:25:03.088944838+02:00","lvl":"INFO","trans":"293a30ed-b1d6-11e7-9368-186590e007bb","corr":"293a30ed-b1d6-11e7-9368-186590e007bb","op":"createUser","svc":"orch","comp":"orch","method":"POST","path":"/partner/api/v2/users","remoteaddr":"192.0.2.1:1234","msg":"Request"}
{"time":"2017-10-15T20:25:03.089112255+02:00","lvl":"INFO","trans":"293a30ed-b1d6-11e7-9368-186590e007bb","corr":"293a30ed-b1d6-11e7-9368-186590e007bb","op":"updateBundle","svc":"orch","comp":"niji","user":"912345678","method":"PATCH","path":"http://127.0.0.1:54782/partner/api/v2/bundles/test-bundle","msg":"Client request"}
{"time":"2017-10-15T20:25:03.089675768+02:00","lvl":"INFO","trans":"293a30ed-b1d6-11e7-9368-186590e007bb","corr":"293a30ed-b1d6-11e7-9368-186590e007bb","op":"updateBundle","svc":"orch","comp":"niji","user":"912345678","status":200,"msg":"Client response"}
{"time":"2017-10-15T20:25:03.089716148+02:00","lvl":"INFO","trans":"293a30ed-b1d6-11e7-9368-186590e007bb","corr":"293a30ed-b1d6-11e7-9368-186590e007bb","op":"createUser","svc":"orch","comp":"nijiHome","user":"912345678","method":"POST","path":"/partner/api/v2/users","msg":"Proxy request"}
{"time":"2017-10-15T20:25:03.090029434+02:00","lvl":"INFO","trans":"293a30ed-b1d6-11e7-9368-186590e007bb","corr":"293a30ed-b1d6-11e7-9368-186590e007bb","op":"createUser","svc":"orch","comp":"nijiHome","user":"912345678","status":201,"msg":"Proxy response"}
{"time":"2017-10-15T20:25:03.090073681+02:00","lvl":"INFO","trans":"293a30ed-b1d6-11e7-9368-186590e007bb","corr":"293a30ed-b1d6-11e7-9368-186590e007bb","op":"createUser","svc":"orch","comp":"orch","user":"912345678","status":201,"latency":1,"msg":"Response"}
```

Relevant log entry fields:

 - **svc**. It is the service name. All the log entries generated by the orchestrator are identified with `orch` service.
 - **comp**. There are 3 components: `orch` (the orchestrator), `niji` (the proxy to niji backend), and `nijiHome` (the proxy to nijiHome backend).
 - **op**. There are several operations: `createUser`, `getUser`, `deleteUser`, `updateUser`, `default`, and `notFound`. Note that `default` operations are not managed by the orchestrator and they are always proxied to the niji backend. The `notFound` operations correspond to HTTP requests mismatching the API base path.

## Alarms

| Alarm ID | Start condition | Stop condition | Description |
|---|---|---|---|
| ORCH_INIT_01 | Log entry with **alarm** field to `ORCH_INIT_01` | Log entry with **op** to `init`, and **msg** starts with `Starting service at` | The orchestrator service cannot be initialised by a configuration issue or because the port is already used. Review the configuration. |
| ORCH_PROXY_01 | Log entry with **alarm** field to `ORCH_PROXY_01` | Log entry with **lvl** to `INFO`, **comp** to `niji`, and **msg** to either `Client response` or `Proxy response` | Runtime alarm when there is no connection to niji backend. Verify that there is connectivity between the orchestrator and the niji backend. |
| ORCH_PROXY_02 | Log entry with **alarm** field to `ORCH_PROXY_02` | Log entry with **lvl** to `INFO`, **comp** to `nijiHome`, and **msg** to either `Client response` or `Proxy response` | Runtime alarm when there is no connection to nijiHome backend. Verify that there is connectivity between the orchestrator and the nijiHome backend.  |

The following log traces correspond to a user query when the proxy to niji backend is down. It generates an alarm `ORCH_PROXY_01` associated to the niji backend (see **comp** field):

```json
{"time":"2017-10-17T06:21:53.401291671Z","lvl":"INFO","trans":"77c8d1d1-b303-11e7-9164-186590e007bb","corr":"77c8d1d1-b303-11e7-9164-186590e007bb","op":"getUser","svc":"orch","comp":"orch","realm":"es","method":"GET","path":"/partner/api/v2/users/34638123456","remoteaddr":"[::1]:49642","msg":"Request"}
{"time":"2017-10-17T06:21:53.40136839Z","lvl":"INFO","trans":"77c8d1d1-b303-11e7-9164-186590e007bb","corr":"77c8d1d1-b303-11e7-9164-186590e007bb","op":"getUser","svc":"orch","comp":"niji","user":"34638123456","realm":"es","method":"GET","path":"/partner/api/v2/users/34638123456","msg":"Proxy request"}
{"time":"2017-10-17T06:21:53.402493153Z","lvl":"ERROR","trans":"77c8d1d1-b303-11e7-9164-186590e007bb","corr":"77c8d1d1-b303-11e7-9164-186590e007bb","op":"getUser","svc":"orch","comp":"niji","user":"34638123456","realm":"es","alarm":"ORCH_PROXY_01","msg":"dial tcp [::1]:8080: getsockopt: connection refused"}
{"time":"2017-10-17T06:21:53.402551107Z","lvl":"INFO","trans":"77c8d1d1-b303-11e7-9164-186590e007bb","corr":"77c8d1d1-b303-11e7-9164-186590e007bb","op":"getUser","svc":"orch","comp":"orch","user":"34638123456","realm":"es","status":502,"latency":1,"msg":"Response"}
```

## Flows

### Create user

![Architecture](doc/flow-create-user.png)

### Get/Delete user

![Architecture](doc/flow-get-user.png)

### Update user

![Architecture](doc/flow-update-user.png)

## Known issues

 - It is impossible to migrate a fixed line from nijiHome to niji. It is required to remove the line in nijiHome backend, and then to create a new line in niji backend.
 - It is not implemented the update of the `line_id` for a nijiHome user. Note that the `line_id` must be stored in the niji backend as well because it is required to invoke the McAfee API.
 - If the fixed line is removed from nijiHome backend, the `line_id` is not removed from the bundle resource in the niji backend.
 - If a user is migrated from niji backend to nijiHome backend, the request to create the user in nijiHome backend will not contain the external_id and the user settings (e.g. if onlineProtection is enabled or not).

## License

```
//
// Copyright (c) Telefonica I+D. All rights reserved.
//
```
