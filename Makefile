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
	docker-compose run --rm sidekiq bash -c "\
		bundle exec rails db:environment:set RAILS_ENV=development &&\
		bundle exec rails db:setup RAILS_ENV=development &&\
		bundle exec rails db:migrate RAILS_ENV=development"
	docker-compose down
	@echo "\nHometown initialization finished! You can now start all containers using: $ make up"

up: install
	docker-compose up

down:
	docker-compose down

clean:
	docker rm -f hometown-build
	docker buildx rm hometown || true
	docker-compose down
	docker volume rm -f $(DOCKER_PROJECT)_db $(DOCKER_PROJECT)_redis


install: build-development
	docker-compose down
	docker-compose up -d db
	docker-compose run --rm webpack bash -c "\
		bundle install -j`nproc` --deployment && \
		yarn install --pure-lockfile"

build-development:
	DOCKER_BUILDKIT=1 \
	docker build --target development \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		--tag $(LOCAL_IMAGE) .
