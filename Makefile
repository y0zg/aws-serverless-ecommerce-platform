# Setup variables
NAME = ecommerce-platform
PYENV := $(shell which pyenv)
SPECCY := $(shell which speccy)
JQ := $(shell which jq)
PYTHON_VERSION = 3.8.1

# Service variables
SERVICES = $(shell tools/services)
SERVICES_ENVONLY = $(shell tools/services --env-only)
export DOMAIN ?= ecommerce
export ENVIRONMENT ?= dev

# Colors
ccblue = \033[0;96m
ccend = \033[0m

###################
# SERVICE TARGETS #
###################

# Run pipeline on services
all: $(foreach service,${SERVICES_ENVONLY}, all-${service})
all-%: 
	@${MAKE} lint-$*
	@${MAKE} clean-$*
	@${MAKE} build-$*
	@${MAKE} tests-unit-$*
	@${MAKE} check-deps-$*
	@${MAKE} package-$*
	@${MAKE} deploy-$*
	@${MAKE} tests-integ-$*

# Run CI on services
ci: $(foreach service,${SERVICES}, ci-${service})
ci-%:
	@${MAKE} lint-$*
	@${MAKE} clean-$*
	@${MAKE} build-$*
	@${MAKE} tests-unit-$*

# Artifacts services
artifacts: $(foreach service,${SERVICES_ENVONLY}, all-${service})
artifacts-%:
	@echo "[*] $(ccblue)artifacts $*$(ccend)"
	@${MAKE} -C $* artifacts

# Build services
build: $(foreach service,${SERVICES}, build-${service})
build-%:
	@echo "[*] $(ccblue)build $*$(ccend)"
	@${MAKE} -C $* build

# Check-deps services
check-deps: $(foreach service,${SERVICES_ENVONLY}, check-deps-${service})
check-deps-%:
	@echo "[*] $(ccblue)check-deps $*$(ccend)"
	@${MAKE} -C $* check-deps

# Clean services
clean: $(foreach service,${SERVICES}, clean-${service})
clean-%:
	@echo "[*] $(ccblue)clean $*$(ccend)"
	@${MAKE} -C $* clean

deploy: $(foreach service,${SERVICES_ENVONLY}, deploy-${service})
deploy-%:
	@echo "[*] $(ccblue)deploy $*$(ccend)"
	@${MAKE} -C $* deploy

# Lint services
lint: $(foreach service,${SERVICES}, lint-${service})
lint-%:
	@echo "[*] $(ccblue)lint $*$(ccend)"
	@${MAKE} -C $* lint

# Package services
package: $(foreach service,${SERVICES_ENVONLY}, package-${service})
package-%:
	@echo "[*] $(ccblue)package $*$(ccend)"
	@${MAKE} -C $* package

# Teardown services
# When running `make teardown`, the shell command inverts the service to remove them in reverse dependency order
teardown: $(foreach service,$(shell echo ${SERVICES_ENVONLY} | awk '{ for (i=NF; i>1; i--) printf("%s ",$$i); print $$1; }'), teardown-${service})
teardown-%:
	@echo "[*] $(ccblue)teardown $*$(ccend)"
	@${MAKE} -C $* teardown

# Integration tests
tests-integ: $(foreach service,${SERVICES_ENVONLY}, tests-integ-${service})
tests-integ-%:
	@echo "[*] $(ccblue)tests-integ $*$(ccend)"
	@${MAKE} -C $* tests-integ

# Unit tests
tests-unit: $(foreach service,${SERVICES}, tests-unit-${service})
tests-unit-%:
	@echo "[*] $(ccblue)tests-unit $*$(ccend)"
	@${MAKE} -C $* tests-unit

#################
# SETUP TARGETS #
#################

# Validate that necessary tools are installed
validate: validate-pyenv validate-speccy validate-jq

# Validate that pyenv is installed
validate-pyenv:
ifndef PYENV
	$(error Make sure pyenv is accessible in your path. You can install pyenv by following the instructions at 'https://github.com/pyenv/pyenv-installer'.)
endif
ifndef PYENV_SHELL
	$(error Add 'pyenv init' to your shell to enable shims and autocompletion.)
endif
ifndef PYENV_VIRTUALENV_INIT
	$(error Add 'pyenv virtualenv-init' to your shell to enable shims and autocompletion.)
endif

# Validate that speccy is installed
validate-speccy:
ifndef SPECCY
	$(error 'speccy' not found. You can install speccy by following the instructions at 'https://github.com/wework/speccy'.)
endif

# Validate that jq is installed
validate-jq:
ifndef JQ
	$(error 'jq' not found. You can install jq by following the instructions at 'https://stedolan.github.io/jq/download/'.)
endif

# setup: configure tools
setup: validate
	@echo "[*] Download and install python $(PYTHON_VERSION)"
	@pyenv install $(PYTHON_VERSION)
	@pyenv local $(PYTHON_VERSION)
	@echo "[*] Create virtualenv $(NAME) using python $(PYTHON_VERSION)"
	@pyenv virtualenv $(PYTHON_VERSION) $(NAME)
	@$(MAKE) activate
	@$(MAKE) requirements
	@${MAKE} npm-install

# Activate the virtual environment
activate: validate-pyenv
	@echo "[*] Activate virtualenv $(NAME)"
	$(shell eval "$$(pyenv init -)" && eval "$$(pyenv virtualenv-init -)" && pyenv activate $(NAME) && pyenv local $(NAME))

# Install python dependencies
requirements:
	@echo "[*] Install Python requirements"
	@pip install -r requirements.txt

# Install npm dependencies
npm-install:
	@echo "[*] Install NPM tools"
	@npm install -g speccy

# Create the entire pipeline
bootstrap-pipeline:
	# Deploy in different environments
	@${MAKE} all ENVIRONMENT=tests
	#@${MAKE} all ENVIRONMENT=staging
	#@${MAKE} all ENVIRONMENT=prod
	# Deploy the pipeline
	@{MAKE} all-pipeline
	# Seed the git repository
	@echo "[*] seed repository"
	@git remote add aws $(shell aws ssm get-parameter --name /ecommerce/pipeline/repository/url | jq -r '.Parameter.Value')
	@git push aws HEAD:master
