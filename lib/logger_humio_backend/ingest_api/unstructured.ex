defmodule Logger.Backend.Humio.IngestApi.Unstructured do
  @moduledoc """
  This Ingest API implementation is for Humio's `Unstructured` API.
  [Humio Documentation]: https://docs.humio.com/api/ingest/#parser
  """
  @behaviour Logger.Backend.Humio.IngestApi

  alias Logger.Backend.Humio.{IngestApi, Metadata}

  @path "/api/v1/ingest/humio-unstructured"
  @content_type "application/json"

  @impl true
  def transmit(%{
        log_events: log_events,
        config:
          %{
            host: host,
            token: token,
            client: client,
            fields: fields,
            tags: tags
          } = config
      }) do
    {:ok, body} =
      log_events
      |> Enum.map(&format_message(&1, config))
      |> Enum.reduce(Map.new(), &group_by_metadata/2)
      |> Enum.map(&encode(&1, fields, tags))
      |> Jason.encode()

    headers = IngestApi.generate_headers(token, @content_type)

    client.send(%{
      base_url: host,
      path: @path,
      body: body,
      headers: headers
    })
  end

  defp format_message(%{metadata: metadata} = log_event, %{metadata: metadata_keys} = config) do
    message = IngestApi.format_message(log_event, config)
    fields = metadata |> Metadata.metadata_to_map(metadata_keys)

    {fields, message}
  end

  defp group_by_metadata({fields, message}, map) do
    Map.update(map, fields, [message], fn list -> [message | list] end)
  end

  defp encode({metadata, messages}, fields, tags) do
    # metadata can override the value of config fields
    merged_fields = Map.merge(fields, metadata)

    Map.new()
    |> add_messages(messages)
    |> add_fields(merged_fields)
    |> add_tags(tags)
  end

  defp add_messages(map, messages) do
    Map.put_new(map, "messages", Enum.reverse(messages))
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
end
