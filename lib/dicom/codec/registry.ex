defmodule Dicom.Codec.Registry do
  @moduledoc """
  Registry for DICOM pixel data codecs.

  Maps Transfer Syntax UIDs to codec modules implementing `Dicom.Codec`.

  Built-in codecs (e.g., `Dicom.Codec.RLE`) are registered automatically
  on first access. Additional codecs can be registered at runtime:

      Dicom.Codec.Registry.register(MyApp.JPEGCodec)

  Uses `:persistent_term` for O(1) lookup with no process overhead.
  """

  @persistent_term_key {__MODULE__, :codecs}

  @builtin_codecs [Dicom.Codec.RLE]

  @doc """
  Registers a codec module for all Transfer Syntax UIDs it declares.

  The module must implement the `Dicom.Codec` behaviour, specifically
  `transfer_syntax_uids/0`.

  Returns `:ok`.

  ## Examples

      iex> Dicom.Codec.Registry.register(Dicom.Codec.RLE)
      :ok
  """
  @spec register(module()) :: :ok
  def register(module) when is_atom(module) do
    uids = module.transfer_syntax_uids()
    current = load_registry()
    new_entries = Map.new(uids, fn uid -> {uid, module} end)
    :persistent_term.put(@persistent_term_key, Map.merge(current, new_entries))
    :ok
  end

  @doc """
  Looks up a codec module for the given Transfer Syntax UID.

  Returns `{:ok, module}` or `:error`.

  ## Examples

      iex> Dicom.Codec.Registry.lookup("1.2.840.10008.1.2.5")
      {:ok, Dicom.Codec.RLE}
  """
  @spec lookup(String.t()) :: {:ok, module()} | :error
  def lookup(transfer_syntax_uid) when is_binary(transfer_syntax_uid) do
    registry = ensure_initialized()

    case Map.get(registry, transfer_syntax_uid) do
      nil -> :error
      module -> {:ok, module}
    end
  end

  @doc """
  Returns all registered `{uid, module}` pairs.

  ## Examples

      iex> Dicom.Codec.Registry.registered() |> Enum.member?({"1.2.840.10008.1.2.5", Dicom.Codec.RLE})
      true
  """
  @spec registered() :: [{String.t(), module()}]
  def registered do
    ensure_initialized()
    |> Map.to_list()
  end

  @doc """
  Removes the codec registration for a given Transfer Syntax UID.

  Returns `:ok`.
  """
  @spec deregister(String.t()) :: :ok
  def deregister(transfer_syntax_uid) when is_binary(transfer_syntax_uid) do
    current = ensure_initialized()
    :persistent_term.put(@persistent_term_key, Map.delete(current, transfer_syntax_uid))
    :ok
  end

  @doc """
  Resets the registry to only built-in codecs.

  Useful in tests to restore a clean state.
  """
  @spec reset() :: :ok
  def reset do
    :persistent_term.erase(@persistent_term_key)
    ensure_initialized()
    :ok
  end

  # ── Private ────────────────────────────────────────────────────

  defp ensure_initialized do
    case load_registry() do
      map when map_size(map) == 0 ->
        initialize_builtins()

      map ->
        map
    end
  end

  defp load_registry do
    :persistent_term.get(@persistent_term_key, %{})
  end

  defp initialize_builtins do
    registry =
      Enum.reduce(@builtin_codecs, %{}, fn module, acc ->
        uids = module.transfer_syntax_uids()
        entries = Map.new(uids, fn uid -> {uid, module} end)
        Map.merge(acc, entries)
      end)

    :persistent_term.put(@persistent_term_key, registry)
    registry
  end
end
