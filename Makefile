LOCAL_IMAGE ?= "queerhaus/hometown:development"
PRODUCTION_IMAGE ?= "queerhaus/hometown:production"
UID ?= "991"
GID ?= "991"
DOCKER_PROJECT = $(shell basename "$$PWD")

# On Linux docker runs natively and the user in the container has to match current user.
# Otherwise files are created that cannot be read outside the container without sudo.
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	UID=`id -u ${USER}`
	GID=`id -g ${USER}`
endif

init: install
	docker-compose run --rm sidekiq bash -c "bundle exec rails db:environment:set RAILS_ENV=development &&\
												          				 bundle exec rails db:setup RAILS_ENV=development &&\
												          				 bundle exec rails db:migrate RAILS_ENV=development"
	docker-compose down
	echo "Hometown initialization finished! You can now start all containers using: $ make up"

up: install
	docker-compose up

down:
	docker-compose down

clean:
	docker rm -f hometown-build
	docker-compose down
	docker volume rm -f $(DOCKER_PROJECT)_db $(DOCKER_PROJECT)_redis


install: build-development
	docker-compose up -d db
	docker-compose run --rm webpack bash -c "bundle install --deployment && yarn install"

build-development:
	docker build --target development \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		--tag $(LOCAL_IMAGE) .

build-production:
	# Build base image
	docker rm -f hometown-build
	docker build --target production-base \
		--cache-from $(PRODUCTION_IMAGE) \
		--build-arg UID=`id -u ${USER}` \
		--build-arg GID=`id -g ${USER}` \
		--tag $(PRODUCTION_IMAGE) .

	# Install dependencies with cached volumes
	mkdir -p $(PWD)/docker/data/yarn-cache
	mkdir -p $(PWD)/docker/data/bundler-cache/vendor
	docker run -i -d --name hometown-build \
		-v $(PWD)/docker/data/yarn-cache:/data/yarn-cache \
		$(PRODUCTION_IMAGE) bash
	docker cp $(PWD)/docker/data/bundler-cache/vendor hometown-build:/opt/mastodon/
	docker exec -i hometown-build bundle install -j`nproc` --deployment --without 'development test'
	docker cp hometown-build:/opt/mastodon/vendor $(PWD)/docker/data/bundler-cache/
	docker exec -i -e YARN_CACHE_FOLDER=/data/yarn-cache hometown-build yarn install -j`nproc` --pure-lockfile
	docker commit hometown-build $(PRODUCTION_IMAGE)
	docker rm -f hometown-build

	# Precompile assets without cached volumes
	docker run -i -d --name hometown-build $(PRODUCTION_IMAGE) bash
	docker exec -i hometown-build bash -c "\
		OTP_SECRET=precompile_placeholder \
		SECRET_KEY_BASE=precompile_placeholder \
		rails assets:precompile"
	docker commit hometown-build $(PRODUCTION_IMAGE)
	docker rm -f hometown-build

