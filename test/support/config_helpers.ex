defmodule Logger.Backend.Humio.ConfigHelpers do
  @moduledoc """
  Helper for configuring a Logger Backend for tests that is completely independent from test to test, as we grab the default_config and then merge in the provided opts.
  """

  alias Logger.Backend.Humio
  alias Logger.Backend.Humio.Client

  import Mox

  # Sensible test defaults
  @default_overrides [
    host: "host",
    token: "token",
    format: "$message",
    client: Client.Mock,
    max_batch_size: 1,
    flush_interval_ms: 500,
    fields: %{
      "example_field" => "example_value"
    },
    tags: %{
      "example_tag" => "example_value"
    }
  ]

  @happy_result %{status: 200, body: "somebody"}
  @fake_headers []

  @doc """
  Test configuration simplified. Sets up a Logger backend with sensible defaults for testing and a mock client that, by default, expects to be called once and will return a happy path result.

  Times that the client is expected to be called, as well as the result it should return, can be passed as arguments, as well as configuration that overrides the defaults.

  Returns {:ok, map} where map contains the passed opts as well as a reference `ref` which will be sent to the process that configured the test.
  """
  def configure(times \\ 1, result \\ @happy_result, opts)

  def configure(times, %{status: status, body: body}, opts) when is_integer(times) do
    set_mox_global()

    parent = self()
    ref = make_ref()

    expect(Client.Mock, :send, times, fn state ->
      # send state to the test
      send(parent, {ref, state})

      request_ref = make_ref()

      # send result to the logger backend
      Process.send_after(self(), {:hackney_response, request_ref, {:headers, @fake_headers}}, 100)

      Process.send_after(
        self(),
        {:hackney_response, request_ref, {:status, status, "status"}},
        120
      )

      Process.send_after(self(), {:hackney_response, request_ref, body}, 140)
      Process.send_after(self(), {:hackney_response, request_ref, :done}, 160)

      # return reference
      {:ok, request_ref}
    end)

    _ = Logger.add_backend(Humio, flush: true)

    opts =
      Humio.default_config()
      |> Keyword.merge(@default_overrides)
      |> Keyword.merge(opts)

    :ok = Logger.configure_backend(Humio, opts)

    verify_on_exit!()

    {:ok, opts |> Enum.into(Map.new()) |> Map.put_new(:ref, ref)}
  end
end
