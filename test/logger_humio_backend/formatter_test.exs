defmodule Logger.Backend.Humio.FormatterTest do
  use ExUnit.Case, async: false

  import Mox

  alias Logger.Backend.Humio.Client

  require Logger

  @backend {Logger.Backend.Humio, :test}
  Logger.add_backend(@backend)

  @base_url "humio.url"
  @token "token"
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
      client: Client.Mock,
      host: @base_url,
      token: @token,
      # use default format
      format: nil,
      max_batch_size: 1,
      metadata: []
    )

    {:ok, %{ref: ref}}
  end

  # This needs a regex test once the formatting settles
  test "Format message", %{ref: ref} do
    message = "message"
    Logger.info(message)

    assert_receive({^ref, %{body: body}}, 500)
    assert [%{"events" => [%{"rawstring" => decoded_message}]}] = Jason.decode!(body)
    # no metadata after message, trimmed space
    assert String.ends_with?(decoded_message, message)
    assert decoded_message =~ "[info]"
    assert decoded_message =~ self() |> :erlang.pid_to_list() |> (&"[#{&1}]").()
    verify!()
  end

  defp config(opts) do
    :ok = Logger.configure_backend(@backend, opts)
  end
end
