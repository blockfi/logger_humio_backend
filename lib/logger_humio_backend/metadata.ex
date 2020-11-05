defmodule Logger.Backend.Humio.Metadata do
  @moduledoc """
  Functions for converting metadata to Humio fields.
  """

  @doc """
  Takes the metadata keyword list, removes any unwanted entries, massages values to be serializable, and returns the result as a map that can be encoded for fields (unstructured) or attributes (structured).
  """
  @spec metadata_to_map(keyword(), list() | :all | {:except, list()}) :: map()
  def metadata_to_map(metadata, keys) do
    metadata
    |> take_metadata(keys)
    |> metadata()
    |> Enum.into(%{})
    |> Iteraptor.to_flatmap()
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

  def metadata(metadata) when is_list(metadata) do
    metadata
    |> Enum.map(fn {k, v} -> {k, metadata(k, v)} end)
  end

  defp metadata(:time, _), do: nil
  defp metadata(:gl, _), do: nil
  defp metadata(:report_cb, _), do: nil

  defp metadata(_, nil), do: nil
  defp metadata(_, string) when is_binary(string), do: string
  defp metadata(_, integer) when is_integer(integer), do: Integer.to_string(integer)
  defp metadata(_, float) when is_float(float), do: Float.to_string(float)
  defp metadata(_, pid) when is_pid(pid), do: pid |> :erlang.pid_to_list() |> to_string()

  defp metadata(_, atom) when is_atom(atom) do
    case Atom.to_string(atom) do
      "Elixir." <> rest -> rest
      "nil" -> ""
      binary -> binary
    end
  end

  defp metadata(_, ref) when is_reference(ref) do
    ref |> :erlang.ref_to_list() |> to_string()
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
end
