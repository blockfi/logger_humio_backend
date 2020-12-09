defmodule Logger.Backend.Humio.Client.Http do
  @moduledoc """
  Client implementation using Hackney to POST to the Humio APIs.
  The default client.

  TODO: Compression, Retries
  """
  @behaviour Logger.Backend.Humio.Client

  @default_request_options [
    connect_timeout: 5_000,
    recv_timeout: 5_000,
    async: true
  ]
  @path "/api/v1/ingest/humio-structured"
  @content_type "application/json"

  @impl true
  def send_logs(body, %Logger.Backend.Humio{host: base_url, token: token}) do
    url = :hackney_url.make_url(base_url, @path, [])
    req_opts = @default_request_options
    headers = generate_headers(token, @content_type)

    try do
      :hackney.request(:post, url, headers, body, req_opts)
    rescue
      e in ArgumentError -> {:error, e}
    end
  end

  defp generate_headers(token, content_type) do
    [
      {"Authorization", "Bearer " <> token},
      {"Content-Type", content_type}
    ]
  end
end
