defmodule Logger.Backend.Humio.IngestApi.TestIngestApiTest do
  @moduledoc """
  An example test for the Test IngestAPI.

  This serves mainly as an example for how to use the Test IngestAPI in other tests.
  """
  use ExUnit.Case, async: false

  alias Logger.Backend.Humio.IngestApi

  @happy_result {:ok, %{body: "somebody", status: 200}}

  setup do
    IngestApi.Test.start_link(%{pid: self(), result: @happy_result})
    :ok
  end

  test "send and receive" do
    params = "testParams"
    @happy_result = IngestApi.Test.transmit(params)
    assert_receive {:transmit, params}
  end
end
