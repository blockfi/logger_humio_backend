defmodule Logger.Backend.Humio.IngestApi.Structured do
  @moduledoc """
    This Ingest API implementation is for Humio's `Structured` API.
    [Humio Documentation]: https://docs.humio.com/api/ingest/#structured-data
  """
  @behaviour Logger.Backend.Humio.IngestApi
  alias Logger.Backend.Humio.{IngestApi, Metadata}

  @path "/api/v1/ingest/humio-structured"
  @content_type "application/json"

  @impl true
  def transmit(%{
        log_events: log_events,
        config:
          %{
            host: host,
            token: token,
            client: client,
            tags: tags
          } = config
      }) do
    headers = IngestApi.generate_headers(token, @content_type)

    body =
      log_events
      |> Enum.map(&to_event(&1, config))
      |> to_request(tags)
      |> Jason.encode!()

    client.send(%{
      base_url: host,
      path: @path,
      body: body,
      headers: headers
    })
  end

  defp to_request(events, tags) when is_list(events) and is_map(tags) do
    Map.new()
    |> Map.put_new("events", events)
    |> Map.put_new("tags", tags)
    |> List.wrap()
  end

  defp to_event(
         %{metadata: metadata, timestamp: timestamp} = log_event,
         %{metadata: metadata_keys, iso8601_format_fun: iso8601_format_fun, fields: fields} =
           config
       ) do
    Map.new()
    |> rawstring(log_event, config)
    |> attributes(metadata, metadata_keys, fields)
    |> timestamp(timestamp, iso8601_format_fun)
  end

  defp timestamp(map, timestamp, iso8601_format_fun) do
    formatted_timestamp = iso8601_format_fun.(timestamp)
    Map.put_new(map, "timestamp", formatted_timestamp)
  end

  defp rawstring(map, log_event, config) do
    rawstring = IngestApi.format_message(log_event, config)
    Map.put_new(map, "rawstring", rawstring)
  end

  defp attributes(map, metadata, metadata_keys, fields) do
    metadata_map = metadata |> Metadata.metadata_to_map(metadata_keys)
    attributes = Map.merge(fields, metadata_map)
    add_attributes(map, attributes)
  end

  defp add_attributes(map, attributes) when attributes == %{} do
    map
  end

  defp add_attributes(map, attributes) when is_map(attributes) do
    Map.put(map, "attributes", attributes)
  end
end
