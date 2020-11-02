defmodule Logger.Backend.Humio.Client.TestClientTest do
  @moduledoc """
  An example test for the Test Client.

  This serves mainly as an example for how to use the Test Client in other tests.
  """
  use ExUnit.Case, async: false

  alias Logger.Backend.Humio.Client

  setup do
    Client.Test.start_link(self())
    :ok
  end

  test "send and receive" do
    params = "testParams"
    Client.Test.send(params)
    assert_receive {:send, params}
  end
end
