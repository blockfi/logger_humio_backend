defmodule Logger.Backend.Humio.IngestApiTest do
  @moduledoc """
  Tests of the common functionality for all ingest APIs, primarily related to message formatting.
  """
  use ExUnit.Case, async: false

  alias Logger.Backend.Humio.IngestApi

  test "generates headers appropriate for Humio" do
    token = "token"
    content_type = "content_type"

    assert [{"Authorization", "Bearer " <> token}, {"Content-Type", content_type}] ==
             IngestApi.generate_headers(token, content_type)
  end
end
