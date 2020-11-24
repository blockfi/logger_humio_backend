defmodule Logger.Backend.Humio.TimeFormat do
  @moduledoc """
  Helpers for formatting timestamps to ISO8601.
  The Elixir logger provides the timestamp to backends as a {{year, month, day}, {hour, minute, second, millisecond}} tuple but without timestamp information.
  """
  use Timex

  # if enabled, the logger's timestamp will be in UTC.  Otherwise it will be in local time
  defp utc_log_enabled? do
    Application.get_env(:logger, :utc_log, false)
  end

  @doc """
  By default should be called with arity 0, which then determines if the :utc_log option is set. Based on that information, returns a function that will correctly format an Elixir Logger timestmap to ISO8601.
  """
  def iso8601_format_fun(utc? \\ utc_log_enabled?()) do
    if utc? do
      &iso8601_format_utc/1
    else
      &iso8601_format_local/1
    end
  end

  defp iso8601_format_utc({date, time}) do
    [Logger.Formatter.format_date(date), "T", Logger.Formatter.format_time(time), "Z"]
    |> IO.chardata_to_string()
  end

  defp iso8601_format_local({{year, month, day}, {hour, minute, second, millisecond}}) do
    {:ok, ts} = NaiveDateTime.new(year, month, day, hour, minute, second, millisecond * 1000)
    ts |> Timex.to_datetime(Timezone.local()) |> Timex.format!("{ISO:Extended}")
  end
end
