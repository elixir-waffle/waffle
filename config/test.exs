import Config

config :waffle, Waffle.HTTPClient.Req,
  request_options: [
    plug: {Req.Test, Waffle.HTTPClient.Req}
  ]
