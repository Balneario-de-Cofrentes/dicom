defmodule Dicom.PrivateTag do
  @moduledoc """
  Private tag validation per DICOM PS3.6 Section 6.1.2.1.

  Private tags use odd-numbered groups (excluding 0x0001). Within each
  private group, a "block" is identified by a creator element at
  `(gggg,00xx)` where `xx` ranges from `0x10` to `0xFF`. The creator
  element has VR LO and its value identifies the definer of the block.

  Private data elements in block `xx` occupy `(gggg,xx00)` through
  `(gggg,xxFF)`. Every private data element must have a corresponding
  creator element for the data set to be valid.

  ## Examples

      iex> Dicom.PrivateTag.private?({0x0009, 0x1001})
      true

      iex> Dicom.PrivateTag.private_block({0x0009, 0x1001})
      16

      iex> Dicom.PrivateTag.creator_tag({0x0009, 0x1001})
      {0x0009, 0x0010}
  """

  alias Dicom.DataSet

  @type tag :: Dicom.DataElement.tag()

  @doc """
  Returns true if the tag is in a private group.

  Private groups have odd group numbers, excluding group 0x0001
  (the DICOM Command group).
  """
  @spec private?(tag()) :: boolean()
  def private?({0x0001, _element}), do: false
  def private?({group, _element}) when is_integer(group), do: rem(group, 2) == 1

  @doc """
  Returns true if the tag is a private creator element.

  Creator elements occupy element numbers 0x0010 through 0x00FF within
  a private (odd) group.
  """
  @spec creator_element?(tag()) :: boolean()
  def creator_element?({group, element})
      when is_integer(group) and is_integer(element) do
    private?({group, element}) and element >= 0x0010 and element <= 0x00FF
  end

  @doc """
  Extracts the block number from a private tag's element number.

  For creator elements `(gggg,00xx)` the block is `xx`.
  For data elements `(gggg,xxyy)` the block is the high byte `xx`.
  """
  @spec private_block(tag()) :: non_neg_integer()
  def private_block({_group, element}) when is_integer(element) and element <= 0x00FF do
    element
  end

  def private_block({_group, element}) when is_integer(element) do
    Bitwise.bsr(element, 8) |> Bitwise.band(0xFF)
  end

  @doc """
  Returns the creator tag for a given private tag.

  For a data element `(gggg,xxyy)`, the creator is `(gggg,00xx)`.
  For a creator element `(gggg,00xx)`, returns the tag unchanged.
  """
  @spec creator_tag(tag()) :: tag()
  def creator_tag({group, element}) when is_integer(group) and is_integer(element) do
    block = private_block({group, element})
    {group, block}
  end

  @doc """
  Returns the creator string for a private data element, or nil.

  Looks up the creator element `(gggg,00xx)` in the data set and returns
  its value. Returns nil if the tag is not private or the creator is absent.
  """
  @spec creator_for(DataSet.t(), tag()) :: String.t() | nil
  def creator_for(%DataSet{} = ds, {_group, _element} = tag) do
    if private?(tag) do
      DataSet.get(ds, creator_tag(tag))
    end
  end

  @doc """
  Validates that every private data element has a corresponding creator.

  Scans all elements in the data set. For each private data element
  (element > 0x00FF in an odd group), checks that a creator element
  exists at `(gggg,00xx)`.

  Returns `{:ok, data_set}` when all creators are present, or
  `{:error, [{tag, :missing_creator}]}` listing every orphaned element.
  """
  @spec validate_creators(DataSet.t()) ::
          {:ok, DataSet.t()} | {:error, [{tag(), :missing_creator}]}
  def validate_creators(%DataSet{} = ds) do
    missing =
      ds.elements
      |> Enum.filter(fn {{group, element}, _de} ->
        private?({group, element}) and element > 0x00FF
      end)
      |> Enum.reject(fn {{_group, _element} = tag, _de} ->
        DataSet.has_tag?(ds, creator_tag(tag))
      end)
      |> Enum.map(fn {tag, _de} -> {tag, :missing_creator} end)
      |> Enum.sort_by(fn {tag, _} -> tag end)

    case missing do
      [] -> {:ok, ds}
      _ -> {:error, missing}
    end
  end
end
