import Config

config :waffle,
  storage: Waffle.Storage.S3

config :ex_aws,
  json_codec: Jason
