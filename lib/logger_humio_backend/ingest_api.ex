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

  def take_metadata(metadata, :all) do
    metadata
  end

  def take_metadata(metadata, keys) when is_list(keys) do
    Enum.reduce(keys, [], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error -> acc
      end
    end)
    |> Enum.reverse()
  end

  def format_message(
        %{message: msg, level: level, timestamp: ts, metadata: md},
        format,
        metadata_keys
      ) do
    format
    |> Formatter.format(level, msg, ts, md, metadata_keys)
    |> IO.chardata_to_string()
    |> String.trim()
  end
end
