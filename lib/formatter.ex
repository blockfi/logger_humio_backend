defmodule Logger.Backend.Humio.Formatter do
  @moduledoc """
  Extends the standard Logger.Formatter with support for additional pattersn:
  * $datetime, which will format the time stamp according to ISO8601.
  * $hostname
  * $pid, which takes the pid from the standard metadata as a stand-alone field. Will work even if :pid is not specified in the metadata config.
  To do so, it expects the metadata keyword list to contain the key `iso8601_format_fun` whose value is a function that accepts the below `time` type as parameter and returns a String type.
  * $application, which derives the application that submitted the log from the PID.
  """

  @type time :: {{1970..10_000, 1..12, 1..31}, {0..23, 0..59, 0..59, 0..999}}
  @type pattern ::
          :date
          | :level
          | :levelpad
          | :message
          | :metadata
          | :node
          | :time
          | :datetime
          | :hostname
          | :pid
          | :application
  @valid_patterns [
    :time,
    :date,
    :message,
    :level,
    :node,
    :metadata,
    :levelpad,
    :datetime,
    :hostname,
    :pid,
    :application
  ]
  @default_pattern "$datetime $hostname[$pid]: [$level] $message $metadata"
  @replacement "�"

  @doc """
  Prunes invalid Unicode code points from lists and invalid UTF-8 bytes.
  Typically called after formatting when the data cannot be printed.
  """
  @spec prune(IO.chardata()) :: IO.chardata()
  def prune(binary) when is_binary(binary), do: prune_binary(binary, "")
  def prune([h | t]) when h in 0..1_114_111, do: [h | prune(t)]
  def prune([h | t]), do: [prune(h) | prune(t)]
  def prune([]), do: []
  def prune(_), do: @replacement

  defp prune_binary(<<h::utf8, t::binary>>, acc), do: prune_binary(t, <<acc::binary, h::utf8>>)
  defp prune_binary(<<_, t::binary>>, acc), do: prune_binary(t, <<acc::binary, @replacement>>)
  defp prune_binary(<<>>, acc), do: acc

  @spec compile(binary | nil) :: [pattern | binary]
  @spec compile(pattern) :: pattern when pattern: {module, function :: atom}
  def compile(pattern)

  def compile(nil), do: compile(@default_pattern)
  def compile({mod, fun}) when is_atom(mod) and is_atom(fun), do: {mod, fun}

  def compile(str) when is_binary(str) do
    regex = ~r/(?<head>)\$[a-z]+(?<tail>)/

    for part <- Regex.split(regex, str, on: [:head, :tail], trim: true) do
      case part do
        "$" <> code -> compile_code(String.to_atom(code))
        _ -> part
      end
    end
  end

  defp compile_code(key) when key in @valid_patterns, do: key

  defp compile_code(key) when is_atom(key) do
    raise ArgumentError, "$#{key} is an invalid format pattern"
  end

  @doc """
  Formats time as chardata.
  """
  @spec format_time({0..23, 0..59, 0..59, 0..999}) :: IO.chardata()
  def format_time({hh, mi, ss, ms}) do
    [pad2(hh), ?:, pad2(mi), ?:, pad2(ss), ?., pad3(ms)]
  end

  @doc """
  Formats date as chardata.
  """
  @spec format_date({1970..10_000, 1..12, 1..31}) :: IO.chardata()
  def format_date({yy, mm, dd}) do
    [Integer.to_string(yy), ?-, pad2(mm), ?-, pad2(dd)]
  end

  defp pad3(int) when int < 10, do: [?0, ?0, Integer.to_string(int)]
  defp pad3(int) when int < 100, do: [?0, Integer.to_string(int)]
  defp pad3(int), do: Integer.to_string(int)

  defp pad2(int) when int < 10, do: [?0, Integer.to_string(int)]
  defp pad2(int), do: Integer.to_string(int)

  def format(config, level, msg, timestamp, metadata, metadata_keys) do
    for config_option <- config do
      output(config_option, level, msg, timestamp, metadata, metadata_keys)
    end
  end

  def take_metadata(metadata, :all) do
    metadata
  end

  def take_metadata(metadata, keys) when is_list(keys) do
    keys
    |> Enum.reduce([], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error -> acc
      end
    end)
    |> Enum.reverse()
  end

  defp output(:message, _, msg, _, _, _), do: msg
  defp output(:date, _, _, {date, _time}, _, _), do: format_date(date)
  defp output(:time, _, _, {_date, time}, _, _), do: format_time(time)
  defp output(:level, level, _, _, _, _), do: Atom.to_string(level)
  defp output(:node, _, _, _, _, _), do: Atom.to_string(node())
  defp output(:metadata, _, _, _, [], _), do: ""

  defp output(:metadata, _, _, _, meta, metadata_keys),
    do: take_metadata(meta, metadata_keys) |> metadata()

  defp output(:levelpad, level, _, _, _, _), do: levelpad(level)

  defp output(:datetime, _, _, datetime, metadata, _),
    do: Keyword.fetch!(metadata, :iso8601_format_fun).(datetime)

  defp output(:hostname, _, _, _, _, _) do
    {:ok, hostname} = :inet.gethostname()
    hostname
  end

  defp output(:pid, _, _, _, meta, _), do: metadata("", Keyword.fetch!(meta, :pid))

  defp output(:application, _, _, _, meta, _) do
    meta
    |> Keyword.fetch!(:pid)
    |> :application.get_application()
    |> application_to_string()
  end

  defp output(other, _, _, _, _, _), do: other

  defp levelpad(:debug), do: ""
  defp levelpad(:info), do: " "
  defp levelpad(:warn), do: " "
  defp levelpad(:error), do: ""

  defp metadata([{key, value} | metadata]) do
    if formatted = metadata(key, value) do
      [to_string(key), ?=, formatted, ?\s | metadata(metadata)]
    else
      metadata(metadata)
    end
  end

  defp metadata([]), do: []

  defp metadata(:time, _), do: nil
  defp metadata(:gl, _), do: nil
  defp metadata(:report_cb, _), do: nil

  defp metadata(_, nil), do: nil
  defp metadata(_, string) when is_binary(string), do: string
  defp metadata(_, integer) when is_integer(integer), do: Integer.to_string(integer)
  defp metadata(_, float) when is_float(float), do: Float.to_string(float)
  defp metadata(_, pid) when is_pid(pid), do: :erlang.pid_to_list(pid)

  defp metadata(_, atom) when is_atom(atom) do
    case Atom.to_string(atom) do
      "Elixir." <> rest -> rest
      "nil" -> ""
      binary -> binary
    end
  end

  defp metadata(_, ref) when is_reference(ref) do
    '#Ref' ++ rest = :erlang.ref_to_list(ref)
    rest
  end

  defp metadata(:file, file) when is_list(file), do: file

  defp metadata(:domain, [head | tail]) when is_atom(head) do
    Enum.map_intersperse([head | tail], ?., &Atom.to_string/1)
  end

  defp metadata(:mfa, {mod, fun, arity})
       when is_atom(mod) and is_atom(fun) and is_integer(arity) do
    Exception.format_mfa(mod, fun, arity)
  end

  defp metadata(:initial_call, {mod, fun, arity})
       when is_atom(mod) and is_atom(fun) and is_integer(arity) do
    Exception.format_mfa(mod, fun, arity)
  end

  defp metadata(_, list) when is_list(list), do: nil

  defp metadata(_, other) do
    case String.Chars.impl_for(other) do
      nil -> nil
      impl -> impl.to_string(other)
    end
  end

  defp application_to_string(atom) when is_atom(atom) do
    Atom.to_string(atom)
  end

  defp application_to_string({:ok, application}) do
    application_to_string(application)
  end
end
