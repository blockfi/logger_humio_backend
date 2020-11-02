defmodule Logger.Backend.Humio.Client do
  @moduledoc """
  Defines the HTTP client interface used to send messages to the Humio ingest APIs
  """

  @type params :: %{
          base_url: String.t(),
          path: String.t(),
          body: String.t(),
          headers: list(tuple)
        }
  @type response :: %{
          status: 100..599,
          body: String.t()
        }
  @type result :: {:ok, response} | {:error, any}

  @callback send(params) :: result
end
