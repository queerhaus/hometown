#syntax=docker/dockerfile:1.2
FROM ubuntu:20.04 as development

# Use bash for the shell
SHELL ["bash", "-c"]

# Enable super fast apt caches for use with --mount=type=cache
RUN rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Install Node v12 (LTS)
ENV NODE_VER="12.20.0"
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
  ARCH= && \
    dpkgArch="$(dpkg --print-architecture)" && \
  case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
  esac && \
    echo "Etc/UTC" > /etc/localtime && \
	apt-get update && \
	apt-get -y install wget python && \
	cd ~ && \
	wget https://nodejs.org/download/release/v$NODE_VER/node-v$NODE_VER-linux-$ARCH.tar.gz && \
	tar xf node-v$NODE_VER-linux-$ARCH.tar.gz && \
	rm node-v$NODE_VER-linux-$ARCH.tar.gz && \
	mv node-v$NODE_VER-linux-$ARCH /opt/node

# Install jemalloc
ENV JE_VER="5.2.1"
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
  apt-get update && \
	apt-get -y install wget make autoconf gcc g++ && \
	cd ~ && \
	wget https://github.com/jemalloc/jemalloc/archive/$JE_VER.tar.gz && \
	tar xf $JE_VER.tar.gz && rm $JE_VER.tar.gz && \
	cd jemalloc-$JE_VER && \
	./autogen.sh && \
	./configure --prefix=/opt/jemalloc && \
	make -j$(nproc) > /dev/null && \
	make install_bin install_include install_lib && \
	rm -rf /root/jemalloc-$JE_VER

# Install Ruby
ENV RUBY_VER="2.7.2"
ENV CPPFLAGS="-I/opt/jemalloc/include"
ENV LDFLAGS="-L/opt/jemalloc/lib/"
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
  apt-get update && \
	apt-get -y install wget build-essential \
		bison libyaml-dev libgdbm-dev libreadline-dev \
		libncurses5-dev libffi-dev zlib1g-dev libssl-dev && \
	cd ~ && \
	wget https://cache.ruby-lang.org/pub/ruby/${RUBY_VER%.*}/ruby-$RUBY_VER.tar.gz && \
	tar xf ruby-$RUBY_VER.tar.gz && rm ruby-$RUBY_VER.tar.gz && \
	cd ruby-$RUBY_VER && \
	./configure --prefix=/opt/ruby \
	  --with-jemalloc \
	  --with-shared \
	  --disable-install-doc && \
	ln -s /opt/jemalloc/lib/* /usr/lib/ && \
	make -j$(nproc) > /dev/null && \
	make install && \
	rm -rf /root/ruby-$RUBY_VER

# Add more PATHs to the PATH
ENV PATH="${PATH}:/opt/ruby/bin:/opt/node/bin:/opt/mastodon/bin"

# Create the mastodon user
ARG UID=991
ARG GID=991
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
	echo "Etc/UTC" > /etc/localtime && \
  apt-get update && \
	apt-get install -y whois wget && \
	addgroup --gid $GID mastodon && \
	useradd -m -u $UID -g $GID -d /opt/mastodon mastodon && \
	echo "mastodon:`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256`" | chpasswd && \
	ln -s /opt/mastodon /mastodon

# Install mastodon runtime deps
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
  apt-get update && \
  apt-get -y --no-install-recommends install \
  build-essential git libicu-dev libidn11-dev \
  libpq-dev libprotobuf-dev protobuf-compiler \
  libssl1.1 libpq5 imagemagick ffmpeg \
  libicu66 libprotobuf17 libidn11 libyaml-0-2 \
  file ca-certificates tzdata libreadline8 tini

# We have to specify the version here, otherwise the `bundle install` fails later with error:
# Could not find 'bundler' (1.17.2) required by your /opt/mastodon/Gemfile.lock
RUN npm install -g yarn && gem install bundler:1.17.3

# Set the work dir and the container entry point
WORKDIR /opt/mastodon
ENTRYPOINT ["/usr/bin/tini", "--"]
EXPOSE 3000 4000
USER mastodon

# Tell rails to serve static files
ENV RAILS_SERVE_STATIC_FILES="true"
ENV BIND="0.0.0.0"

# Run mastodon services in development mode
ENV RAILS_ENV="development"
ENV NODE_ENV="development"

# Tell bundler to install to the vendor folder
RUN cd /opt/mastodon && bundle config set deployment 'true'


FROM development as production

# Copy over mastodon source, and set permissions
COPY --chown=mastodon:mastodon . /opt/mastodon

# Run mastodon services in production mode
ENV RAILS_ENV="production"
ENV NODE_ENV="production"
RUN cd /opt/mastodon && \
  bundle config set without 'development test'

# Install ruby dependencies
RUN bundle install -j$(nproc) --deployment --without 'development test'

# Install node dependencies
RUN yarn install --pure-lockfile

# Precompile assets
RUN cd ~ && \
	OTP_SECRET=precompile_placeholder \
	SECRET_KEY_BASE=precompile_placeholder \
	rails assets:precompile
