defmodule Logger.Humio.Backend.IngestApi.StructuredTest do
  use ExUnit.Case, async: false

  import Mox

  alias Logger.Backend.Humio.{Client, ConfigHelpers, TestStruct}

  require Logger

  @base_url "humio.url"
  @token "token"
  @path "/api/v1/ingest/humio-structured"
  @headers [{"Authorization", "Bearer " <> @token}, {"Content-Type", "application/json"}]
  @fields %{
    "service" => "cool_service"
  }
  @tags %{
    "env" => "dev"
  }

  @happy_result {:ok, %{status: 200, body: "somebody"}}

  defp smoke_test_config(_context) do
    set_mox_global()
    parent = self()
    ref = make_ref()

    expect(Client.Mock, :send, fn request ->
      send(parent, {ref, request})
      @happy_result
    end)

    ConfigHelpers.configure(
      client: Client.Mock,
      host: @base_url,
      format: "$message",
      token: @token,
      max_batch_size: 1,
      metadata: :all,
      fields: @fields,
      tags: @tags
    )

    {:ok, %{ref: ref}}
  end

  describe "smokes tests: " do
    setup [:smoke_test_config, :verify_on_exit!]

    test "Send payload successfully", %{ref: ref} do
      message = "message"
      Logger.info(message)

      assert_receive({^ref, %{body: body, base_url: @base_url, path: @path, headers: @headers}})

      decoded_body = Jason.decode!(body)

      assert [
               %{
                 "tags" => tags,
                 "events" => [
                   %{
                     "rawstring" => ^message,
                     "timestamp" => timestamp,
                     "attributes" => attributes
                   }
                 ]
               }
             ] = decoded_body

      assert {:ok, _, _} = DateTime.from_iso8601(timestamp)
      assert @tags == tags

      assert %{
               "domain" => ["elixir"],
               "file" => file,
               "function" => "test smokes tests:  Send payload successfully/1",
               "mfa" =>
                 "Logger.Humio.Backend.IngestApi.StructuredTest.\"test smokes tests:  Send payload successfully\"/1",
               "module" => "Logger.Humio.Backend.IngestApi.StructuredTest",
               "service" => "cool_service"
             } = attributes

      assert file =~
               "logger_humio_backend/test/logger_humio_backend/ingest_api/structured_test.exs"
    end

    test "Various Metadata is encoded correctly as attributes", %{ref: ref} do
      Logger.metadata(atom: :gl)
      Logger.metadata(list: ["item1", "item2"])
      Logger.metadata(integer: 13)
      Logger.metadata(float: 12.3)
      Logger.metadata(string: "some string")
      Logger.metadata(map: %{"map_key" => "map_value"})
      Logger.metadata(list: ["list_entry_1", "list_entry_2"])
      Logger.metadata(struct: %TestStruct{})
      pid = self()
      pid_string = :erlang.pid_to_list(pid) |> to_string()
      Logger.metadata(pid: pid)
      reference = make_ref()
      reference_string = :erlang.ref_to_list(reference) |> to_string()
      Logger.metadata(reference: reference)
      port = Port.open({:spawn, "cat"}, [:binary])
      port_string = port |> :erlang.port_to_list() |> to_string()
      Logger.metadata(port: port)
      function = &Enum.map/2
      function_string = function |> :erlang.fun_to_list() |> to_string()
      Logger.metadata(function: function)
      Logger.metadata(tuple: {:ok, "value"})
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
                       "string" => "some string",
                       "map" => %{"map_key" => "map_value"},
                       "list" => ["list_entry_1", "list_entry_2"],
                       "port" => ^port_string,
                       "function" => ^function_string,
                       "struct" => %{"name" => "John", "age" => "27"},
                       "tuple" => ["ok", "value"]
                     }
                   }
                 ]
               }
             ] = Jason.decode!(body)
    end
  end
end
