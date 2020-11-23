defmodule Logger.Backend.Humio.Metadata do
  @moduledoc """
  Functions for converting metadata to Humio fields.
  """

  @nil_substitute "nil"

  @doc """
  Takes the metadata keyword list, removes any unwanted entries, massages values to be serializable, and returns the result as a map that can be encoded for fields (unstructured) or attributes (structured).
  """
  @spec metadata_to_map(keyword(), list() | :all | {:except, list()}) :: map()
  def metadata_to_map(metadata, keys) do
    metadata
    |> take_metadata(keys)
    |> format_metadata()
    |> Enum.map(&nil_to_string/1)
    |> Enum.into(%{})
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

  def take_metadata(metadata, {:except, keys}) when is_list(keys) do
    metadata
    |> Keyword.drop(keys)
  end

  def format_metadata(metadata) do
    Iteraptor.map(metadata, fn {k, v} ->
      {k, metadata(k, v)}
    end)
    |> Iteraptor.jsonify()
  end

  defp metadata([:time], _), do: nil
  defp metadata([:gl], _), do: nil
  defp metadata([:report_cb], _), do: nil
  defp metadata([:file], file) when is_list(file), do: file

  defp metadata([:mfa], {mod, fun, arity})
       when is_atom(mod) and is_atom(fun) and is_integer(arity) do
    Exception.format_mfa(mod, fun, arity)
  end

  defp metadata([:initial_call], {mod, fun, arity})
       when is_atom(mod) and is_atom(fun) and is_integer(arity) do
    Exception.format_mfa(mod, fun, arity)
  end

  defp metadata(_, nil), do: nil

  defp metadata(_, list) when is_list(list) do
    if Keyword.keyword?(list) do
      Iteraptor.map(list, fn {k, v} -> metadata(k, v) end)
    else
      Iteraptor.map(list, fn v -> metadata(nil, v) end)
    end
  end

  defp metadata(_, struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Iteraptor.map(fn {k, v} -> {k, metadata(k, v)} end)
  end

  defp metadata(_, map) when is_map(map) do
    Iteraptor.map(map, fn {k, v} -> {k, metadata(k, v)} end)
  end

  defp metadata(_, string) when is_binary(string), do: string
  defp metadata(_, integer) when is_integer(integer), do: Integer.to_string(integer)
  defp metadata(_, float) when is_float(float), do: Float.to_string(float)
  defp metadata(_, pid) when is_pid(pid), do: pid |> :erlang.pid_to_list() |> to_string()

  defp metadata(_, tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.map(fn v -> metadata(nil, v) end)
  end

  defp metadata(_, atom) when is_atom(atom) do
    case Atom.to_string(atom) do
      "Elixir." <> rest -> rest
      "nil" -> ""
      binary -> binary
    end
  end

  defp metadata(_, port) when is_port(port), do: port |> :erlang.port_to_list() |> to_string()

  defp metadata(_, ref) when is_reference(ref) do
    ref |> :erlang.ref_to_list() |> to_string()
  end

  defp metadata(_, function) when is_function(function) do
    function |> :erlang.fun_to_list() |> to_string()
  end

  defp metadata(_, other) do
    case String.Chars.impl_for(other) do
      nil -> nil
      impl -> impl.to_string(other)
    end
  end

  defp nil_to_string({k, v}) when is_nil(v) do
    {k, @nil_substitute}
  end

  defp nil_to_string({k, v}) do
    {k, v}
  end
end
