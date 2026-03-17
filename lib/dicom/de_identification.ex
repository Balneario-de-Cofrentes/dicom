defmodule Dicom.DeIdentification do
  @moduledoc """
  DICOM De-identification / Anonymization (PS3.15 Table E.1-1).

  Implements the Basic Application Level Confidentiality Profile with
  10 option columns. Supports action codes D, Z, X, K, C, and U.

  ## Action Codes

  - **D** — Replace with dummy value (per VR)
  - **Z** — Replace with zero-length value
  - **X** — Remove the element
  - **K** — Keep (no change)
  - **C** — Clean (remove identifying text from descriptions)
  - **U** — Replace UID with consistent new UID

  ## Usage

      {:ok, deidentified, uid_map} = Dicom.DeIdentification.apply(data_set)

      # With options
      profile = %Dicom.DeIdentification.Profile{retain_uids: true}
      {:ok, result, uid_map} = Dicom.DeIdentification.apply(data_set, profile: profile)

  Reference: DICOM PS3.15 Annex E.
  """

  alias Dicom.{DataSet, DataElement, Tag, UID}

  @doc """
  Returns the Basic Application Level Confidentiality Profile with defaults.
  """
  @spec basic_profile() :: __MODULE__.Profile.t()
  def basic_profile, do: %__MODULE__.Profile{}

  @doc """
  Applies de-identification to a data set.

  Returns `{:ok, deidentified_data_set, uid_map}` where `uid_map` maps
  original UIDs to their replacements.

  ## Options

  - `profile` — a `DeIdentification.Profile` struct (default: `basic_profile()`)
  """
  @spec apply(DataSet.t(), keyword()) :: {:ok, DataSet.t(), map()}
  def apply(%DataSet{} = ds, opts \\ []) do
    profile = Keyword.get(opts, :profile, basic_profile())
    uid_map = %{}

    {ds, uid_map} = process_elements(ds, profile, uid_map)
    ds = strip_private_tags(ds, profile)
    ds = add_deidentification_markers(ds, profile)

    {:ok, ds, uid_map}
  end

  @doc """
  Returns the action code for a tag given a profile.
  """
  @spec action_for(Tag.t(), __MODULE__.Profile.t()) :: :D | :Z | :X | :K | :C | :U
  def action_for(tag, %__MODULE__.Profile{} = profile) do
    case tag_action(tag) do
      :U -> if profile.retain_uids, do: :K, else: :U
      :X_or_C -> if profile.clean_descriptions, do: :C, else: :X
      action -> action
    end
  end

  # ── Tag → Action mapping (PS3.15 Table E.1-1 subset) ──────────
  # D = dummy, Z = zero, X = remove, K = keep, U = replace UID
  # X_or_C = remove by default, clean if clean_descriptions option

  # Patient identifying
  defp tag_action({0x0010, 0x0010}), do: :D
  defp tag_action({0x0010, 0x0020}), do: :Z
  defp tag_action({0x0010, 0x0030}), do: :Z
  defp tag_action({0x0010, 0x0040}), do: :Z
  defp tag_action({0x0010, 0x1010}), do: :X
  defp tag_action({0x0010, 0x1020}), do: :X
  defp tag_action({0x0010, 0x1030}), do: :X
  defp tag_action({0x0010, 0x1000}), do: :X
  defp tag_action({0x0010, 0x1001}), do: :X
  defp tag_action({0x0010, 0x2160}), do: :X
  defp tag_action({0x0010, 0x21B0}), do: :X

  # Study identifying
  defp tag_action({0x0008, 0x0050}), do: :Z
  defp tag_action({0x0008, 0x0090}), do: :X
  defp tag_action({0x0008, 0x0080}), do: :X
  defp tag_action({0x0008, 0x0081}), do: :X
  defp tag_action({0x0008, 0x1010}), do: :X
  defp tag_action({0x0008, 0x1040}), do: :X
  defp tag_action({0x0008, 0x1048}), do: :X
  defp tag_action({0x0008, 0x1050}), do: :X
  defp tag_action({0x0008, 0x1070}), do: :X

  # Descriptions (X or C depending on profile)
  defp tag_action({0x0008, 0x1030}), do: :X_or_C
  defp tag_action({0x0008, 0x103E}), do: :X_or_C
  defp tag_action({0x0008, 0x1090}), do: :X_or_C
  defp tag_action({0x0020, 0x4000}), do: :X_or_C

  # UIDs
  defp tag_action({0x0008, 0x0018}), do: :U
  defp tag_action({0x0020, 0x000D}), do: :U
  defp tag_action({0x0020, 0x000E}), do: :U
  defp tag_action({0x0008, 0x0016}), do: :K
  defp tag_action({0x0008, 0x1150}), do: :U
  defp tag_action({0x0008, 0x1155}), do: :U

  # Keep: structural/non-identifying
  defp tag_action({0x0008, 0x0060}), do: :K
  defp tag_action({0x0008, 0x0008}), do: :K
  defp tag_action({0x0020, 0x0013}), do: :K
  defp tag_action({0x0020, 0x0011}), do: :K
  defp tag_action({0x0020, 0x0010}), do: :K
  defp tag_action({0x0028, _}), do: :K
  defp tag_action({0x7FE0, _}), do: :K
  defp tag_action({0x0020, 0x0032}), do: :K
  defp tag_action({0x0020, 0x0037}), do: :K
  defp tag_action({0x0020, 0x0052}), do: :K
  defp tag_action({0x0020, 0x1041}), do: :K
  defp tag_action({0x0018, _}), do: :K

  # File Meta: keep
  defp tag_action({0x0002, _}), do: :K

  # De-identification markers: keep
  defp tag_action({0x0012, _}), do: :K

  # Dates
  defp tag_action({0x0008, 0x0020}), do: :Z
  defp tag_action({0x0008, 0x0021}), do: :X
  defp tag_action({0x0008, 0x0022}), do: :X
  defp tag_action({0x0008, 0x0023}), do: :X
  defp tag_action({0x0008, 0x0030}), do: :Z
  defp tag_action({0x0008, 0x0031}), do: :X
  defp tag_action({0x0008, 0x0032}), do: :X
  defp tag_action({0x0008, 0x0033}), do: :X
  defp tag_action({0x0008, 0x002A}), do: :X

  # Default: remove unknown
  defp tag_action(_), do: :X

  # ── Processing pipeline ───────────────────────────────────────

  defp process_elements(%DataSet{} = ds, profile, uid_map) do
    {new_elements, uid_map} =
      Enum.reduce(ds.elements, {%{}, uid_map}, fn {tag, elem}, {acc, umap} ->
        # SQ elements are always kept and recursed into
        if elem.vr == :SQ and is_list(elem.value) do
          {new_items, umap} = deidentify_sequence(elem.value, profile, umap)
          {Map.put(acc, tag, %{elem | value: new_items}), umap}
        else
          action = action_for(tag, profile)
          {new_elem, umap} = apply_action(action, elem, profile, umap)

          case new_elem do
            nil -> {acc, umap}
            elem -> {Map.put(acc, tag, elem), umap}
          end
        end
      end)

    {%{ds | elements: new_elements}, uid_map}
  end

  defp apply_action(:D, %DataElement{} = elem, _profile, uid_map) do
    {%{elem | value: dummy_value(elem.vr), length: 0}, uid_map}
  end

  defp apply_action(:Z, %DataElement{} = elem, _profile, uid_map) do
    {%{elem | value: "", length: 0}, uid_map}
  end

  defp apply_action(:X, _elem, _profile, uid_map) do
    {nil, uid_map}
  end

  defp apply_action(:K, %DataElement{vr: :SQ, value: items} = elem, profile, uid_map)
       when is_list(items) do
    {new_items, uid_map} = deidentify_sequence(items, profile, uid_map)
    {%{elem | value: new_items}, uid_map}
  end

  defp apply_action(:K, elem, _profile, uid_map) do
    {elem, uid_map}
  end

  defp apply_action(:C, %DataElement{} = elem, _profile, uid_map) do
    {%{elem | value: "CLEANED", length: 7}, uid_map}
  end

  defp apply_action(:U, %DataElement{value: value} = elem, _profile, uid_map)
       when is_binary(value) do
    uid = String.trim_trailing(value, <<0>>)

    {new_uid, uid_map} =
      case Map.get(uid_map, uid) do
        nil ->
          generated = UID.generate()
          {generated, Map.put(uid_map, uid, generated)}

        existing ->
          {existing, uid_map}
      end

    {%{elem | value: new_uid, length: byte_size(new_uid)}, uid_map}
  end

  defp apply_action(:U, elem, _profile, uid_map) do
    {elem, uid_map}
  end

  defp deidentify_sequence(items, profile, uid_map) do
    Enum.map_reduce(items, uid_map, fn item, umap ->
      {new_item, umap} =
        Enum.reduce(item, {%{}, umap}, fn {tag, elem}, {acc, umap} ->
          action = action_for(tag, profile)
          {new_elem, umap} = apply_action(action, elem, profile, umap)

          case new_elem do
            nil -> {acc, umap}
            elem -> {Map.put(acc, tag, elem), umap}
          end
        end)

      {new_item, umap}
    end)
  end

  defp strip_private_tags(%DataSet{} = ds, %__MODULE__.Profile{retain_safe_private: true}), do: ds

  defp strip_private_tags(%DataSet{} = ds, _profile) do
    elements =
      ds.elements
      |> Enum.reject(fn {{group, _}, _} -> rem(group, 2) == 1 end)
      |> Map.new()

    %{ds | elements: elements}
  end

  defp add_deidentification_markers(%DataSet{} = ds, _profile) do
    ds
    |> DataSet.put({0x0012, 0x0062}, :CS, "YES")
    |> DataSet.put({0x0012, 0x0063}, :LO, "Basic Application Level Confidentiality Profile")
  end

  # ── Dummy values per VR ───────────────────────────────────────

  defp dummy_value(:PN), do: "ANONYMOUS"
  defp dummy_value(:DA), do: "19000101"
  defp dummy_value(:TM), do: "000000"
  defp dummy_value(:DT), do: "19000101000000.000000"
  defp dummy_value(:LO), do: "ANONYMOUS"
  defp dummy_value(:SH), do: "ANON"
  defp dummy_value(:CS), do: "ANON"
  defp dummy_value(:AS), do: "000Y"
  defp dummy_value(:DS), do: "0"
  defp dummy_value(:IS), do: "0"
  defp dummy_value(:UI), do: UID.generate()
  defp dummy_value(_), do: ""
end
