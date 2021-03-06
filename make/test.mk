############################################################
#
# (local) Tests
#
############################################################

.PHONY: test
## runs the tests without coverage and excluding E2E tests
test:
	@echo "running the tests without coverage and excluding E2E tests..."
	$(Q)go test ${V_FLAG} -race $(shell go list ./... | grep -v /test/e2e) -failfast


############################################################
#
# OpenShift CI Tests with Coverage
#
############################################################

# Output directory for coverage information
COV_DIR = $(OUT_DIR)/coverage

.PHONY: test-with-coverage
## runs the tests with coverage
test-with-coverage:
	@echo "running the tests with coverage..."
	@-mkdir -p $(COV_DIR)
	@-rm $(COV_DIR)/coverage.txt
	$(Q)go test -vet off ${V_FLAG} $(shell go list ./... | grep -v /test/e2e) -coverprofile=$(COV_DIR)/coverage.txt -covermode=atomic ./...

.PHONY: upload-codecov-report
# Uploads the test coverage reports to codecov.io. 
# DO NOT USE LOCALLY: must only be called by OpenShift CI when processing new PR and when a PR is merged! 
upload-codecov-report: 
	# Upload coverage to codecov.io. Since we don't run on a supported CI platform (Jenkins, Travis-ci, etc.), 
	# we need to provide the PR metadata explicitely using env vars used coming from https://github.com/openshift/test-infra/blob/master/prow/jobs.md#job-environment-variables
	# 
	# Also: not using the `-F unittests` flag for now as it's temporarily disabled in the codecov UI 
	# (see https://docs.codecov.io/docs/flags#section-flags-in-the-codecov-ui)
	env
ifneq ($(PR_COMMIT), null)
	@echo "uploading test coverage report for pull-request #$(PULL_NUMBER)..."
	bash <(curl -s https://codecov.io/bash) \
		-t $(CODECOV_TOKEN) \
		-f $(COV_DIR)/coverage.txt \
		-C $(PR_COMMIT) \
		-r $(REPO_OWNER)/$(REPO_NAME) \
		-P $(PULL_NUMBER) \
		-Z
else
	@echo "uploading test coverage report after PR was merged..."
	bash <(curl -s https://codecov.io/bash) \
		-t $(CODECOV_TOKEN) \
		-f $(COV_DIR)/coverage.txt \
		-C $(BASE_COMMIT) \
		-r $(REPO_OWNER)/$(REPO_NAME) \
		-Z
endif

CODECOV_TOKEN := "b4bc232f-a825-4dc2-add1-5ab6e896b0a4"
REPO_OWNER := $(shell echo $$CLONEREFS_OPTIONS | jq '.refs[0].org')
REPO_NAME := $(shell echo $$CLONEREFS_OPTIONS | jq '.refs[0].repo')
BASE_COMMIT := $(shell echo $$CLONEREFS_OPTIONS | jq '.refs[0].base_sha')
PR_COMMIT := $(shell echo $$CLONEREFS_OPTIONS | jq '.refs[0].pulls[0].sha')
PULL_NUMBER := $(shell echo $$CLONEREFS_OPTIONS | jq '.refs[0].pulls[0].number')

TOOLCHAIN_NS := toolchain-operator-$(shell date +'%s')

###########################################################
#
# End-to-end Tests
#
###########################################################

DATE_SUFFIX := $(shell date +'%s')

IS_OS_3 := $(shell curl -k -XGET -H "Authorization: Bearer $(shell oc whoami -t 2>/dev/null)" $(shell oc config view --minify -o jsonpath='{.clusters[0].cluster.server}')/version/openshift 2>/dev/null | grep paths)
IS_OS_CI := $(OPENSHIFT_BUILD_NAMESPACE)

.PHONY: test-e2e-keep-namespaces
test-e2e-keep-namespaces: e2e-setup e2e-run

.PHONY: test-e2e
test-e2e: test-e2e-keep-namespaces e2e-cleanup

.PHONY: e2e-run
e2e-run:
	operator-sdk test local ./test/e2e --no-setup --namespace $(TOOLCHAIN_NS) --verbose --go-test-flags "-timeout=15m" || \
	($(MAKE) print-logs TOOLCHAIN_NS=${TOOLCHAIN_NS} && exit 1)

.PHONY: print-logs
print-logs:
	@echo "=====================================================================================" &
	@echo "============================== Toolchain cluster logs ==============================="
	@echo "====================================================================================="
	@oc logs deployment.apps/toolchain-operator --namespace $(TOOLCHAIN_NS)
	@echo "====================================================================================="

.PHONY: e2e-setup
e2e-setup: build-image
	oc new-project $(TOOLCHAIN_NS) --display-name e2e-tests
	oc apply -f ./deploy/service_account.yaml
	oc apply -f ./deploy/role.yaml
	oc apply -f ./deploy/role_binding.yaml
	oc apply -f ./deploy/cluster_role.yaml
	sed -e 's|REPLACE_NAMESPACE|${TOOLCHAIN_NS}|g' ./deploy/cluster_role_binding.yaml | oc apply -f -
	oc apply -f deploy/crds
	sed -e 's|REPLACE_IMAGE|${IMAGE_NAME}|g' ./deploy/operator.yaml  | oc apply -f -

.PHONY: build-image
build-image:
ifneq ($(IS_OS_3),)
	$(info logging as system:admin")
	$(shell echo "oc login -u system:admin")
	$(eval IMAGE_NAME := docker.io/${GO_PACKAGE_ORG_NAME}/${GO_PACKAGE_REPO_NAME}:${GIT_COMMIT_ID_SHORT})
	$(MAKE) docker-image IMAGE_NAME=${IMAGE_NAME}
else ifneq ($(IS_OS_CI),)
	$(eval IMAGE_NAME := registry.svc.ci.openshift.org/${OPENSHIFT_BUILD_NAMESPACE}/stable:toolchain-operator)
else
	# For OpenShift-4
	$(eval IMAGE_NAME := quay.io/${QUAY_NAMESPACE}/${GO_PACKAGE_REPO_NAME}:${DATE_SUFFIX})
	$(MAKE) docker-image IMAGE_NAME=${IMAGE_NAME}
	$(Q)docker push ${IMAGE_NAME}
endif

.PHONY: e2e-cleanup
e2e-cleanup:
	oc delete project ${TOOLCHAIN_NS} --wait=false || true

.PHONY: clean-e2e-namespaces
clean-e2e-namespaces:
	$(Q)-oc get projects --output=name | grep -E "toolchain\-operator\-[0-9]+" | xargs oc delete
