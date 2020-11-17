defmodule Logger.Backend.Humio.Formatter do
  @moduledoc false

  @type time :: {{1970..10_000, 1..12, 1..31}, {0..23, 0..59, 0..59, 0..999}}
  @type pattern ::
          :application
          | :hostname
          | :level
          | :levelpad
          | :message
          | :node
          | :pid
  @valid_patterns [
    :application,
    :hostname,
    :level,
    :levelpad,
    :message,
    :node,
    :pid
  ]
  @default_pattern "$hostname[$pid]: [$level]$levelpad $message"
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

  def format(config, level, msg, timestamp, metadata) do
    for config_option <- config do
      output(config_option, level, msg, timestamp, metadata)
    end
  end

  defp output(:message, _, msg, _, _), do: msg
  defp output(:level, level, _, _, _), do: Atom.to_string(level)
  defp output(:node, _, _, _, _), do: Atom.to_string(node())

  defp output(:levelpad, level, _, _, _), do: levelpad(level)

  defp output(:hostname, _, _, _, _) do
    {:ok, hostname} = :inet.gethostname()
    hostname
  end

  defp output(:pid, _, _, _, meta) do
    meta
    |> Keyword.fetch!(:pid)
    |> :erlang.pid_to_list()
  end

  defp output(:application, _, _, _, meta) do
    meta
    |> Keyword.fetch!(:pid)
    |> :application.get_application()
    |> application_to_string()
  end

  defp output(other, _, _, _, _), do: other

  defp levelpad(:debug), do: ""
  defp levelpad(:info), do: " "
  defp levelpad(:warn), do: " "
  defp levelpad(:error), do: ""

  defp application_to_string(atom) when is_atom(atom) do
    Atom.to_string(atom)
  end

  defp application_to_string({:ok, application}) do
    application_to_string(application)
  end
end
