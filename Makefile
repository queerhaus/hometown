DOCKER_IMAGE_DEV ?= "queerhaus/hometown:development"
DOCKER_IMAGE_PROD ?= "queerhaus/hometown:production"
UID ?= "991"
GID ?= "991"
DOCKER_PROJECT = $(shell basename "$$PWD")
NPROC = 1

# On Linux docker runs natively and the user in the container has to match current user.
# Otherwise files are created that cannot be read outside the container without sudo.
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	NPROC = $(shell nproc)
	UID=`id -u ${USER}`
	GID=`id -g ${USER}`
endif
ifeq ($(UNAME_S),Darwin)
	NPROC = $(shell sysctl -n hw.ncpu)
endif

init: install
	docker-compose -f docker-compose.local.yml run --rm sidekiq bash -c "\
		bundle exec rails db:environment:set RAILS_ENV=development &&\
		bundle exec rails db:setup RAILS_ENV=development &&\
		bundle exec rails db:migrate RAILS_ENV=development"
	docker-compose -f docker-compose.local.yml down
	@echo "\nHometown initialization finished! You can now start all containers using: $ make up"

up: install
	docker-compose -f docker-compose.local.yml up

down:
	docker-compose -f docker-compose.local.yml down

clean:
	docker rm -f hometown-build
	docker buildx rm hometown || true
	docker-compose -f docker-compose.local.yml down
	docker volume rm -f $(DOCKER_PROJECT)_db $(DOCKER_PROJECT)_redis


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
		--tag $(DOCKER_IMAGE_DEV) .

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
		--build-arg UID=`id -u ${USER}` \
		--build-arg GID=`id -g ${USER}` \
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
