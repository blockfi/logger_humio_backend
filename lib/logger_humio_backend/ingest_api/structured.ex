defmodule Logger.Backend.Humio.IngestApi.Structured do
  @moduledoc """
    This Ingest API implementation is for Humio's `Structured` API.
    [Humio Documentation]: https://docs.humio.com/api/ingest/#structured-data
  """
  @behaviour Logger.Backend.Humio.IngestApi
  alias Logger.Backend.Humio.{Formatter, IngestApi, Metadata}

  @path "/api/v1/ingest/humio-structured"
  @content_type "application/json"
  @omitted_metadata [
    # timestamp is already included in Structured's "timestamp" field
    :time
  ]

  @impl true
  def transmit(%{
        log_events: log_events,
        config: %{
          host: host,
          token: token,
          client: client,
          format: format,
          metadata: metadata_keys
        }
      }) do
    headers = IngestApi.generate_headers(token, @content_type)
    events = to_humio_events(log_events, format, metadata_keys)
    {:ok, body} = encode_events(events)

    client.send(%{
      base_url: host,
      path: @path,
      body: body,
      headers: headers
    })
  end

  defp encode_events(events) do
    Jason.encode([
      %{
        "events" => events
      }
    ])
  end

  defp to_humio_events(log_events, format, metadata_keys) do
    log_events |> Enum.map(&to_humio_event(&1, format, metadata_keys))
  end

  defp to_humio_event(
         %{timestamp: timestamp, metadata: metadata} = log_event,
         format,
         metadata_keys
       ) do
    # omit metadata for raw string, we add metadata as attributes instead
    raw_string = IngestApi.format_message(log_event, format, [])
    attributes = metadata |> Formatter.take_metadata(metadata_keys) |> metadata_to_map()

    %{
      "rawstring" => raw_string,
      "timestamp" => Keyword.fetch!(metadata, :iso8601_format_fun).(timestamp),
      "attributes" => attributes
    }
  end

  defp metadata_to_map(metadata) do
    metadata
    |> Keyword.drop(@omitted_metadata)
    |> Metadata.metadata()
  end
end
