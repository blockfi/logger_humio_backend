defmodule Logger.Backend.Humio.IngestApi.UnstructuredTest do
  use ExUnit.Case, async: false
  require Logger

  alias Logger.Backend.Humio.IngestApi
  alias Logger.Backend.Humio.Client

  @backend {Logger.Backend.Humio, :test}
  Logger.add_backend(@backend)

  @base_url "humio.url"
  @token "token"
  @path "/api/v1/ingest/humio-unstructured"
  @headers [{"Authorization", "Bearer " <> @token}, {"Content-Type", "application/json"}]
  @fields %{
    "service" => "cool_service"
  }
  @tags %{
    "env" => "dev"
  }

  defp smoke_test_config(_context) do
    config(
      ingest_api: IngestApi.Unstructured,
      client: Client.Test,
      host: @base_url,
      format: "$message",
      token: @token,
      max_batch_size: 1,
      fields: @fields,
      tags: @tags
    )

    Client.Test.start_link(self())
    :ok
  end

  defp no_tags_or_fields_config(_context) do
    config(
      ingest_api: IngestApi.Unstructured,
      client: Client.Test,
      host: @base_url,
      format: "$message",
      token: @token,
      max_batch_size: 1,
      fields: %{},
      tags: %{}
    )

    Client.Test.start_link(self())
    :ok
  end

  describe "smoke tests" do
    setup [:smoke_test_config]

    test "Send payload successfully" do
      message = "message"
      Logger.info(message)

      expected_body = Jason.encode!([%{fields: @fields, tags: @tags, messages: [message]}])

      assert_receive(
        {:send, %{body: ^expected_body, base_url: @base_url, path: @path, headers: @headers}}
      )
    end
  end

  describe "no tags or fields" do
    setup [:no_tags_or_fields_config]

    test "neither are present in payload" do
      message = "message"
      Logger.info(message)

      assert_receive({:send, %{body: body, base_url: @base_url, path: @path, headers: @headers}})

      [decoded_body] = Jason.decode!(body)
      refute Map.has_key?(decoded_body, "tags")
      refute Map.has_key?(decoded_body, "fields")
    end
  end

  defp config(opts) do
    :ok = Logger.configure_backend(@backend, opts)
  end
end
