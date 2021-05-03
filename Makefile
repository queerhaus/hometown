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

build-production:
	# Docker buildx works and produces a cache folder that we can save to Github Actions cache.
	# The negative with buildx local cache output is that it keeps growing over time,
	# and quickly reaches gigabytes upon gigabytes of size.
	# https://github.com/moby/buildkit/issues/1947

	# I was hoping to use buildkit cache mounts for bundler and yarn caches,
	# but until they are stored in the buildkit cache output,
	# we cannot save them in GitHub actions cache.
	# https://github.com/moby/buildkit/issues/1512
	# https://github.com/moby/buildkit/issues/1474
	# So to get around this, we build and then extract the vendor and node_modules from the image.

	# Build base image using buildx with local cache
	docker buildx rm hometown || true
	docker buildx create --name hometown --use
	docker buildx build \
		--cache-from type=local,src=docker/cache \
		--cache-to type=local,dest=docker/cache \
		--target production \
		--tag $(DOCKER_IMAGE_PROD) --load .
	docker buildx rm hometown

	# Build finished, store our new cache folders
	rm -rf ./vendor ./node_modules
	docker rm -f hometown-build
	docker run -i -d --name hometown-build $(DOCKER_IMAGE_PROD) bash
	docker cp hometown-build:/opt/mastodon/vendor ./
	docker cp hometown-build:/opt/mastodon/node_modules ./
	docker rm -f hometown-build
