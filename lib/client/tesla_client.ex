defmodule Logger.Backend.Humio.Client.Tesla do
  @moduledoc """
  Client implementation using Tesla to POST to the Humio APIs.
  The default client.
  """
  @behaviour Logger.Backend.Humio.Client

  @impl true
  def send(%{base_url: base_url, path: path, body: body, headers: headers}) do
    case Tesla.post(client(base_url, headers), path, body) do
      {:ok, result} ->
        {:ok,
         %{
           body: result.body,
           status: result.status
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def client(base_url, headers) do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.Headers, headers},
      {Tesla.Middleware.Compression, format: "gzip"},
      {Tesla.Middleware.Retry,
       delay: 500,
       max_retries: 10,
       max_delay: 4_000,
       should_retry: fn
         {:ok, %{status: status}} when status in [400, 500] -> true
         {:ok, _} -> false
         {:error, _} -> true
       end}
    ]

    Tesla.client(middleware)
  end
end
