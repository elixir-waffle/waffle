import Config

config :waffle,
  storage: Waffle.Storage.S3,
  http_client: Waffle.HTTPClient.Req,
  request: [
    max_redirects: 4
  ]

config :ex_aws,
  json_codec: Jason

if config_env() == :test do
  import_config "test.exs"
end
