defmodule Logger.Backend.Humio.Client.Test do
  @moduledoc """
  Test client for the backend.

  Start the GenServer in your test, then use assert_receive.

  See test/client/test_client_test.ex for an example.
  """

  @behaviour Logger.Backend.Humio.Client

  @impl true
  def send(params) do
    GenServer.cast(__MODULE__, {:send, params})
    {:ok, %{status: 200, body: "great success!"}}
  end

  use GenServer

  def start_link(pid) do
    GenServer.start_link(__MODULE__, pid, name: __MODULE__)
  end

  @impl true
  def init(pid) do
    {:ok, %{pid: pid}}
  end

  @impl true
  def handle_cast({:send, params}, %{pid: pid} = state) do
    send(pid, {:send, params})
    {:noreply, state}
  end
end
