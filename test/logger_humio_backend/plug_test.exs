defmodule Logger.Backend.Humio.PlugTest do
  use ExUnit.Case, async: false
  use Plug.Test

  import Mox

  alias Logger.Backend.Humio.{IngestApi, Plug}

  require Logger

  @backend {Logger.Backend.Humio, :test}
  Logger.add_backend(@backend)

  @happy_result {:ok, %{status: 200, body: "somebody"}}

  defp plug_test_config(_context) do
    set_mox_global()
    parent = self()
    ref = make_ref()

    expect(IngestApi.Mock, :transmit, fn state ->
      send(parent, {ref, state})
      @happy_result
    end)

    config(
      ingest_api: IngestApi.Mock,
      host: "humio.url",
      format: "[$level] $message\n",
      token: "humio-token",
      max_batch_size: 1
    )

    {:ok, %{ref: ref}}
  end

  describe "Plug" do
    setup [:plug_test_config]

    test " prints lots of metadata successfully", %{ref: ref} do
      message = "great success"

      conn(:get, "/")
      |> call(log_level: :info, message: message)
      |> send_resp(200, "response_body")

      assert_receive {^ref, events}

      assert %{
               log_events: [
                 %{message: message}
               ]
             } = events
    end
  end

  defp call(conn, opts) do
    Plug.call(conn, Plug.init(opts))
  end

  defp config(opts) do
    :ok = Logger.configure_backend(@backend, opts)
  end
end
