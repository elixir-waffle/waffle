# Waffle

<img align="right" width="160"
     alt="Waffle logo"
     src="https://elixir-waffle.github.io/waffle/assets/logo.svg">

Waffle is a flexible file upload library for Elixir with straightforward integrations for Amazon S3 and ImageMagick.

[Documentation](https://waffle.hexdocs.pm/readme.html)
 · [Hex](https://hex.pm/packages/waffle)

[Presentation at ElixirConf](https://www.youtube.com/watch?v=4iM-V9yELsE)
 · [Thinking Elixir Podcast 80](https://podcast.thinkingelixir.com/80)

---

Already using Waffle in your org? I'd love to learn more. Let's [have a chat](https://cal.com/achempion/meet) or just [send me an email](mailto:me@achempion.com?subject=Feedback%20on%20Waffle).

---

## Why use Waffle?

You want to apply file transformations, manage access rules, save files, or process files asynchronously.

## Quick start

Add the `:waffle` dependency to `mix.exs`.

**mix.exs**
```elixir
{:waffle, "~> 2.0"},
{:waffle_ecto, "~> 0.0"}
```

Configure file storage

```elixir
config :waffle, storage: Waffle.Storage.Local
```

_Read more about [storage configuration](https://waffle.hexdocs.pm/Waffle.Definition.Storage.html) and the supported adapters (including S3)._

Create an uploader module with `mix waffle.g avatar`

```elixir
defmodule MyApp.Avatar do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  def storage_dir(_version, {_file, user}) do
    "users/#{user.id}/avatar/"
  end
end
```

Update the user schema

```elixir
schema "users" do
  field :avatar, Avatar.Type
end
```

Cast the file payload with a changeset

```
changeset
|> cast_attachments(
  params,
  [:avatar],
  allow_paths: true,
  allow_urls: true
)
```

_Read more about Ecto integration in the [WaffleEcto documentation](https://waffle-ecto.hexdocs.pm/)._
_WaffleEcto supports changeset integration and versioned URLs for cache busting._

## More Examples

* [An example for the Local storage driver](documentation/examples/local.md)
* [An example for the S3 storage driver](documentation/examples/s3.md)

## Attribution

This library was forked from [Arc](https://github.com/stavro/arc) at version `v0.11.0`. Special thanks to Sean Stavropoulos ([@stavro](https://github.com/stavro)) for creating Arc.

## Sponsors

- [Evrone](https://evrone.com?utm_source=waffle), custom software development company
- [Oficinaria](https://oficinaria.com.br?utm_source=waffle), marketplace for in-person creative workshops Brazil

## License

Copyright 2019 Boris Kuznetsov <me@achempion.com>

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
