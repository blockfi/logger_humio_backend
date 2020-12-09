defmodule Logger.Backend.Humio.Client do
  @moduledoc """
  Defines the HTTP client interface used to send messages to the Humio ingest APIs
  """

  @type body :: String.t()
  @type result :: {:ok, reference()} | {:error, any()}

  @callback send_logs(body(), %Logger.Backend.Humio{}) :: result
end
