defmodule Logger.Backend.Humio.Test do
  @moduledoc """
  Smoke tests for the backend.
  """
  use ExUnit.Case, async: false

  alias Logger.Backend.Humio.{ConfigHelpers, TestStruct}

  require Logger

  ### Setup Functions
  defp batch_test_config(_context) do
    ConfigHelpers.configure(
      max_batch_size: 3,
      flush_interval_ms: 10_000
    )
  end

  defp timeout_test_config(_context) do
    ConfigHelpers.configure(
      max_batch_size: 10,
      flush_interval_ms: 300
    )
  end

  defp timeout_test_two_sends_config(_context) do
    ConfigHelpers.configure(2, max_batch_size: 10, flush_interval_ms: 300)
  end

  ### Tests

  describe "smoke tests" do
    test "default logger level is `:debug`" do
      assert Logger.level() == :debug
    end

    test "does not log when level is under minimum Logger level" do
      {:ok, %{ref: ref}} = ConfigHelpers.configure(0, level: :info)
      Logger.debug("do not log me")
      refute_receive {^ref, %{}}
    end

    test "does log when level is above or equal minimum Logger level" do
      {:ok, %{ref: ref}} = ConfigHelpers.configure(level: :info)
      Logger.warn("you will log me")
      assert_receive {^ref, %{}}
    end

    test "can configure format" do
      {:ok, %{ref: ref}} = ConfigHelpers.configure(format: "I have a $message")

      Logger.info("custom format")
      assert_receive {^ref, %{body: body}}

      decoded_body = Jason.decode!(body)

      assert [
               %{
                 "events" => [
                   %{
                     "rawstring" => "I have a custom format",
                     "timestamp" => _
                   }
                 ]
               }
             ] = decoded_body
    end

    test "can configure metadata and send all sorts of stuff" do
      {:ok, %{ref: ref}} = ConfigHelpers.configure(metadata: :all)

      Logger.info("hello", user_id: 123, auth: true)
      assert_receive {^ref, %{body: body}}

      assert [
               %{
                 "tags" => %{
                   "example_tag" => "example_value"
                 },
                 "events" => [
                   %{
                     "timestamp" => timestamp,
                     "rawstring" => "hello",
                     "attributes" => %{
                       "user_id" => "123",
                       "auth" => "true",
                       "domain" => ["elixir"],
                       "file" => file,
                       "function" =>
                         "test smoke tests can configure metadata and send all sorts of stuff/1",
                       "mfa" =>
                         "Logger.Backend.Humio.Test.\"test smoke tests can configure metadata and send all sorts of stuff\"/1",
                       "module" => "Logger.Backend.Humio.Test",
                       "example_field" => "example_value"
                     }
                   }
                 ]
               }
             ] = Jason.decode!(body)

      assert file =~
               "logger_humio_backend/test/logger_humio_backend_test.exs"

      assert {:ok, _, _} = DateTime.from_iso8601(timestamp)
    end

    test "Various Metadata is encoded correctly as attributes" do
      {:ok, %{ref: ref}} = ConfigHelpers.configure(metadata: :all)
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

      assert_receive(
        {^ref,
         %{
           body: body,
           base_url: "host",
           path: "/api/v1/ingest/humio-structured",
           headers: [{"Authorization", "Bearer token"}, {"Content-Type", "application/json"}]
         }}
      )

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

  describe "batch tests" do
    setup [:batch_test_config]

    test "send message batch", %{ref: ref} do
      Logger.info("message1")
      Logger.info("message2")
      refute_receive {^ref, %{}}
      Logger.info("message3")

      assert_receive {^ref, %{body: body}}
      decoded_body = Jason.decode!(body)

      assert [
               %{
                 "events" => [
                   %{
                     "timestamp" => _,
                     "rawstring" => "message1"
                   },
                   %{
                     "timestamp" => _,
                     "rawstring" => "message2"
                   },
                   %{
                     "timestamp" => _,
                     "rawstring" => "message3"
                   }
                 ]
               }
             ] = decoded_body
    end

    test "flush", %{ref: ref} do
      Logger.info("message1")
      refute_receive {^ref, %{}}
      Logger.flush()
      assert_receive {^ref, %{body: body}}
      decoded_body = Jason.decode!(body)

      assert [
               %{
                 "events" => [
                   %{
                     "timestamp" => _,
                     "rawstring" => "message1"
                   }
                 ]
               }
             ] = decoded_body
    end
  end

  describe "timeout tests" do
    setup [:timeout_test_config]

    test "no message received before timeout", %{flush_interval_ms: flush_interval_ms, ref: ref} do
      Logger.info("message")
      # we multiply by 0.7 to ensure we're under the threshold introduced by the 20% jitter.
      refute_receive({^ref, %{}}, round(flush_interval_ms * 0.7))

      # we multiply by 0.5 so that we assert the :transmit is received between 0.7 to 1.3 the flush interval,
      # which accounts for the 20% jitter.
      assert_receive {^ref, %{body: body}}, round(flush_interval_ms * 0.5)
      decoded_body = Jason.decode!(body)

      assert [
               %{
                 "events" => [
                   %{
                     "timestamp" => _,
                     "rawstring" => "message"
                   }
                 ]
               }
             ] = decoded_body
    end

    test "receive batched messages via timeout", %{
      flush_interval_ms: flush_interval_ms,
      max_batch_size: max_batch_size,
      ref: ref
    } do
      for n <- 1..(max_batch_size - 2) do
        Logger.info("message" <> Integer.to_string(n))
      end

      assert_receive {^ref, %{body: body}}, round(flush_interval_ms * 1.2)

      decoded_body = Jason.decode!(body)

      assert [
               %{
                 "events" => [
                   %{
                     "timestamp" => _,
                     "rawstring" => "message1"
                   },
                   %{
                     "timestamp" => _,
                     "rawstring" => "message2"
                   },
                   %{
                     "timestamp" => _,
                     "rawstring" => "message3"
                   },
                   %{
                     "timestamp" => _,
                     "rawstring" => "message4"
                   },
                   %{
                     "timestamp" => _,
                     "rawstring" => "message5"
                   },
                   %{
                     "timestamp" => _,
                     "rawstring" => "message6"
                   },
                   %{
                     "timestamp" => _,
                     "rawstring" => "message7"
                   },
                   %{
                     "timestamp" => _,
                     "rawstring" => "message8"
                   }
                 ]
               }
             ] = decoded_body
    end
  end

  describe "multiple timeouts" do
    setup [:timeout_test_two_sends_config]

    test "timer is reset by flush due to max batch size", %{
      flush_interval_ms: flush_interval_ms,
      max_batch_size: max_batch_size,
      ref: ref
    } do
      for n <- 1..max_batch_size do
        Logger.info("message" <> Integer.to_string(n))
      end

      # received before flush interval reached, since max_batch_size reached
      assert_receive {^ref, %{body: body}}, round(div(flush_interval_ms, 2))

      assert [
               %{
                 "events" => [
                   %{
                     "rawstring" => "message1",
                     "timestamp" => _
                   },
                   %{
                     "rawstring" => "message2",
                     "timestamp" => _
                   },
                   %{
                     "rawstring" => "message3",
                     "timestamp" => _
                   },
                   %{
                     "rawstring" => "message4",
                     "timestamp" => _
                   },
                   %{
                     "rawstring" => "message5",
                     "timestamp" => _
                   },
                   %{
                     "rawstring" => "message6",
                     "timestamp" => _
                   },
                   %{
                     "rawstring" => "message7",
                     "timestamp" => _
                   },
                   %{
                     "rawstring" => "message8",
                     "timestamp" => _
                   },
                   %{
                     "rawstring" => "message9",
                     "timestamp" => _
                   },
                   %{
                     "rawstring" => "message10",
                     "timestamp" => _
                   }
                 ]
               }
             ] = Jason.decode!(body)

      Logger.info("timer is reset")

      assert_receive(
        {^ref, %{body: body}},
        round(flush_interval_ms * 1.2)
      )

      assert [
               %{
                 "events" => [
                   %{
                     "rawstring" => "timer is reset",
                     "timestamp" => _
                   }
                 ]
               }
             ] = Jason.decode!(body)
    end

    test "timer is reset after timeout", %{
      flush_interval_ms: flush_interval_ms,
      ref: ref
    } do
      Logger.info("message1")

      assert_receive(
        {^ref, %{body: body}},
        round(flush_interval_ms * 1.2)
      )

      assert [
               %{
                 "events" => [
                   %{
                     "rawstring" => "message1",
                     "timestamp" => _
                   }
                 ]
               }
             ] = Jason.decode!(body)

      Logger.info("message2")
      Logger.info("message3")

      assert_receive(
        {^ref, %{body: body}},
        round(flush_interval_ms * 1.2)
      )

      assert [
               %{
                 "events" => [
                   %{
                     "rawstring" => "message2",
                     "timestamp" => _
                   },
                   %{
                     "rawstring" => "message3",
                     "timestamp" => _
                   }
                 ]
               }
             ] = Jason.decode!(body)
    end
  end

  describe "failure to send" do
    test "API or Client returns non-2xx status causes error log" do
      {:ok, string_io} = StringIO.open("")
      flush_interval_ms = 100
      error_message = "oh no spaghettio"
      unhappy_result = %{status: 500, body: error_message}

      {:ok, %{ref: ref}} =
        ConfigHelpers.configure(1, unhappy_result,
          flush_interval_ms: flush_interval_ms,
          debug_io_device: string_io
        )

      message = "something important that needs to go to Humio"
      Logger.warn(message)
      assert_receive({^ref, %{}}, round(flush_interval_ms * 2))

      # required since unhappy result needs to be returned to backend from ingest API
      # which triggers the output to the debug device.
      # May be improved in future by substituting a mock IO device for StringIO.
      :timer.sleep(500)
      {:ok, {_initial_empty_string, error_output}} = StringIO.close(string_io)
      assert error_output =~ "ERROR"
      assert error_output =~ "Received unexpected status 500"
      assert error_output =~ error_message
    end
  end
end
