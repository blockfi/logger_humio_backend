defmodule Logger.Backend.Humio.IngestApi.UnstructuredTest do
  use ExUnit.Case, async: false

  import Mox

  alias Logger.Backend.Humio.{Client, IngestApi}

  require Logger

  @backend {Logger.Backend.Humio, :test}

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
    Logger.add_backend(@backend)
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
      tags: @tags,
      metadata: []
    )

    {:ok, %{ref: ref}}
  end

  defp no_tags_or_fields_config(_context) do
    Logger.add_backend(@backend)
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
      tags: %{},
      metadata: []
    )

    {:ok, %{ref: ref}}
  end

  defp grouped_fields_config(_context) do
    Logger.add_backend(@backend)
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
      max_batch_size: 2,
      fields: %{},
      tags: %{},
      metadata: [:yaks]
    )

    {:ok, %{ref: ref}}
  end

  defp all_metadata_config(_context) do
    Logger.add_backend(@backend)
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
      tags: %{},
      metadata: :all
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

    test "are present in payload when disabled", %{ref: ref} do
      message = "message"
      Logger.info(message)

      assert_receive({^ref, %{body: body, base_url: @base_url, path: @path, headers: @headers}})

      [decoded_body] = Jason.decode!(body)
      refute Map.has_key?(decoded_body, "tags")
      refute Map.has_key?(decoded_body, "fields")
      verify!()
    end
  end

  describe "message grouping" do
    setup [:grouped_fields_config]

    test "happens when fields are equal", %{ref: ref} do
      Logger.metadata(yaks: 2)
      Logger.info("message1")
      Logger.info("message2")

      assert_receive({^ref, %{body: body}})
      decoded_body = Jason.decode!(body)
      assert length(decoded_body) == 1
      event = List.first(decoded_body)
      # messages are grouped
      assert %{"messages" => ["message1", "message2"], "fields" => %{"yaks" => "2"}} == event
      # the only field is yaks
      assert event |> Map.get("fields") |> map_size() == 1
    end

    test "doesn't happen when fields aren't equal", %{ref: ref} do
      Logger.info("message1")
      Logger.metadata(yaks: 2)
      Logger.info("message2")

      assert_receive({^ref, %{body: body}})
      decoded_body = Jason.decode!(body)
      assert length(decoded_body) == 2

      first_event = List.first(decoded_body)
      # first event has first message
      assert %{"messages" => ["message1"]} == first_event
      # no fields
      assert first_event |> Map.get("fields") |> is_nil()

      second_event = List.last(decoded_body)
      # second event has second message, and the yaks field
      assert %{"messages" => ["message2"], "fields" => %{"yaks" => "2"}} == second_event
      # the only field is yaks
      assert second_event |> Map.get("fields") |> map_size() == 1
    end
  end

  describe "all metadata" do
    setup [:all_metadata_config]

    # Test currently just asserts that the built in metadata like domain, file, etc.
    # can be successfully encoded and decoded.
    test "is parsed as string", %{ref: ref} do
      Logger.info("message")
      assert_receive({^ref, %{body: body}})
      _decoded_body = Jason.decode!(body)
    end
  end

  defp config(opts) do
    :ok = Logger.configure_backend(@backend, opts)
  end
end
