# Development

Development documentation with instructions how to setup the project for local development.

## Preliminary

* Docker

```sh
# screen 1
$ cp example.env .env
$ docker-compose up

# screen 2
$ docker-compose exec waffle sh
$ > mix deps.get
```

## Common tasks

```sh
# to run linter
$ mix credo --strict

# to generate documentation
$ MIX_ENV=dev mix docs

# to publish package
$ MIX_ENV=dev mix hex.publish

# to publish only documentation
$ MIX_ENV=dev mix hex.publish docs
 ```
