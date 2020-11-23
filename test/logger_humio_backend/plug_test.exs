defmodule Logger.Backend.Humio.PlugTest do
  use ExUnit.Case, async: false
  use Plug.Test

  import Mox

  alias Logger.Backend.Humio.{Client, IngestApi, Plug}

  require Logger

  @backend {Logger.Backend.Humio, :test}
  Logger.add_backend(@backend)

  @happy_result {:ok, %{status: 200, body: "somebody"}}

  defp smoke_test_config(_context) do
    set_mox_global()
    parent = self()
    ref = make_ref()

    expect(Client.Mock, :send, fn state ->
      send(parent, {ref, state})
      @happy_result
    end)

    config(
      client: Client.Mock,
      ingest_api: IngestApi.Structured,
      format: "[$level] $message\n",
      max_batch_size: 1,
      metadata: [:conn]
    )

    {:ok, %{ref: ref}}
  end

  describe "Plug" do
    setup [:smoke_test_config]

    test " prints lots of metadata successfully", %{ref: ref} do
      message = "great success"

      conn(:get, "/")
      |> call(metadata: :all)
      |> send_resp(200, "response_body")

      assert_receive {^ref, %{body: body}}

      decoded_body = Jason.decode!(body)

      assert [
               %{
                 "events" => [
                   %{
                     "attributes" => %{
                       "conn" => %{
                         "response_time_us" => _,
                         "adapter" => [
                           "Plug.Adapters.Test.Conn",
                           %{
                             "chunks" => nil,
                             "http_protocol" => "HTTP/1.1",
                             "method" => "GET",
                             "owner" => _,
                             "params" => nil,
                             "peer_data" => %{
                               "address" => ["127", "0", "0", "1"],
                               "port" => "111317",
                               "ssl_cert" => nil
                             },
                             "ref" => _,
                             "req_body" => ""
                           }
                         ],
                         "assigns" => %{},
                         "before_send" => [_],
                         "body_params" => %{"aspect" => "body_params"},
                         "cookies" => %{"aspect" => "cookies"},
                         "halted" => "false",
                         "host" => "www.example.com",
                         "method" => "GET",
                         "owner" => _,
                         "params" => %{"aspect" => "params"},
                         "path_info" => [],
                         "path_params" => %{},
                         "port" => "80",
                         "private" => %{},
                         "query_params" => %{"aspect" => "query_params"},
                         "query_string" => "",
                         "remote_ip" => "127.0.0.1",
                         "req_cookies" => %{"aspect" => "cookies"},
                         "req_headers" => [],
                         "request_path" => "/",
                         "resp_body" => "response_body",
                         "resp_cookies" => %{},
                         "resp_headers" => %{
                           "cache-control" => "max-age=0, private, must-revalidate"
                         },
                         "scheme" => "http",
                         "script_name" => [],
                         "secret_key_base" => nil,
                         "state" => "set",
                         "status" => "200"
                       }
                     },
                     "rawstring" => rawstring,
                     "timestamp" => _
                   }
                 ]
               }
             ] = decoded_body

      assert rawstring =~ "[info] GET / Sent 200 in"
    end

    test " prints a little bit of metadata, as a treat", %{ref: ref} do
      conn(:get, "/")
      |> call([])
      |> send_resp(200, "response_body")

      assert_receive {^ref, %{body: body}}

      decoded_body = Jason.decode!(body)

      assert [
               %{
                 "events" => [
                   %{
                     "attributes" => %{
                       "conn" => %{
                         "method" => "GET",
                         "request_path" => "/",
                         "remote_ip" => "127.0.0.1",
                         "status" => "200",
                         "response_time_us" => _
                       }
                     },
                     "rawstring" => rawstring,
                     "timestamp" => _
                   }
                 ]
               }
             ] = decoded_body

      assert rawstring =~ "[info] GET / Sent 200 in"
    end
  end

  defp call(conn, opts) do
    Plug.call(conn, Plug.init(opts))
  end

  defp config(opts) do
    :ok = Logger.configure_backend(@backend, opts)
  end
end
