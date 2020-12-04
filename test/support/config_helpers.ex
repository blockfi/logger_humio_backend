defmodule Logger.Backend.Humio.ConfigHelpers do
  @moduledoc """
  Helper for configuring a Logger Backend for tests that is completely independent from test to test, as we grab the default_config and then merge in the provided opts.
  """

  alias Logger.Backend.Humio
  alias Logger.Backend.Humio.Client

  # Sensible test defaults
  @default_overrides [
    host: "host",
    token: "token",
    format: "$message",
    client: Client.Mock,
    max_batch_size: 1,
    flush_interval_ms: 500,
    fields: %{
      "example_field" => "example_value"
    },
    tags: %{
      "example_tag" => "example_value"
    }
  ]

  def configure(opts) do
    Logger.add_backend(Humio, flush: true)

    opts =
      Humio.default_config()
      |> Keyword.merge(@default_overrides)
      |> Keyword.merge(opts)

    :ok = Logger.configure_backend(Humio, opts)
  end
end
