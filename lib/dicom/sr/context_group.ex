defmodule Dicom.SR.ContextGroup do
  @moduledoc """
  CID validation for coded concepts.

  Validates whether a `Dicom.SR.Code` is a member of a DICOM Context Group (CID).
  Non-extensible CIDs reject codes not in the defined set; extensible CIDs accept
  any code but signal it via `{:ok, :extensible}`.
  """

  alias Dicom.SR.Code
  alias Dicom.SR.ContextGroup.Registry

  @type validation_result ::
          :ok | {:ok, :extensible} | {:error, :not_in_cid} | {:error, :unknown_cid}

  @doc """
  Validates a code against a context group.

  Returns:
    - `:ok` — code is a defined member of the CID
    - `{:ok, :extensible}` — code is not in the CID but the CID is extensible
    - `{:error, :not_in_cid}` — code is not in a non-extensible CID
    - `{:error, :unknown_cid}` — CID does not exist in the registry
  """
  @spec validate(Code.t(), non_neg_integer()) :: validation_result()
  def validate(%Code{} = code, cid) when is_integer(cid) do
    case Registry.lookup(cid) do
      {:ok, entry} ->
        if Registry.member?(cid, code.scheme_designator, code.value) do
          :ok
        else
          if entry.extensible, do: {:ok, :extensible}, else: {:error, :not_in_cid}
        end

      :error ->
        {:error, :unknown_cid}
    end
  end

  @doc """
  Returns `true` if the code is valid for the given CID.

  A code is valid if it is a defined member or the CID is extensible.
  """
  @spec valid?(Code.t(), non_neg_integer()) :: boolean()
  def valid?(%Code{} = code, cid) do
    case validate(code, cid) do
      :ok -> true
      {:ok, :extensible} -> true
      _ -> false
    end
  end

  @doc "Returns the name of a context group."
  @spec name(non_neg_integer()) :: {:ok, String.t()} | :error
  def name(cid) do
    case Registry.lookup(cid) do
      {:ok, entry} -> {:ok, entry.name}
      :error -> :error
    end
  end

  @doc "Returns whether a context group is extensible."
  @spec extensible?(non_neg_integer()) :: boolean() | :error
  def extensible?(cid) do
    case Registry.lookup(cid) do
      {:ok, entry} -> entry.extensible
      :error -> :error
    end
  end

  @doc "Returns the number of context groups in the registry."
  @spec size() :: non_neg_integer()
  def size, do: Registry.size()
end
