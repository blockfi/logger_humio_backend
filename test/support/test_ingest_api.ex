defmodule Logger.Backend.Humio.IngestApi.Test do
  @moduledoc """
  This Ingest API implementation is designed for testing.

  It writes entries to @logfile contains convenience functions for reading back what was logged and cleaning up the generated file.
  """
  @behaviour Logger.Backend.Humio.IngestApi

  @type opts :: %{
          pid: pid(),
          result: Logger.Backend.Humio.IngestApi.result()
        }

  @impl true
  def transmit(params) do
    GenServer.call(__MODULE__, {:transmit, params})
  end

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def handle_call({:transmit, params}, _from, %{pid: pid, result: result} = state) do
    send(pid, {:transmit, params})
    {:reply, result, state}
  end
end
