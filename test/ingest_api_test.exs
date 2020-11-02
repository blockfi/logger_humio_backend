defmodule Logger.Backend.Humio.IngestApiTest do
  @moduledoc """
  Tests of the common functionality for all ingest APIs, primarily related to message formatting.
  """
  use ExUnit.Case, async: false

  alias Logger.Backend.Humio.IngestApi

  test "can configure metadata" do
    metadata = [auth: true, user_id: 13]
    assert [auth: true] == IngestApi.take_metadata(metadata, [:auth])
  end

  test "can parse :all metadata" do
    metadata = [auth: true, user_id: 13]
    assert metadata == IngestApi.take_metadata(metadata, :all)
  end

  test "generates headers appropriate for Humio" do
    token = "token"
    content_type = "content_type"

    assert [{"Authorization", "Bearer " <> token}, {"Content-Type", content_type}] ==
             IngestApi.generate_headers(token, content_type)
  end
end
