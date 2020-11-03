defmodule Logger.Backend.Humio.IngestApi.Structured do
  @moduledoc """
    This Ingest API implementation is for Humio's `Structured` API.
    [Humio Documentation]: https://docs.humio.com/api/ingest/#structured-data
  """
  @behaviour Logger.Backend.Humio.IngestApi
  alias Logger.Backend.Humio.{Formatter, IngestApi}

  require IEx

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
    |> Enum.map(fn {k, v} -> {k, metadata(k, v)} end)
    |> Enum.into(%{})
  end

  defp metadata(:time, _), do: nil
  defp metadata(:gl, _), do: nil
  defp metadata(:report_cb, _), do: nil

  defp metadata(_, nil), do: nil
  defp metadata(_, string) when is_binary(string), do: string
  defp metadata(_, integer) when is_integer(integer), do: integer
  defp metadata(_, float) when is_float(float), do: float
  defp metadata(_, pid) when is_pid(pid), do: :erlang.pid_to_list(pid)

  defp metadata(_, atom) when is_atom(atom) do
    case Atom.to_string(atom) do
      "Elixir." <> rest -> rest
      "nil" -> ""
      binary -> binary
    end
  end

  defp metadata(_, ref) when is_reference(ref) do
    '#Ref' ++ rest = :erlang.ref_to_list(ref)
    rest
  end

  defp metadata(:file, file) when is_list(file), do: file

  defp metadata(:domain, [head | tail]) when is_atom(head) do
    Enum.map_intersperse([head | tail], ?., &Atom.to_string/1)
  end

  defp metadata(:mfa, {mod, fun, arity})
       when is_atom(mod) and is_atom(fun) and is_integer(arity) do
    Exception.format_mfa(mod, fun, arity)
  end

  defp metadata(:initial_call, {mod, fun, arity})
       when is_atom(mod) and is_atom(fun) and is_integer(arity) do
    Exception.format_mfa(mod, fun, arity)
  end

  defp metadata(_, list) when is_list(list), do: nil

  defp metadata(_, other) do
    case String.Chars.impl_for(other) do
      nil -> nil
      impl -> impl.to_string(other)
    end
  end
end
