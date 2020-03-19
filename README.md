# Waffle

[![Codeship Status for elixir-waffle/waffle][codeship-img]][codeship-url]
[![Hex.pm Version][hex-img]][hex-url]
[![waffle documentation][hexdocs-img]][hexdocs-url]

[codeship-img]: https://app.codeship.com/projects/182a04b0-aa53-0137-1d00-2259d5318dee/status?branch=master
[codeship-url]: https://app.codeship.com/projects/361668
[hex-img]: http://img.shields.io/hexpm/v/waffle.svg
[hex-url]: https://hex.pm/packages/waffle
[hexdocs-img]: http://img.shields.io/badge/hexdocs-documentation-brightgreen.svg
[hexdocs-url]: https://hexdocs.pm/waffle

[logo-img]: https://elixir-waffle.github.io/waffle/assets/logo.svg
[Waffle]: https://evrone.com/waffle-elixir-library?utm_source=github&utm_campaign=waffle
[Evrone design team]: https://evrone.com/branding?utm_source=github&utm_campaign=waffle
[build with Elixir]: https://evrone.com/elixir?utm_source=github&utm_campaign=waffle

<img align="right" width="176" height="120"
     alt="Waffle is a flexible file upload library for Elixir"
     src="https://elixir-waffle.github.io/waffle/assets/logo.svg">

[Waffle] is a flexible file upload library for Elixir with straightforward integrations for Amazon S3 and ImageMagick.

Waffle is a flexible file upload library for Elixir with straightforward integrations for Amazon S3 and ImageMagick.

[Documentation](https://hexdocs.pm/waffle)

Thanks [Evrone design team] for Waffle's branding.

What else we [build with Elixir] at Evrone.

## Installation

Add the latest stable release to your `mix.exs` file, along with the required dependencies for `ExAws` if appropriate:

```elixir
defp deps do
  [
    {:waffle, "~> 1.0.0"},

    # If using S3:
    {:ex_aws, "~> 2.1"},
    {:ex_aws_s3, "~> 2.0"},
    {:hackney, "~> 1.9"},
    {:sweet_xml, "~> 0.6"}
  ]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies.

### Configuration

Waffle expects certain properties to be configured at the application level:

```elixir
config :waffle,
  storage: Waffle.Storage.S3, # or Waffle.Storage.Local
  bucket: {:system, "AWS_S3_BUCKET"}, # if using S3
  asset_host: "http://static.example.com" # or {:system, "ASSET_HOST"}

# If using S3:
config :ex_aws,
  json_codec: Jason
```

Along with any configuration necessary for ExAws.

### Usage with Ecto

Waffle comes with a companion package for use with Ecto.  If you intend to use Waffle with Ecto, it is highly recommended you also add the [`waffle_ecto`](https://github.com/elixir-waffle/waffle_ecto) dependency.  Benefits include:

  * Changeset integration
  * Versioned urls for cache busting (`.../thumb.png?v=63601457477`)

## License

Copyright 2019 Boris Kuznetsov
Copyright 2015 Sean Stavropoulos

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
