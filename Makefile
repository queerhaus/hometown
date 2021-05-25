DOCKER_IMAGE_LOCAL ?= "queerhaus:local"
DOCKER_IMAGE_PROD ?= "ghcr.io/queerhaus/hometown"
DOCKER_PROJECT = $(shell basename "$$PWD")
DOCKER_DB_INIT_FILE_CHECK = ".docker-db-initialized"
UNAME_S := $(shell uname -s)
UID ?= "991"
GID ?= "991"
NPROC = 1

ifeq ($(UNAME_S),Linux)
	NPROC = $(shell nproc)
	UID=`id -u ${USER}`
	GID=`id -g ${USER}`
endif
ifeq ($(UNAME_S),Darwin)
	NPROC = $(shell sysctl -n hw.ncpu)
endif

up:
ifeq (,$(wildcard $(DOCKER_DB_INIT_FILE_CHECK)))
	@echo "Database has not been initialized, running init script..."
	make init
else
	make install
endif
	docker-compose -f docker-compose.local.yml up

init: install
	docker-compose -f docker-compose.local.yml run --rm sidekiq bash -c "\
		bundle exec rails db:environment:set RAILS_ENV=development &&\
		bundle exec rails db:setup RAILS_ENV=development &&\
		bundle exec rails db:migrate RAILS_ENV=development"
	docker-compose -f docker-compose.local.yml down
	touch $(DOCKER_DB_INIT_FILE_CHECK)
	@echo "\nHometown initialization finished! You can now start all containers using: $ make up"

down:
	docker-compose -f docker-compose.local.yml down

clean:
	docker rm -f hometown-build
	docker buildx rm hometown || true
	docker-compose -f docker-compose.local.yml down
	docker volume rm -f $(DOCKER_PROJECT)_db $(DOCKER_PROJECT)_redis
	rm $(DOCKER_DB_INIT_FILE_CHECK)


install: build-development
	docker-compose -f docker-compose.local.yml down
	docker-compose -f docker-compose.local.yml up -d db
	docker-compose -f docker-compose.local.yml run --rm webpack bash -c "\
		bundle install -j$(NPROC) --deployment && \
		yarn install --pure-lockfile"

build-development:
	DOCKER_BUILDKIT=1 \
	docker build --target development \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		--tag $(DOCKER_IMAGE_LOCAL) .
