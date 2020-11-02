defmodule Logger.Humio.Backend.IngestApi.StructuredTest do
  use ExUnit.Case, async: false
  require Logger

  alias Logger.Backend.Humio.IngestApi
  alias Logger.Backend.Humio.Client

  @backend {Logger.Backend.Humio, :test}
  Logger.add_backend(@backend)

  @base_url "humio.url"
  @token "token"
  @path "/api/v1/ingest/humio-structured"
  @headers [{"Authorization", "Bearer " <> @token}, {"Content-Type", "application/json"}]

  setup do
    config(
      ingest_api: IngestApi.Structured,
      client: Client.Test,
      host: @base_url,
      format: "$message",
      token: @token,
      max_batch_size: 1,
      metadata: :all
    )

    Client.Test.start_link(self())
    :ok
  end

  test "Send payload successfully" do
    message = "message"
    Logger.info(message)

    assert_receive({:send, %{body: body, base_url: @base_url, path: @path, headers: @headers}})

    assert [
             %{
               "events" => [
                 %{"rawstring" => message}
               ]
             }
           ] = Jason.decode!(body)
  end

  # example: 2003-10-11T22:14:15.003Z
  test "Configure timestamp according to Syslog/ISO 8601" do
    message = "message"
    Logger.info(message)

    assert_receive({:send, %{body: body, base_url: @base_url, path: @path, headers: @headers}})
    [%{"events" => [%{"timestamp" => timestamp}]}] = Jason.decode!(body)
    {:ok, _, _} = DateTime.from_iso8601(timestamp)
  end

  test "Various Metadata is encoded correctly as attributes" do
    Logger.metadata(atom: :gl)
    Logger.metadata(list: ["item1", "item2"])
    Logger.metadata(integer: 13)
    Logger.metadata(float: 12.3)
    Logger.metadata(string: "some string")
    pid = self()
    pid_string = :erlang.pid_to_list(pid)
    Logger.metadata(pid: pid)
    reference = make_ref()
    '#Ref' ++ reference_string = :erlang.ref_to_list(reference)
    Logger.metadata(reference: reference)
    Logger.info("message")

    assert_receive({:send, %{body: body, base_url: @base_url, path: @path, headers: @headers}})

    assert [
             %{
               "events" => [
                 %{
                   "attributes" => %{
                     "integer" => 13,
                     "float" => 12.3,
                     "atom" => "gl",
                     "pid" => ^pid_string,
                     "reference" => ^reference_string,
                     "string" => "some string"
                   }
                 }
               ]
             }
           ] = Jason.decode!(body)
  end

  # Should eventually figure out what to do with them.
  test "Metadata that cannot be encoded is submitted with nil value" do
    Logger.metadata(tuple: {"item1", "item2"})
    Logger.metadata(list: ["item1", "item2"])
    Logger.metadata(some_function: &Enum.map/2)
    Logger.metadata(map: %{bool: true, integer: 14})
    port = Port.open({:spawn, "cat"}, [:binary])
    Logger.metadata(port: port)
    Logger.info("message")

    assert_receive({:send, %{body: body, base_url: @base_url, path: @path, headers: @headers}})

    assert [
             %{
               "events" => [
                 %{
                   "attributes" => %{
                     "tuple" => nil,
                     "list" => nil,
                     "some_function" => nil,
                     "map" => nil,
                     "port" => nil
                   }
                 }
               ]
             }
           ] = Jason.decode!(body)
  end

  defp config(opts) do
    :ok = Logger.configure_backend(@backend, opts)
  end
end
