# If the first argument is "run"...
ifeq ($(shell test "$(firstword $(MAKECMDGOALS))" = build -o "$(firstword $(MAKECMDGOALS))" = push && echo -n true), true)
  # use the rest as arguments for "run"
  ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn them into do-nothing targets
  $(eval $(ARGS):;@:)
endif

IMAGE_BASE_REF?=quay.io/pmacik/tekton-poc
STEPS ?= setup create-ocp test metrics

.PHONY: build
build:
	docker build -f sbo-perf/steps/Dockerfile -t $(IMAGE_BASE_REF):$(ARGS) sbo-perf/steps/$(ARGS)

.PHONY: build-all
build-all:
	for i in $(STEPS); do $(MAKE) build $$i; done

.PHONY: push
push: build $(ARGS)
	docker push $(IMAGE_BASE_REF):$(ARGS)

.PHONY: push-all
push-all:
	for i in $(STEPS); do $(MAKE) push $$i; done

.PHONY: install-secrets
install-secrets:
	cat *secret.yaml | oc apply -f -

.PHONY: install-step-images
install-step-images:
	for i in $(STEPS); do sed -e "s,@@STEP@@,$$i,g" sbo-perf/steps/buildconfig_imagestream_template.yaml | oc apply -f -; done

.PHONY: install-pipelines-operator
install-pipelines-operator:
	./hack/install-pipelines-operator.sh

.PHONY: install-pipeline
install-pipeline:
	cat pipeline.yaml artifacts.*.yaml sbo-perf/task.yaml | oc apply -f -

.PHONY: sbo-perf
sbo-perf:
	tkn pipeline start sbo-perf --timeout 5h --workspace name=artifacts,claimName=sbo-perf-artifacts,subPath=.
