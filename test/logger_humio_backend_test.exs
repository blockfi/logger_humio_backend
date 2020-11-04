defmodule Logger.Backend.Humio.Test do
  @moduledoc """
  Smoke tests for the backend.
  """
  use ExUnit.Case, async: false

  import Mox

  alias Logger.Backend.Humio.IngestApi

  require Logger

  @backend {Logger.Backend.Humio, :test}
  Logger.add_backend(@backend)

  @happy_result {:ok, %{status: 200, body: "somebody"}}

  ### Setup Functions

  defp smoke_test_config(_context) do
    set_mox_global()
    config(
      ingest_api: IngestApi.Mock,
      host: "humio.url",
      format: "[$level] $message\n",
      token: "humio-token",
      max_batch_size: 1
    )
    :ok
  end

  defp batch_test_config(_context) do
    config(
      ingest_api: Logger.Backend.Humio.IngestApi.Test,
      host: "humio.url",
      format: "[$level] $message\n",
      token: "humio-token",
      max_batch_size: 3,
      flush_interval_ms: 10_000
    )

    IngestApi.Test.start_link(%{pid: self(), result: @happy_result})
    :ok
  end

  defp timeout_test_config(_context) do
    flush_interval_ms = 200
    max_batch_size = 10

    config(
      ingest_api: Logger.Backend.Humio.IngestApi.Test,
      host: "humio.url",
      format: "$message",
      token: "humio-token",
      max_batch_size: max_batch_size,
      flush_interval_ms: flush_interval_ms
    )

    IngestApi.Test.start_link(%{pid: self(), result: @happy_result})
    {:ok, %{flush_interval_ms: flush_interval_ms, max_batch_size: max_batch_size}}
  end

  ### Tests

  describe "smoke tests" do
    setup [:smoke_test_config]

    test "default logger level is `:debug`" do
      assert Logger.level() == :debug
    end

    test "does not log when level is under minimum Logger level" do
      config(level: :info)
      Logger.debug("do not log me")
      refute_receive {:transmit, %{}}
    end

    test "does log when level is above or equal minimum Logger level" do
      parent = self()

      expect(IngestApi.Mock, :transmit, fn state ->
        send(parent, {:transmit, state})
        @happy_result
      end)

      config(level: :info)
      Logger.warn("you will log me")
      assert_receive {:transmit, %{}}
      verify!()
    end

    test "can configure format" do
      config(format: "$message ($level)\n")
      Logger.info("I am formatted")
      assert_receive {:transmit, %{config: %{format: [:message, " (", :level, ")\n"]}}}
    end

    test "can configure metadata" do
      config(format: "$metadata$message\n", metadata: [:user_id, :auth])

      Logger.info("hello")
      assert_receive {:transmit, %{config: %{metadata: [:user_id, :auth]}}}
    end
  end

  describe "batch tests" do
    setup [:batch_test_config]

    test "send message batch" do
      Logger.info("message1")
      Logger.info("message2")
      refute_receive {:transmit, %{}}
      Logger.info("message3")

      assert_receive {:transmit,
                      %{
                        log_events: [
                          %{message: "message1"},
                          %{message: "message2"},
                          %{message: "message3"}
                        ]
                      }}

      Logger.info("message4")
      refute_receive {:transmit, %{}}
    end

    test "flush" do
      Logger.info("message1")
      refute_receive {:transmit, %{}}
      Logger.flush()
      assert_receive {:transmit, %{log_events: [%{message: "message1"}]}}
    end
  end

  describe "timeout tests" do
    setup [:timeout_test_config]

    test "no message received before timeout", %{flush_interval_ms: flush_interval_ms} do
      Logger.info("message")
      # we multiply by 0.7 to ensure we're under the threshold introduced by the 20% jitter.
      refute_receive({:transmit, %{}}, round(flush_interval_ms * 0.7))

      # we multipley by 0.5 so that we assert the :transmit is received between 0.7 to 1.3 the flush interval, which accounts for the 20% jitter.
      assert_receive(
        {:transmit, %{log_events: [%{message: "message"}]}},
        round(flush_interval_ms * 0.6)
      )
    end

    test "receive batched messages via timeout", %{
      flush_interval_ms: flush_interval_ms,
      max_batch_size: max_batch_size
    } do
      for n <- 1..(max_batch_size - 2) do
        Logger.info("message" <> Integer.to_string(n))
      end

      assert_receive(
        {:transmit,
         %{
           log_events: [
             %{message: "message1"},
             %{message: "message2"},
             %{message: "message3"},
             %{message: "message4"},
             %{message: "message5"},
             %{message: "message6"},
             %{message: "message7"},
             %{message: "message8"}
           ]
         }},
        round(flush_interval_ms * 1.2)
      )
    end

    test "no timer set/nothing sent to ingest API while log event queue is empty", %{
      flush_interval_ms: flush_interval_ms
    } do
      refute_receive({:transmit, %{}}, round(flush_interval_ms * 1.5))
    end

    test "timer is reset after timeout", %{flush_interval_ms: flush_interval_ms} do
      Logger.info("message1")

      assert_receive(
        {:transmit, %{log_events: [%{message: "message1"}]}},
        round(flush_interval_ms * 1.2)
      )

      Logger.info("message2")
      Logger.info("message3")

      assert_receive(
        {:transmit, %{log_events: [%{message: "message2"}, %{message: "message3"}]}},
        round(flush_interval_ms * 1.2)
      )
    end

    test "timer is reset by flush due to max batch size", %{
      flush_interval_ms: flush_interval_ms,
      max_batch_size: max_batch_size
    } do
      for n <- 1..max_batch_size do
        Logger.info("message" <> Integer.to_string(n))
      end

      # received before flush interval reached, since max_batch_size reached
      assert_receive(
        {:transmit,
         %{
           log_events: [
             %{message: "message1"},
             %{message: "message2"},
             %{message: "message3"},
             %{message: "message4"},
             %{message: "message5"},
             %{message: "message6"},
             %{message: "message7"},
             %{message: "message8"},
             %{message: "message9"},
             %{message: "message10"}
           ]
         }},
        round(div(flush_interval_ms, 2))
      )

      Logger.info("timer is reset")

      assert_receive(
        {:transmit, %{log_events: [%{message: "timer is reset"}]}},
        round(flush_interval_ms * 1.2)
      )
    end
  end

  describe "failure to send" do
    test "API or Client returns non-2xx status causes error log" do
      {:ok, string_io} = StringIO.open("")
      flush_interval_ms = 100

      config(
        ingest_api: Logger.Backend.Humio.IngestApi.Test,
        host: "humio.url",
        token: "humio-token",
        flush_interval_ms: flush_interval_ms,
        debug_io_device: string_io
      )

      error_message = "oh no spaghettio"
      unhappy_result = {:ok, %{status: 500, body: error_message}}
      IngestApi.Test.start_link(%{pid: self(), result: unhappy_result})
      message = "something important that needs to go to Humio"
      Logger.warn(message)
      assert_receive({:transmit, %{}}, round(flush_interval_ms * 2))

      # required since unhappy result needs to be returned to backend from ingest API, which triggers the output to the debug device.
      # May be improved in future by substituting a mock IO device for StringIO.
      :timer.sleep(500)
      {:ok, {_initial_empty_string, error_output}} = StringIO.close(string_io)
      assert error_output =~ "ERROR"
      assert error_output =~ "Sending logs to Humio failed."
      assert error_output =~ "Status: 500"
      assert error_output =~ message
      assert error_output =~ error_message
    end

    test "API or Client returns :error causing error log" do
      {:ok, string_io} = StringIO.open("")
      flush_interval_ms = 100

      config(
        ingest_api: Logger.Backend.Humio.IngestApi.Test,
        host: "humio.url",
        token: "humio-token",
        flush_interval_ms: flush_interval_ms,
        debug_io_device: string_io
      )

      reason = "oh no spaghettio"
      unhappy_result = {:error, reason}
      IngestApi.Test.start_link(%{pid: self(), result: unhappy_result})
      message = "something important that needs to go to Humio"
      Logger.warn(message)
      assert_receive({:transmit, %{}}, round(flush_interval_ms * 2))

      # required since unhappy result needs to be returned to backend from ingest API, which triggers the output to the debug device.
      # May be improved in future by substituting a mock IO device for StringIO.
      :timer.sleep(500)
      {:ok, {_initial_empty_string, error_output}} = StringIO.close(string_io)
      assert error_output =~ "ERROR"
      assert error_output =~ "Sending logs to Humio failed"
      assert error_output =~ message
      assert error_output =~ reason
    end
  end

  defp config(opts) do
    :ok = Logger.configure_backend(@backend, opts)
  end
end
