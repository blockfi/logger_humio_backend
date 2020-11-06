defmodule Logger.Backend.Humio.IngestApi do
  @moduledoc """
  Defines the contract for implementing a Humio Ingest API,
  such as humio-structured, humio-unstructured, HEC, etc.
  """
  alias Logger.Backend.Humio
  alias Logger.Backend.Humio.{Client, Formatter}

  @type result :: {:ok, Client.response()} | {:error, any}

  @callback transmit(Humio.state()) :: result

  def generate_headers(token, content_type) do
    [
      {"Authorization", "Bearer " <> token},
      {"Content-Type", content_type}
    ]
  end

  def format_message(
        %{message: msg, level: level, timestamp: ts, metadata: md},
        %{format: format, iso8601_format_fun: iso8601_format_fun}
      ) do
    format
    |> Formatter.format(level, msg, ts, md, iso8601_format_fun)
    |> IO.chardata_to_string()
    |> String.trim()
  end
end
