defmodule Logger.Backend.Humio.TimeFormatTest do
  use ExUnit.Case, async: false

  alias Logger.Backend.Humio.{LogHelpers, TimeFormat}

  test "format timestamp utc" do
    fun = TimeFormat.iso8601_format_fun(true)
    ts = LogHelpers.timestamp()
    formatted = fun.(ts)
    assert String.ends_with?(formatted, "+00:00")
    assert {:ok, _, _} = DateTime.from_iso8601(formatted)
  end

  test "format timestamp to local timezone" do
    fun = TimeFormat.iso8601_format_fun(false)
    ts = LogHelpers.timestamp()
    formatted = fun.(ts)
    assert {:ok, _, _} = DateTime.from_iso8601(formatted)
  end
end
