defmodule Waffle do
  @moduledoc ~S"""
  Waffle is a flexible file upload library for Elixir with straightforward integrations for Amazon S3 and ImageMagick.

  ## Installation

  Add the latest stable release to your `mix.exs` file, along with the
  required dependencies for `ExAws` if appropriate:

      defp deps do
        [
          {:waffle, "~> 1.1.0"},

          # If using S3:
          {:ex_aws, "~> 2.1.2"},
          {:ex_aws_s3, "~> 2.0"},
          {:hackney, "~> 1.9"},
          {:sweet_xml, "~> 0.6"}
        ]
      end

  Then run `mix deps.get` in your shell to fetch the dependencies.

  ## Configuration

  Waffle expects certain properties to be configured at the application level:

      config :waffle,
        storage: Waffle.Storage.S3, # or Waffle.Storage.Local
        bucket: {:system, "AWS_S3_BUCKET"}, # if using S3
        asset_host: "http://static.example.com" # or {:system, "ASSET_HOST"}

      # If using S3:
      config :ex_aws,
        json_codec: Jason

  Along with any configuration necessary for ExAws.

  ## Storage Providers

  Waffle ships with integrations for `Waffle.Storage.Local` and
  `Waffle.Storage.S3`.  Alternative storage providers may be supported
  by the community:

    * **Rackspace** - [arc_rackspace](https://github.com/lokalebasen/arc_rackspace)

    * **Manta** - [arc_manta](https://github.com/onyxrev/arc_manta)

    * **OVH** - [arc_ovh](https://github.com/stephenmoloney/arc_ovh)

    * **Google Cloud Storage** - [waffle_gcs](https://github.com/kolorahl/waffle_gcs)

    * **Microsoft Azure Storage** - [arc_azure](https://github.com/phil-a/arc_azure])

  ## Usage with Ecto

  Waffle comes with a companion package for use with Ecto.  If you
  intend to use Waffle with Ecto, it is highly recommended you also
  add the
  [`waffle_ecto`](https://github.com/elixir-waffle/waffle_ecto)
  dependency.  Benefits include:

    * Changeset integration
    * Versioned urls for cache busting (`.../thumb.png?v=63601457477`)

  ### Getting Started: Defining your Upload

  Waffle requires a **definition module** which contains the relevant
  configuration to store and retrieve your files.

  This definition module contains relevant functions to determine:
    * Optional transformations of the uploaded file
    * Where to put your files (the storage directory)
    * What to name your files
    * How to secure your files (private? Or publicly accessible?)
    * Default placeholders

  To start off, generate an attachment definition:

      mix waffle.g avatar

  This should give you a basic file in:

      web/uploaders/avatar.ex

  Check this file for descriptions of configurable options.

  ## Further reading

    * `Waffle.Definition`

    * [full example](https://hexdocs.pm/waffle/full.html)

  """
end
