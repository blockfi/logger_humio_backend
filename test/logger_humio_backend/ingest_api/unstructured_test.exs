defmodule Logger.Backend.Humio.IngestApi.UnstructuredTest do
  use ExUnit.Case, async: false

  import Mox

  alias Logger.Backend.Humio.{Client, IngestApi}

  require Logger

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

  @happy_result {:ok, %{status: 200, body: "somebody"}}

  defp smoke_test_config(_context) do
    set_mox_global()
    parent = self()
    ref = make_ref()

    expect(Client.Mock, :send, fn request ->
      send(parent, {ref, request})
      @happy_result
    end)

    config(
      ingest_api: IngestApi.Unstructured,
      client: Client.Mock,
      host: @base_url,
      format: "$message",
      token: @token,
      max_batch_size: 1,
      fields: @fields,
      tags: @tags
    )

    {:ok, %{ref: ref}}
  end

  defp no_tags_or_fields_config(_context) do
    set_mox_global()
    parent = self()
    ref = make_ref()

    expect(Client.Mock, :send, fn request ->
      send(parent, {ref, request})
      @happy_result
    end)

    config(
      ingest_api: IngestApi.Unstructured,
      client: Client.Mock,
      host: @base_url,
      format: "$message",
      token: @token,
      max_batch_size: 1,
      fields: %{},
      tags: %{}
    )

    {:ok, %{ref: ref}}
  end

  describe "smoke tests" do
    setup [:smoke_test_config]

    test "Send payload successfully", %{ref: ref} do
      message = "message"
      Logger.info(message)

      expected_body = Jason.encode!([%{fields: @fields, tags: @tags, messages: [message]}])

      assert_receive(
        {^ref, %{body: ^expected_body, base_url: @base_url, path: @path, headers: @headers}}
      )

      verify!()
    end
  end

  describe "no tags or fields" do
    setup [:no_tags_or_fields_config]

    test "neither are present in payload", %{ref: ref} do
      message = "message"
      Logger.info(message)

      assert_receive({^ref, %{body: body, base_url: @base_url, path: @path, headers: @headers}})

      [decoded_body] = Jason.decode!(body)
      refute Map.has_key?(decoded_body, "tags")
      refute Map.has_key?(decoded_body, "fields")
      verify!()
    end
  end

  defp config(opts) do
    :ok = Logger.configure_backend(@backend, opts)
  end
end
