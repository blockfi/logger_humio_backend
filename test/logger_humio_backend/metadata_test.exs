defmodule Logger.Backend.Humio.MetadataTest do
  use ExUnit.Case, async: true

  alias Logger.Backend.Humio.Metadata

  test "take metadata except" do
    metadata = [a: 1, b: 2]
    keys = [:b]
    assert [a: 1] == Metadata.take_metadata(metadata, {:except, keys})
  end
end
