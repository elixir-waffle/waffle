import Config

config :waffle, Waffle.HTTPClient.Req,
  request_options: [
    plug: {Req.Test, Waffle.HTTPClient.Req}
  ]

config :ex_aws,
  http_client: ExAws.Request.Req
