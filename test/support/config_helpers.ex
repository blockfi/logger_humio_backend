defmodule Logger.Backend.Humio.ConfigHelpers do
  @moduledoc """
  Helper for configuring a Logger Backend for tests that is completely independent from test to test, as we grab the default_config and then merge in the provided opts.
  """

  alias Logger.Backend.Humio

  def configure(opts) do
    Logger.add_backend(Logger.Backend.Humio)
    opts = Keyword.merge(Humio.default_config(), opts)
    :ok = Logger.configure_backend(Logger.Backend.Humio, opts)
  end
end
