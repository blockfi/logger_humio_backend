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
      metadata = metadata(conn, start, keys)
      message = format_message(metadata)
      Logger.log(level, message, metadata(conn, start, keys))
      conn
    end)
  end

  defp format_message(_metadata) do
    "great success"
  end

  defp metadata(conn, start, keys) do
    stop = System.monotonic_time()
    diff = System.convert_time_unit(stop - start, :native, :microsecond)

    [response_time_us: diff] ++ [conn: to_metadata(conn, keys)]
  end

  defp to_metadata(conn, keys) do
    conn
    |> Map.from_struct()
    |> Enum.into([])
    |> Metadata.take_metadata(keys)
  end
end
