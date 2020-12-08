defmodule Logger.Backend.Humio.Client.Hackney do
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

  @impl true
  def send(%{base_url: base_url, path: path, body: body, headers: headers}) do
    url = :hackney_url.make_url(base_url, path, [])
    req_opts = @default_request_options

    try do
      :hackney.request(:post, url, headers, body, req_opts)
    rescue
      e in ArgumentError -> {:error, e}
    end
  end
end
