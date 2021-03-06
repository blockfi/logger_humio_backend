defmodule LoggerHumioBackend.Mixfile do
  use Mix.Project

  @version "0.2.3"

  def project do
    [
      app: :logger_humio_backend,
      version: @version,
      elixir: "~> 1.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :hackney]
    ]
  end

  defp deps do
    [
      {:benchee, "~> 1.0", only: :dev},
      {:credo, "~> 1.5.0-rc.2", only: [:dev, :test], runtime: false},
      {:dialyzex, "~> 1.2.1", only: [:test, :dev]},
      {:excoveralls, "~> 0.13", only: :test},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:iteraptor, "~> 1.12"},
      {:jason, "~> 1.1"},
      {:mix_audit, "~> 0.1", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:plug, "~> 1.2"},
      {:tesla, "~> 1.4.0"}
    ]
  end

  defp description do
    """
    A Logger backend to support the Humio (humio.com) ingest APIs.
    """
  end

  defp package do
    [
      files: ["config", "lib", "mix.exs", "README*", "LICENSE*", ".formatter.exs"],
      maintainers: ["Andreas Kasprzok"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/blockfi/logger_humio_backend"}
    ]
  end

  defp docs() do
    [
      main: "readme",
      name: "Logger Humio Backend",
      source_ref: "v#{@version}",
      canonical: "https://hexdocs.pm/logger_humio_backend",
      source_url: "https://github.com/blockfi/logger_humio_backend",
      extras: [
        "README.md"
      ]
    ]
  end
end
