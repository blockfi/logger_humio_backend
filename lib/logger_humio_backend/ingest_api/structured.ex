defmodule Logger.Backend.Humio.IngestApi.Structured do
  @moduledoc """
    This Ingest API implementation is for Humio's `Structured` API.
    [Humio Documentation]: https://docs.humio.com/api/ingest/#structured-data
  """
  @behaviour Logger.Backend.Humio.IngestApi
  alias Logger.Backend.Humio.{IngestApi, Metadata}

  @path "/api/v1/ingest/humio-structured"
  @content_type "application/json"
  @omitted_metadata [
    # timestamp is already included in Structured's "timestamp" field
    :time
  ]

  @impl true
  def transmit(%{config: %{host: host, token: token, client: client}} = state) do
    headers = IngestApi.generate_headers(token, @content_type)
    events = to_humio_events(state)
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

  defp to_humio_events(%{log_events: log_events, config: config}) do
    log_events |> Enum.map(&to_humio_event(&1, config))
  end

  defp to_humio_event(
         %{timestamp: timestamp, metadata: metadata} = log_event,
         %{metadata: metadata_keys, iso8601_format_fun: iso8601_format_fun} = config
       ) do
    raw_string = IngestApi.format_message(log_event, config)

    attributes =
      metadata
      |> Keyword.drop(@omitted_metadata)
      |> Metadata.metadata_to_map(metadata_keys)

    %{
      "rawstring" => raw_string,
      "timestamp" => iso8601_format_fun.(timestamp),
      "attributes" => attributes
    }
  end
end
