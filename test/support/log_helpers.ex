defmodule Logger.Backend.Humio.LogHelpers do
  @moduledoc false
  @doc """
  The Logger timestamp format is weird.  This helper gets you a valid one.
  """
  def timestamp do
    DateTime.utc_now()
    |> to_logger_timestamp()
  end

  def to_logger_timestamp(datetime) do
    {microsecond, _} = datetime.microsecond

    {
      {datetime.year, datetime.month, datetime.day},
      {datetime.hour, datetime.minute, datetime.second, div(microsecond, 1000)}
    }
  end
end
