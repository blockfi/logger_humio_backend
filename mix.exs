defmodule LoggerHumioBackend.Mixfile do
  use Mix.Project

  def project do
    [
      app: :logger_humio_backend,
      version: "0.0.1",
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
      source_url: "https://github.com/blockfi/logger_humio_backend"
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
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:tesla, "~> 1.3.0"},
      {:jason, "~> 1.1"},
      {:credo, "~> 1.5.0-rc.2", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:timex, "~> 3.5"}
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
      links: %{"GitHub" => "https://github.com/blockfi/logger_humio_backend"},
      organization: "blockfi"
    ]
  end
end
