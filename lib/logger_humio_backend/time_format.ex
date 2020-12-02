defmodule Logger.Backend.Humio.TimeFormat do
  @moduledoc """
  Helper for formatting timestamps.
  """
  def iso8601_format_utc({date, time}) do
    [Logger.Formatter.format_date(date), "T", Logger.Formatter.format_time(time), "Z"]
    |> IO.chardata_to_string()
  end
end
