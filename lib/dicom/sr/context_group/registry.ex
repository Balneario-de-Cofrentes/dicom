defmodule Dicom.SR.ContextGroup.Registry do
  @moduledoc """
  Generated CID registry for DICOM SR context groups.

  Contains 1223 context groups with include-chain resolved codes.
  Generated via `mix dicom.gen_context_groups` from PS3.16 data.

  The registry is loaded at compile time from a pre-compiled ETF binary
  (`priv/context_groups_registry.etf`) to avoid exceeding the constant
  term size limit on older Elixir/OTP versions.
  """

  @etf_path Path.expand("../../../../priv/context_groups_registry.etf", __DIR__)
  @external_resource @etf_path

  @registry @etf_path |> File.read!() |> :erlang.binary_to_term()

  @doc "Looks up a context group by CID number."
  @spec lookup(non_neg_integer()) :: {:ok, map()} | :error
  def lookup(cid) do
    case Map.get(@registry, cid) do
      nil -> :error
      entry -> {:ok, entry}
    end
  end

  @doc "Checks whether a code is a member of the given CID."
  @spec member?(non_neg_integer(), String.t(), String.t()) :: boolean() | :unknown_cid
  def member?(cid, scheme, value) do
    case Map.get(@registry, cid) do
      nil -> :unknown_cid
      entry -> MapSet.member?(entry.codes, {scheme, value})
    end
  end

  @doc "Returns whether the given CID is extensible."
  @spec extensible?(non_neg_integer()) :: boolean() | :unknown_cid
  def extensible?(cid) do
    case Map.get(@registry, cid) do
      nil -> :unknown_cid
      entry -> entry.extensible
    end
  end

  @doc "Returns the number of context groups in the registry."
  @spec size() :: non_neg_integer()
  def size, do: map_size(@registry)
end
