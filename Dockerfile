FROM elixir:1.12-alpine as build

ARG DATABASE_URL
ARG SECRET_KEY_BASE

# install build dependencies
RUN apk add --no-cache build-base npm git python3

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix do deps.get, deps.compile

# build assets
# COPY assets/package.json assets/package-lock.json ./assets/
# RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error


COPY priv priv
COPY assets assets
# Compile assets
RUN mix assets.deploy

RUN mix phx.digest

# compile and build release
COPY lib lib
# uncomment COPY if rel/ exists
# COPY rel rel
RUN mix do compile, release

# prepare release image
FROM alpine:latest AS app
# added bash and postgresql-client for entrypoint.sh
RUN apk add --no-cache openssl ncurses-libs bash postgresql-client

RUN mkdir /app
WORKDIR /app

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/pento ./
COPY entrypoint.sh .

RUN chown -R nobody: /app
USER nobody

ENV HOME=/app

CMD ["bash", "/app/entrypoint.sh"]