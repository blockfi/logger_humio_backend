defmodule Logger.Backend.Humio.IngestApi.Unstructured do
  @moduledoc """
  This Ingest API implementation is for Humio's `Unstructured` API.
  [Humio Documentation]: https://docs.humio.com/api/ingest/#parser
  """
  @behaviour Logger.Backend.Humio.IngestApi
  alias Logger.Backend.Humio.IngestApi

  @path "/api/v1/ingest/humio-unstructured"
  @content_type "application/json"

  @impl true
  def transmit(%{
        log_events: log_events,
        config: %{
          host: host,
          token: token,
          client: client,
          format: format,
          metadata: metadata_keys,
          fields: fields,
          tags: tags
        }
      }) do
    {:ok, body} =
      log_events
      |> format_messages(format, metadata_keys)
      |> encode(fields, tags)

    headers = IngestApi.generate_headers(token, @content_type)

    client.send(%{
      base_url: host,
      path: @path,
      body: body,
      headers: headers
    })
  end

  defp encode(entries, fields, tags) do
    Map.new()
    |> add_entries(entries)
    |> add_fields(fields)
    |> add_tags(tags)
    |> to_list()
    |> Jason.encode()
  end

  defp to_list(map) do
    [map]
  end

  defp add_entries(map, entries) do
    Map.put_new(map, "messages", entries)
  end

  defp add_fields(map, fields) when fields == %{} do
    map
  end

  defp add_fields(map, fields) do
    Map.put_new(map, "fields", fields)
  end

  defp add_tags(map, tags) when tags == %{} do
    map
  end

  defp add_tags(map, tags) do
    Map.put_new(map, "tags", tags)
  end

  defp format_messages(log_events, format, metadata_keys) do
    log_events
    |> Enum.map(&IngestApi.format_message(&1, format, metadata_keys))
  end
end
