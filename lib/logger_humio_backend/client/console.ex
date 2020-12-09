defmodule Logger.Backend.Humio.Client.Console do
  @moduledoc """
  Can be used instead of :console logger to write logs to console for testing.
  Enables the user to visually verify how metadata is parsed and how the message string is formed, since this Logger is more flexible in both respects compared to the :console logger.
  """

  @behaviour Logger.Backend.Humio.Client

  @impl true
  def send_logs(_body, _state) do
    ref = make_ref()
    {:ok, ref}
  end
end
