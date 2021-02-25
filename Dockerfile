FROM elixir:1.11-alpine

# add `convert` utility from imagemagick for image transformations
RUN apk add --no-cache imagemagick

RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /srv/app

COPY . .

ENV MIX_ENV=test

RUN mix deps.get && mix compile

CMD mix test
