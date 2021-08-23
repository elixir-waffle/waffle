defmodule Waffle.Mixfile do
  use Mix.Project

  @version "1.1.5"

  def project do
    [
      app: :waffle,
      version: @version,
      elixir: "~> 1.4",
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
      main: "Waffle",
      extras: [
        "documentation/examples/local.md",
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

      # Test
      {:mock, "~> 0.3", only: :test},

      # Dev
      {:ex_doc, "~> 0.21", only: :dev},

      # Dev, Test
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
