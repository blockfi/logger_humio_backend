defmodule Logger.Backend.Humio.Plug do
  @moduledoc """
  Automatically logs metadata information about HTTP requests and responses.
  """
  require Logger
  alias Logger.Backend.Humio.Metadata
  alias Plug.Conn
  @behaviour Plug

  @default_level :info
  @default_metadata [:method, :remote_ip, :request_path, :status]

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    level = Keyword.get(opts, :level, @default_level)
    keys = Keyword.get(opts, :metadata, @default_metadata)

    start = System.monotonic_time()

    Conn.register_before_send(conn, fn conn ->
      metadata = to_metadata(conn, start)
      message = format_message(metadata)
      Logger.log(level, message, conn: Metadata.take_metadata(metadata, keys))
      conn
    end)
  end

  defp format_message(metadata) do
    response_time = Keyword.get(metadata, :response_time_us)
    status = Keyword.get(metadata, :status)
    request_path = Keyword.get(metadata, :request_path)
    method = Keyword.get(metadata, :method)

    [
      method,
      " ",
      request_path,
      " Sent ",
      Integer.to_string(status),
      " in ",
      Integer.to_string(response_time),
      "us"
    ]
  end

  defp to_metadata(conn, start) do
    stop = System.monotonic_time()
    diff = System.convert_time_unit(stop - start, :native, :microsecond)

    conn_metadata =
      conn
      |> Map.from_struct()
      |> Enum.into([])
      |> format_metadata()

    [response_time_us: diff] ++ conn_metadata
  end

  # Puts certain fields into a more legible format. Separate from Metadata.format_metadata since certain fields we only see here
  defp format_metadata(metadata) do
    Iteraptor.map(metadata, fn {k, v} -> {k, metadata(k, v)} end)
  end

  defp metadata([:remote_ip], ip) do
    ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp metadata(_, other) do
    other
  end
end
