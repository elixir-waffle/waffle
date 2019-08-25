defmodule Waffle.Mixfile do
  use Mix.Project

  @version "0.0.1"

  def project do
    [app: :waffle,
     version: @version,
     elixir: "~> 1.4",
     deps: deps(),

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

  def application do
    [
      applications: [
        :logger,
        :hackney,
      ] ++ applications(Mix.env)
    ]
  end

  def applications(:test), do: [:ex_aws, :ex_aws_s3, :poison]
  def applications(_), do: []

  defp deps do
    [
      {:hackney, "~> 1.0"},

      # If using Amazon S3
      {:ex_aws, "~> 2.0", optional: true},
      {:ex_aws_s3, "~> 2.0", optional: true},
      {:poison, "~> 2.2 or ~> 3.1", optional: true},
      {:sweet_xml, "~> 0.6", optional: true},

      # Test
      {:mock, "~> 0.1", only: :test},

      # Dev
      {:ex_doc, "~> 0.14", only: :dev}
    ]
  end
end
