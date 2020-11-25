defmodule Logger.Backend.Humio.ConfigHelpers do
  @moduledoc """
  Helper for configuring a Logger Backend for tests that is completely independent from test to test, as we grab the default_config and then merge in the provided opts.
  """

  alias Logger.Backend.Humio

  @backend {Logger.Backend.Humio, :test}

  def configure(opts) do
    Logger.add_backend(@backend)
    opts = Keyword.merge(Humio.default_config(), opts)
    :ok = Logger.configure_backend(@backend, opts)
  end
end
