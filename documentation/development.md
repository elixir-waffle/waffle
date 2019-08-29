# Development

Development documentation with instructions how to setup the project for local development.

## Preliminary

* Docker

```sh
# screen 1
$ docker-compose up

# screen 2
$ docker-compose exec waffle sh
$ > mix deps.get
```

## Run tests

### Tests without S3 integration
```sh
$ mix test
```

### Tests with S3 integration

AWS S3 setup
- create a new user with FullS3Access
- copy `key_id` and `secret`
- create a new backet with *public access*
- comment the `s3` exlusion inside `test/test_helper.exs`

```sh
$ export WAFFLE_TEST_BUCKET=
$ export WAFFLE_TEST_S3_KEY=
$ export WAFFLE_TEST_S3_SECRET=
$ mix test
```
