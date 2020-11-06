defmodule Logger.Humio.Backend.IngestApi.StructuredTest do
  use ExUnit.Case, async: false

  import Mox

  alias Logger.Backend.Humio.{Client, IngestApi}

  require Logger

  @backend {Logger.Backend.Humio, :test}
  Logger.add_backend(@backend)

  @base_url "humio.url"
  @token "token"
  @path "/api/v1/ingest/humio-structured"
  @headers [{"Authorization", "Bearer " <> @token}, {"Content-Type", "application/json"}]

  @happy_result {:ok, %{status: 200, body: "somebody"}}

  setup do
    set_mox_global()
    parent = self()
    ref = make_ref()

    expect(Client.Mock, :send, fn request ->
      send(parent, {ref, request})
      @happy_result
    end)

    config(
      ingest_api: IngestApi.Structured,
      client: Client.Mock,
      host: @base_url,
      format: "$message",
      token: @token,
      max_batch_size: 1,
      metadata: :all
    )

    {:ok, %{ref: ref}}
  end

  test "Send payload successfully", %{ref: ref} do
    message = "message"
    Logger.info(message)

    assert_receive({^ref, %{body: body, base_url: @base_url, path: @path, headers: @headers}})

    assert [
             %{
               "events" => [
                 %{"rawstring" => message}
               ]
             }
           ] = Jason.decode!(body)

    verify!()
  end

  # example: 2003-10-11T22:14:15.003Z
  test "Configure timestamp according to Syslog/ISO 8601", %{ref: ref} do
    message = "message"
    Logger.info(message)

    assert_receive({^ref, %{body: body, base_url: @base_url, path: @path, headers: @headers}})
    [%{"events" => [%{"timestamp" => timestamp}]}] = Jason.decode!(body)
    {:ok, _, _} = DateTime.from_iso8601(timestamp)
    verify!()
  end

  test "Various Metadata is encoded correctly as attributes", %{ref: ref} do
    Logger.metadata(atom: :gl)
    Logger.metadata(list: ["item1", "item2"])
    Logger.metadata(integer: 13)
    Logger.metadata(float: 12.3)
    Logger.metadata(string: "some string")
    pid = self()
    pid_string = :erlang.pid_to_list(pid) |> to_string()
    Logger.metadata(pid: pid)
    reference = make_ref()
    reference_string = :erlang.ref_to_list(reference) |> to_string()
    Logger.metadata(reference: reference)
    Logger.info("message")

    assert_receive({^ref, %{body: body, base_url: @base_url, path: @path, headers: @headers}})

    assert [
             %{
               "events" => [
                 %{
                   "attributes" => %{
                     "integer" => "13",
                     "float" => "12.3",
                     "atom" => "gl",
                     "pid" => ^pid_string,
                     "reference" => ^reference_string,
                     "string" => "some string"
                   }
                 }
               ]
             }
           ] = Jason.decode!(body)

    verify!()
  end

  # Should eventually figure out what to do with them.
  test "Metadata that cannot be encoded is submitted with nil value", %{ref: ref} do
    Logger.metadata(tuple: {"item1", "item2"})
    Logger.metadata(some_function: &Enum.map/2)
    port = Port.open({:spawn, "cat"}, [:binary])
    Logger.metadata(port: port)
    Logger.info("message")

    assert_receive({^ref, %{body: body, base_url: @base_url, path: @path, headers: @headers}})

    assert [
             %{
               "events" => [
                 %{
                   "attributes" => %{
                     "tuple" => "nil",
                     "some_function" => "nil",
                     "port" => "nil"
                   }
                 }
               ]
             }
           ] = Jason.decode!(body)

    verify!()
  end

  defp config(opts) do
    :ok = Logger.configure_backend(@backend, opts)
  end
end
