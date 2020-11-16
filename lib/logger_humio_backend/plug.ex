defmodule Logger.Backend.Humio.Plug do
  @moduledoc """
  Automatically logs metadata information about HTTP requests and responses.
  """
  require Logger
  alias Plug.Conn
  alias Logger.Backend.Humio.Metadata
  @behaviour Plug

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    level = Keyword.get(opts, :level, :info)
    keys = Keyword.get(opts, :metadata, :all)
    message = Keyword.get(opts, :message, "Processed Request")

    start = System.monotonic_time()

    Conn.register_before_send(conn, fn conn ->
      Logger.log(level, message, metadata(conn, start, keys))
      conn
    end)
  end

  def metadata(conn, start, keys) do
    stop = System.monotonic_time()
    diff = System.convert_time_unit(stop - start, :native, :microsecond)

    ([response_time_us: diff] ++ to_metadata(conn))
    |> Metadata.take_metadata(keys)
  end

  defp to_metadata(conn) do
    conn
    |> Map.from_struct()
    |> Enum.into([])
  end
end
