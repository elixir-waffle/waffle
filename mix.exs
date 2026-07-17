defmodule Waffle.Mixfile do
  use Mix.Project

  @version "1.1.10"

  def project do
    [
      app: :waffle,
      version: @version,
      elixir: "~> 1.4",
      source_url: "https://github.com/elixir-waffle/waffle",
      deps: deps(),
      docs: docs(),

      # Hex
      description: description(),
      package: package()
    ]
  end

  defp description do
    """
    Flexible file upload and attachment library for Elixir.
    """
  end

  defp package do
    [
      maintainers: ["Boris Kuznetsov"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/elixir-waffle/waffle"},
      files: ~w(mix.exs README.md CHANGELOG.md lib)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "documentation/examples/local.md",
        "documentation/examples/s3.md",
        "documentation/livebooks/custom_transformation.livemd"
      ]
    ]
  end

  def application do
    [
      extra_applications: [
        :logger,
        # Used by Mix.generator.embed_template/2
        :eex
      ]
    ]
  end

  defp deps do
    [
      {:hackney, "~> 1.9"},
      {:req, "~> 0.5", optional: true},

      # If using Amazon S3
      {:ex_aws, "~> 2.1", optional: true},
      {:ex_aws_s3, "~> 2.1", optional: true},
      {:sweet_xml, "~> 0.6", optional: true},

      # Test
      {:mock, "~> 0.3", only: :test},
      {:plug, "~> 1.0", only: :test},

      # To be removed once https://github.com/jjh42/mock/pull/155/changes is merged.
      # Needed because meck 0.9.2, required by mock above, won't compile on OTP 29
      {:meck, "~> 1.0", only: :test, override: true},

      # Dev
      {:ex_doc, "~> 0.21", only: :dev},

      # Dev, Test
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
