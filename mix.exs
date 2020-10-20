defmodule Waffle.Mixfile do
  use Mix.Project

  @version "1.1.3"

  def project do
    [app: :waffle,
     version: @version,
     elixir: "~> 1.4",
     deps: deps(),
     docs: docs(),

    # Hex
     description: description(),
     package: package()]
  end

  defp description do
    """
    Flexible file upload and attachment library for Elixir.
    """
  end

  defp package do
    [maintainers: ["Boris Kuznetsov"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/elixir-waffle/waffle"},
     files: ~w(mix.exs README.md CHANGELOG.md lib)]
  end

  defp docs do
    [
      main: "Waffle",
      extras: [
        "documentation/examples/local.md",
        "documentation/examples/s3.md"
      ]
    ]
  end

  def application do
    [
      applications: [
        :logger,
        :hackney,
      ] ++ applications(Mix.env)
    ]
  end

  def applications(:test), do: [:ex_aws, :ex_aws_s3]
  def applications(_), do: []

  defp deps do
    [
      {:hackney, "~> 1.9"},

      # file validation
      {:mime, "~> 1.2"},

      # If using Amazon S3
      {:ex_aws, "~> 2.1.2", optional: true},
      {:ex_aws_s3, "~> 2.0", optional: true},
      {:sweet_xml, "~> 0.6", optional: true},

      # Test
      {:mock, "~> 0.3", only: :test},

      # Dev
      {:ex_doc, "~> 0.21", only: :dev},

      # Dev, Test
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
