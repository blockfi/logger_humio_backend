defmodule Logger.Backend.Humio do
  @moduledoc """
  A Genserver that receives calls and events from Elixir when configured as a logger.
  """
  @behaviour :gen_event

  alias Logger.Backend.Humio.{Client, Formatter, Metadata, TimeFormat}

  require Logger

  @path "/api/v1/ingest/humio-structured"
  @content_type "application/json"
  @default_config [
    client: Client.Tesla,
    host: "",
    token: "",
    min_level: :debug,
    metadata: [],
    format: nil,
    max_batch_size: 20,
    flush_interval_ms: 2_000,
    debug_io_device: :stdio,
    fields: %{},
    tags: %{}
  ]

  defstruct [log_events: [], flush_timer: nil] ++ @default_config

  @type log_event :: %{
          level: Logger.level(),
          message: String.t(),
          timestamp: any(),
          metadata: keyword()
        }
  @type t :: %__MODULE__{
          log_events: [log_event] | [],
          flush_timer: reference() | nil,
          token: String.t(),
          host: String.t(),
          client: Client,
          min_level: Logger.level(),
          format: any(),
          metadata: keyword() | :all | {:except, keyword()},
          max_batch_size: pos_integer(),
          flush_interval_ms: pos_integer(),
          debug_io_device: atom() | pid(),
          fields: map(),
          tags: map()
        }

  #### :gen_event implementation

  @impl true
  @spec init(__MODULE__) :: {:ok, t}
  def init(__MODULE__) do
    init_state = configure([], %__MODULE__{})
    {:ok, init_state}
  end

  @impl true
  @spec handle_call({:configure, Keyword.t()}, t) :: {:ok, :ok, t}
  def handle_call({:configure, opts}, state) do
    {:ok, :ok, configure(opts, state)}
  end

  @doc """
  Ignore messages where the group leader is in a different node than the one where handler is installed.
  """
  @impl true
  def handle_event({_level, group_leader, {Logger, _msg, _ts, _md}}, state)
      when node(group_leader) != node() do
    {:ok, state}
  end

  def handle_event({level, _group_leader, {Logger, msg, ts, md}}, state) do
    if is_nil(state.min_level) or Logger.compare_levels(level, state.min_level) != :lt do
      add_to_batch(
        %{
          level: level,
          message: msg,
          timestamp: ts,
          metadata: md
        },
        state
      )
    else
      {:ok, state}
    end
  end

  @doc """
  Send batched events when `Logger.flush/0` is called.
  """
  @impl true
  def handle_event(:flush, state) do
    send_events(state)
  end

  @doc """
  Handles flush due to timeout from the timer set in the `set_timer` function.
  """
  @impl true
  def handle_info({:timeout, _ref, :flush}, state) do
    send_events(state)
  end

  @doc """
  Unhandled messages are simply ignored.
  """
  def handle_info(_message, state) do
    {:ok, state}
  end

  #### internal implementation

  defp set_timer_if_nil(%__MODULE__{flush_timer: nil} = state), do: set_timer(state)

  defp set_timer_if_nil(state), do: state

  # Sets the timer in the state to have the backend send a :flush info message to itself on timeout.
  # Introduces 20% jitter.
  defp set_timer(%__MODULE__{flush_interval_ms: flush_interval_ms} = state) do
    jitter = :random.uniform(div(flush_interval_ms, 5))
    timer = :erlang.start_timer(flush_interval_ms + jitter, self(), :flush)
    %{cancel_timer(state) | flush_timer: timer}
  end

  defp cancel_timer(%__MODULE__{flush_timer: timer} = state) when is_nil(timer), do: state

  defp cancel_timer(%__MODULE__{flush_timer: timer} = state) do
    :erlang.cancel_timer(timer)
    %{state | flush_timer: nil}
  end

  defp add_to_batch(log_event, %__MODULE__{max_batch_size: max_batch_size} = state) do
    state =
      state
      |> Map.put(:log_events, [log_event | state.log_events])
      |> set_timer_if_nil()

    if length(state.log_events) >= max_batch_size do
      send_events(state)
    else
      {:ok, state}
    end
  end

  defp send_events(%__MODULE__{log_events: []} = state) do
    {:ok, state}
  end

  defp send_events(
         %__MODULE__{
           log_events: log_events,
           debug_io_device: debug_io_device
         } = state
       ) do
    state
    |> Map.update!(:log_events, &Enum.reverse(&1))
    |> transmit()
    |> case do
      {:ok, %{status: status, body: body}} when status not in 200..299 ->
        log(
          debug_io_device,
          :error,
          "Sending logs to Humio failed. Status: #{inspect(status)}, Response Body: #{
            inspect(body)
          }, logs: #{inspect(log_events)}"
        )

      {:error, reason} ->
        log(
          debug_io_device,
          :error,
          "Sending logs to Humio failed: #{inspect(reason)}, logs: #{inspect(log_events)}"
        )

      {:ok, _response} ->
        :ok
    end

    {:ok, %{cancel_timer(state) | log_events: []}}
  end

  defp log(nil, _level, _message) do
    false
  end

  defp log(io_device, level, message) do
    level = level |> Atom.to_string() |> String.upcase()
    IO.puts(io_device, [level, ": ", message])
  end

  def default_config, do: @default_config

  @spec configure(Keyword.t(), t()) :: t()
  defp configure(opts, state) do
    updates = [
      client: Keyword.get(opts, :client, state.client),
      host: Keyword.get(opts, :host, state.host),
      token: Keyword.get(opts, :token, state.token),
      min_level: Keyword.get(opts, :min_level, state.min_level),
      metadata: Keyword.get(opts, :metadata, state.metadata),
      format: opts |> Keyword.get(:format, nil) |> Formatter.compile(),
      max_batch_size: Keyword.get(opts, :max_batch_size, state.max_batch_size),
      flush_interval_ms: Keyword.get(opts, :flush_interval_ms, state.flush_interval_ms),
      debug_io_device: Keyword.get(opts, :debug_io_device, state.debug_io_device),
      fields: Keyword.get(opts, :fields, state.fields),
      tags: Keyword.get(opts, :tags, state.tags)
    ]

    struct!(state, updates)
  end

  def transmit(
        %__MODULE__{
          host: host,
          token: token,
          client: client,
          tags: tags
        } = state
      ) do
    headers = generate_headers(token, @content_type)

    to_events(state)
    |> to_request(tags)
    |> Jason.encode()
    |> case do
      {:ok, body} ->
        client.send(%{
          base_url: host,
          path: @path,
          body: body,
          headers: headers
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_request(events, tags) do
    Map.new()
    |> Map.put_new("events", events)
    |> add_tags(tags)
    |> List.wrap()
  end

  def add_tags(map, tags) when tags == %{} do
    map
  end

  def add_tags(map, tags) do
    Map.put_new(map, "tags", tags)
  end

  defp to_events(%__MODULE__{log_events: log_events} = state) do
    log_events
    |> Enum.map(&to_event(&1, state))
  end

  defp to_event(
         %{metadata: metadata, timestamp: timestamp} = log_event,
         %__MODULE__{metadata: metadata_keys, fields: fields} = state
       ) do
    formatted_timestamp = TimeFormat.iso8601_format_utc(timestamp)
    rawstring = format_message(log_event, state)
    metadata_map = metadata |> Metadata.metadata_to_map(metadata_keys)
    attributes = Map.merge(fields, metadata_map)

    Map.new()
    |> Map.put_new("rawstring", rawstring)
    |> add_attributes(attributes)
    |> Map.put_new("timestamp", formatted_timestamp)
  end

  defp add_attributes(map, attributes) when attributes == %{} do
    map
  end

  defp add_attributes(map, attributes) do
    Map.put_new(map, "attributes", attributes)
  end

  def generate_headers(token, content_type) do
    [
      {"Authorization", "Bearer " <> token},
      {"Content-Type", content_type}
    ]
  end

  def format_message(
        %{message: msg, level: level, timestamp: ts, metadata: md},
        %__MODULE__{format: format}
      ) do
    format
    |> Formatter.format(level, msg, ts, md)
    |> IO.chardata_to_string()
    |> String.trim()
  end
end
