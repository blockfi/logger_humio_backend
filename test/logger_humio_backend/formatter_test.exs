defmodule Logger.Backend.Humio.FormatterTest do
  use ExUnit.Case, async: false
  require Logger

  alias Logger.Backend.Humio.{Client, Formatter, IngestApi}

  @backend {Logger.Backend.Humio, :test}
  Logger.add_backend(@backend)

  @base_url "humio.url"
  @token "token"

  setup do
    config(
      ingest_api: IngestApi.Unstructured,
      client: Client.Test,
      host: @base_url,
      token: @token,
      formatter: Formatter,
      # use default format
      format: nil,
      max_batch_size: 1,
      metadata: []
    )

    Client.Test.start_link(self())
    :ok
  end

  # This needs a regex test once the formatting settles
  test "Format message" do
    message = "message"
    Logger.info(message)

    assert_receive({:send, %{body: body}}, 500)
    [%{"messages" => [decoded_message]}] = Jason.decode!(body)
    # no metadata after message, trimmed space
    assert String.ends_with?(decoded_message, message)
    assert decoded_message =~ "[info]"
    assert decoded_message =~ self() |> :erlang.pid_to_list() |> (&"[#{&1}]").()

    # valid iso8601 timestamp at beginning
    assert {:ok, _, _} =
             decoded_message |> String.split() |> Enum.at(0) |> DateTime.from_iso8601()
  end

  test "take metadata except" do
    metadata = [a: 1, b: 2]
    keys = [:b]
    assert [a: 1] == Formatter.take_metadata(metadata, {:except, keys})
  end

  defp config(opts) do
    :ok = Logger.configure_backend(@backend, opts)
  end
end
