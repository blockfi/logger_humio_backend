defmodule Logger.Backend.Humio.TimeFormatTest do
  use ExUnit.Case, async: false

  alias Logger.Backend.Humio.{LogHelpers, TimeFormat}

  test "format timestamp utc" do
    ts = LogHelpers.timestamp()
    formatted = TimeFormat.iso8601_format_utc(ts)
    assert {:ok, _, _} = DateTime.from_iso8601(formatted)
  end
end
