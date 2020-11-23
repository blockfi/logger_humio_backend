defmodule Logger.Backend.Humio.Plug do
  @moduledoc """
  Automatically logs metadata information about HTTP requests and responses.
  """
  require Logger
  alias Logger.Backend.Humio.Metadata
  alias Plug.Conn
  @behaviour Plug

  @default_level :info
  @default_metadata [:method, :remote_ip, :request_path, :status, :response_time_us]

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    level = Keyword.get(opts, :log, @default_level)
    keys = Keyword.get(opts, :metadata, @default_metadata)

    start = System.monotonic_time()

    Conn.register_before_send(conn, fn conn ->
      metadata = to_metadata(conn, start, keys)
      message = format_message(conn)
      Logger.log(level, message, conn: metadata)
      conn
    end)
  end

  defp format_message(conn) do
    [
      conn.method,
      " ",
      conn.request_path,
      " Sent ",
      Integer.to_string(conn.status),
    ]
  end

  defp to_metadata(conn, start, keys) do
    stop = System.monotonic_time()
    diff = System.convert_time_unit(stop - start, :native, :microsecond)

    conn_metadata =
      conn
      |> Map.from_struct()
      |> Enum.into([])
      |> Metadata.take_metadata(keys)
      |> format_metadata()

    [response_time_us: diff] ++ conn_metadata
  end

  # Puts certain fields into a more legible format.
  # Separate from Metadata.format_metadata since certain fields we only see here
  defp format_metadata(metadata) do
    Iteraptor.map(metadata, fn {k, v} ->
      {k, metadata(k, v)} end)
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
