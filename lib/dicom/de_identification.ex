defmodule Dicom.DeIdentification do
  @moduledoc """
  DICOM De-identification / Anonymization (PS3.15 Table E.1-1).

  Implements a best-effort Basic Application Level Confidentiality Profile
  for the supported tag set, with 10 profile flags that affect behavior.
  Supports action codes D, Z, X, K, C, and U.

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
  Returns the default de-identification profile.
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
  @spec action_for(Tag.t(), __MODULE__.Profile.t()) :: :D | :Z | :X | :K | :C | :U | :M
  def action_for(tag, %__MODULE__.Profile{} = profile) do
    tag
    |> tag_action()
    |> apply_profile_overrides(tag, profile)
  end

  # ── Tag → Action mapping (PS3.15 Table E.1-1) ────────────────
  # D = dummy, Z = zero, X = remove, K = keep, U = replace UID
  # X_or_C = remove by default, clean if clean_descriptions option
  #
  # For compound actions (X/Z, Z/D, X/Z/D, X/D):
  #   Z/D → D (more informative for downstream systems)
  #   X/Z → X (more conservative)
  #   X/D → X (more conservative)
  #   X/Z/D → X (more conservative)

  # ── Patient identifying ─────────────────────────────────────
  defp tag_action({0x0010, 0x0010}), do: :D
  defp tag_action({0x0010, 0x0020}), do: :Z
  defp tag_action({0x0010, 0x0030}), do: :Z
  defp tag_action({0x0010, 0x0032}), do: :X
  defp tag_action({0x0010, 0x0040}), do: :Z
  defp tag_action({0x0010, 0x1010}), do: :X
  defp tag_action({0x0010, 0x1020}), do: :X
  defp tag_action({0x0010, 0x1030}), do: :X
  defp tag_action({0x0010, 0x1000}), do: :X
  defp tag_action({0x0010, 0x1001}), do: :X
  defp tag_action({0x0010, 0x1002}), do: :X
  defp tag_action({0x0010, 0x1005}), do: :X
  defp tag_action({0x0010, 0x1040}), do: :X
  defp tag_action({0x0010, 0x1050}), do: :X
  defp tag_action({0x0010, 0x1060}), do: :X
  defp tag_action({0x0010, 0x1080}), do: :X
  defp tag_action({0x0010, 0x1081}), do: :X
  defp tag_action({0x0010, 0x1090}), do: :X
  defp tag_action({0x0010, 0x2000}), do: :X
  defp tag_action({0x0010, 0x2110}), do: :X
  defp tag_action({0x0010, 0x2150}), do: :X
  defp tag_action({0x0010, 0x2152}), do: :X
  defp tag_action({0x0010, 0x2154}), do: :X
  defp tag_action({0x0010, 0x2155}), do: :X
  defp tag_action({0x0010, 0x2160}), do: :X
  defp tag_action({0x0010, 0x2180}), do: :X
  defp tag_action({0x0010, 0x21A0}), do: :X
  defp tag_action({0x0010, 0x21B0}), do: :X
  defp tag_action({0x0010, 0x21C0}), do: :X
  defp tag_action({0x0010, 0x21D0}), do: :X
  defp tag_action({0x0010, 0x21F0}), do: :X
  defp tag_action({0x0010, 0x2203}), do: :X
  defp tag_action({0x0010, 0x2297}), do: :X
  defp tag_action({0x0010, 0x2299}), do: :X
  defp tag_action({0x0010, 0x4000}), do: :X
  defp tag_action({0x0010, 0x0050}), do: :X
  defp tag_action({0x0010, 0x1100}), do: :X

  # ── Study/Series identifying ────────────────────────────────
  defp tag_action({0x0008, 0x0050}), do: :Z
  defp tag_action({0x0008, 0x0090}), do: :Z
  defp tag_action({0x0008, 0x0092}), do: :X
  defp tag_action({0x0008, 0x0094}), do: :X
  defp tag_action({0x0008, 0x0096}), do: :X
  defp tag_action({0x0008, 0x009C}), do: :Z
  defp tag_action({0x0008, 0x009D}), do: :X
  defp tag_action({0x0008, 0x0080}), do: :X
  defp tag_action({0x0008, 0x0081}), do: :X
  defp tag_action({0x0008, 0x0082}), do: :X
  defp tag_action({0x0008, 0x1010}), do: :X
  defp tag_action({0x0008, 0x1040}), do: :X
  defp tag_action({0x0008, 0x1041}), do: :X
  defp tag_action({0x0008, 0x1048}), do: :X
  defp tag_action({0x0008, 0x1049}), do: :X
  defp tag_action({0x0008, 0x1050}), do: :X
  defp tag_action({0x0008, 0x1052}), do: :X
  defp tag_action({0x0008, 0x1060}), do: :X
  defp tag_action({0x0008, 0x1062}), do: :X
  defp tag_action({0x0008, 0x1070}), do: :X
  defp tag_action({0x0008, 0x1072}), do: :X
  defp tag_action({0x0008, 0x4000}), do: :X

  # ── Descriptions (X or C depending on profile) ──────────────
  defp tag_action({0x0008, 0x1030}), do: :X_or_C
  defp tag_action({0x0008, 0x103E}), do: :X_or_C
  defp tag_action({0x0008, 0x1090}), do: :X_or_C
  defp tag_action({0x0008, 0x2111}), do: :X
  defp tag_action({0x0020, 0x4000}), do: :X_or_C
  defp tag_action({0x0028, 0x4000}), do: :X
  defp tag_action({0x0040, 0x2400}), do: :X

  # ── UIDs — replace with consistent mapping ──────────────────
  defp tag_action({0x0008, 0x0014}), do: :U
  defp tag_action({0x0008, 0x0017}), do: :U
  defp tag_action({0x0008, 0x0018}), do: :U
  defp tag_action({0x0008, 0x0058}), do: :U
  defp tag_action({0x0008, 0x1150}), do: :U
  defp tag_action({0x0008, 0x1155}), do: :U
  defp tag_action({0x0008, 0x1195}), do: :U
  defp tag_action({0x0008, 0x3010}), do: :U
  defp tag_action({0x0008, 0x0016}), do: :K
  defp tag_action({0x0002, 0x0003}), do: :U
  defp tag_action({0x0004, 0x1511}), do: :U
  defp tag_action({0x0018, 0x1002}), do: :U
  defp tag_action({0x0018, 0x100B}), do: :U
  defp tag_action({0x0018, 0x2042}), do: :U
  defp tag_action({0x0020, 0x000D}), do: :U
  defp tag_action({0x0020, 0x000E}), do: :U
  defp tag_action({0x0020, 0x0052}), do: :U
  defp tag_action({0x0020, 0x0200}), do: :U
  defp tag_action({0x0020, 0x9161}), do: :U
  defp tag_action({0x0020, 0x9164}), do: :U
  defp tag_action({0x0028, 0x1199}), do: :U
  defp tag_action({0x0028, 0x1214}), do: :U
  defp tag_action({0x003A, 0x0310}), do: :U
  defp tag_action({0x0040, 0x0554}), do: :U
  defp tag_action({0x0040, 0x4023}), do: :U
  defp tag_action({0x0040, 0xA124}), do: :U
  defp tag_action({0x0040, 0xA171}), do: :U
  defp tag_action({0x0040, 0xA402}), do: :U
  defp tag_action({0x0040, 0xDB0C}), do: :U
  defp tag_action({0x0040, 0xDB0D}), do: :U
  defp tag_action({0x0062, 0x0021}), do: :U
  defp tag_action({0x0064, 0x0003}), do: :U
  defp tag_action({0x0070, 0x031A}), do: :U
  defp tag_action({0x0070, 0x1101}), do: :U
  defp tag_action({0x0070, 0x1102}), do: :U
  defp tag_action({0x0088, 0x0140}), do: :U
  defp tag_action({0x0400, 0x0100}), do: :U
  defp tag_action({0x3006, 0x0024}), do: :U
  defp tag_action({0x3006, 0x00C2}), do: :U
  defp tag_action({0x300A, 0x0013}), do: :U
  defp tag_action({0x300A, 0x0054}), do: :U
  defp tag_action({0x300A, 0x0609}), do: :U
  defp tag_action({0x300A, 0x0650}), do: :U
  defp tag_action({0x300A, 0x0700}), do: :U
  defp tag_action({0x3010, 0x0006}), do: :U
  defp tag_action({0x3010, 0x000B}), do: :U
  defp tag_action({0x3010, 0x0013}), do: :U
  defp tag_action({0x3010, 0x0015}), do: :U
  defp tag_action({0x3010, 0x003B}), do: :U
  defp tag_action({0x3010, 0x006E}), do: :U
  defp tag_action({0x3010, 0x006F}), do: :U

  # ── Content creator/observer ────────────────────────────────
  defp tag_action({0x0070, 0x0084}), do: :D
  defp tag_action({0x0070, 0x0086}), do: :X
  defp tag_action({0x0040, 0xA123}), do: :D
  defp tag_action({0x0040, 0xA160}), do: :X
  defp tag_action({0x0040, 0xA730}), do: :X
  defp tag_action({0x0040, 0x1101}), do: :D
  defp tag_action({0x0040, 0xA075}), do: :D
  defp tag_action({0x0040, 0xA073}), do: :D
  defp tag_action({0x0040, 0xA027}), do: :D
  defp tag_action({0x0040, 0xA088}), do: :Z
  defp tag_action({0x0040, 0xA030}), do: :D
  defp tag_action({0x0040, 0xA078}), do: :X
  defp tag_action({0x0040, 0xA082}), do: :Z
  defp tag_action({0x0040, 0xA07A}), do: :X

  # ── Keep: structural/non-identifying ────────────────────────
  defp tag_action({0x0008, 0x0060}), do: :K
  defp tag_action({0x0008, 0x0008}), do: :K
  defp tag_action({0x0020, 0x0013}), do: :K
  defp tag_action({0x0020, 0x0011}), do: :K
  defp tag_action({0x0020, 0x0010}), do: :Z
  defp tag_action({0x0020, 0x0032}), do: :K
  defp tag_action({0x0020, 0x0037}), do: :K
  defp tag_action({0x0020, 0x1041}), do: :K
  # Group 0028 (image parameters) — keep, except UIDs/comments handled above
  defp tag_action({0x0028, _}), do: :K
  # Group 7FE0 (pixel data) — keep
  defp tag_action({0x7FE0, _}), do: :K

  # ── Device identifiers in group 0018 (before wildcard) ──────
  defp tag_action({0x0018, 0x1000}), do: :X
  defp tag_action({0x0018, 0x1004}), do: :X
  defp tag_action({0x0018, 0x1005}), do: :X
  defp tag_action({0x0018, 0x1007}), do: :X
  defp tag_action({0x0018, 0x1008}), do: :X
  defp tag_action({0x0018, 0x1009}), do: :X
  defp tag_action({0x0018, 0x100A}), do: :X
  defp tag_action({0x0018, 0x1010}), do: :X
  defp tag_action({0x0018, 0x1011}), do: :X
  defp tag_action({0x0018, 0x1200}), do: :X
  defp tag_action({0x0018, 0x1201}), do: :X
  defp tag_action({0x0018, 0x1203}), do: :Z
  defp tag_action({0x0018, 0x1400}), do: :X
  defp tag_action({0x0018, 0x4000}), do: :X
  defp tag_action({0x0018, 0x9424}), do: :X
  defp tag_action({0x0018, 0x0010}), do: :D
  defp tag_action({0x0018, 0x0027}), do: :X
  defp tag_action({0x0018, 0x0035}), do: :X
  defp tag_action({0x0018, 0x1042}), do: :X
  defp tag_action({0x0018, 0x1043}), do: :X
  defp tag_action({0x0018, 0x1078}), do: :X
  defp tag_action({0x0018, 0x1079}), do: :X
  defp tag_action({0x0018, 0xA002}), do: :X
  defp tag_action({0x0018, 0xA003}), do: :X
  # Group 0018 wildcard — keep remaining acquisition parameters
  defp tag_action({0x0018, _}), do: :K

  # ── File Meta: keep (except MediaStorageSOPInstanceUID → U above) ──
  defp tag_action({0x0002, _}), do: :K

  # ── Clinical trial tags ─────────────────────────────────────
  defp tag_action({0x0012, 0x0010}), do: :D
  defp tag_action({0x0012, 0x0020}), do: :D
  defp tag_action({0x0012, 0x0021}), do: :Z
  defp tag_action({0x0012, 0x0030}), do: :Z
  defp tag_action({0x0012, 0x0031}), do: :Z
  defp tag_action({0x0012, 0x0040}), do: :D
  defp tag_action({0x0012, 0x0042}), do: :D
  defp tag_action({0x0012, 0x0050}), do: :Z
  defp tag_action({0x0012, 0x0051}), do: :X
  defp tag_action({0x0012, 0x0060}), do: :Z
  defp tag_action({0x0012, 0x0071}), do: :X
  defp tag_action({0x0012, 0x0072}), do: :X
  defp tag_action({0x0012, 0x0081}), do: :D
  defp tag_action({0x0012, 0x0082}), do: :X
  # De-identification markers: keep
  defp tag_action({0x0012, 0x0062}), do: :K
  defp tag_action({0x0012, 0x0063}), do: :K
  defp tag_action({0x0012, _}), do: :X

  # ── Dates and times ─────────────────────────────────────────
  defp tag_action({0x0008, 0x0020}), do: :Z
  defp tag_action({0x0008, 0x0021}), do: :X
  defp tag_action({0x0008, 0x0022}), do: :X
  defp tag_action({0x0008, 0x0023}), do: :D
  defp tag_action({0x0008, 0x0030}), do: :Z
  defp tag_action({0x0008, 0x0031}), do: :X
  defp tag_action({0x0008, 0x0032}), do: :X
  defp tag_action({0x0008, 0x0033}), do: :D
  defp tag_action({0x0008, 0x002A}), do: :X
  defp tag_action({0x0008, 0x0012}), do: :X
  defp tag_action({0x0008, 0x0013}), do: :X
  defp tag_action({0x0008, 0x0015}), do: :X

  # ── Procedure/scheduling ────────────────────────────────────
  defp tag_action({0x0032, _}), do: :X
  defp tag_action({0x0038, _}), do: :X
  defp tag_action({0x0040, 0x0006}), do: :X
  defp tag_action({0x0040, 0x0007}), do: :X
  defp tag_action({0x0040, 0x0241}), do: :X
  defp tag_action({0x0040, 0x0242}), do: :X
  defp tag_action({0x0040, 0x0243}), do: :X
  defp tag_action({0x0040, 0x0244}), do: :X
  defp tag_action({0x0040, 0x0245}), do: :X
  defp tag_action({0x0040, 0x0250}), do: :X
  defp tag_action({0x0040, 0x0251}), do: :X
  defp tag_action({0x0040, 0x0254}), do: :X
  defp tag_action({0x0040, 0x0275}), do: :X
  defp tag_action({0x0040, 0x0280}), do: :X
  defp tag_action({0x0040, 0x0310}), do: :X
  defp tag_action({0x0040, 0x1001}), do: :X
  defp tag_action({0x0040, 0x1010}), do: :X
  defp tag_action({0x0040, 0x1400}), do: :X
  defp tag_action({0x0040, 0x2001}), do: :X
  defp tag_action({0x0040, 0x2016}), do: :Z
  defp tag_action({0x0040, 0x2017}), do: :Z

  # ── Digital signatures ──────────────────────────────────────
  defp tag_action({0xFFFA, 0xFFFA}), do: :X
  defp tag_action({0x0400, 0x0310}), do: :X
  defp tag_action({0x0400, 0x0402}), do: :X
  defp tag_action({0x0400, 0x0403}), do: :X
  defp tag_action({0x0400, 0x0404}), do: :X
  defp tag_action({0x0400, 0x0550}), do: :X
  defp tag_action({0x0400, 0x0561}), do: :X
  defp tag_action({0x0400, 0x0115}), do: :D
  defp tag_action({0x0400, 0x0105}), do: :D
  defp tag_action({0x0400, 0x0562}), do: :D
  defp tag_action({0x0400, 0x0563}), do: :D
  defp tag_action({0x0400, 0x0565}), do: :D

  # ── Graphics/presentation ───────────────────────────────────
  defp tag_action({0x0070, 0x0001}), do: :D
  defp tag_action({0x0070, 0x0006}), do: :D
  defp tag_action({0x0070, 0x0008}), do: :X
  defp tag_action({0x0070, 0x0082}), do: :X
  defp tag_action({0x0070, 0x0083}), do: :X

  # ── Interpretation (retired) ────────────────────────────────
  defp tag_action({0x4008, _}), do: :X

  # ── Overlay/curve data ──────────────────────────────────────
  defp tag_action({g, _}) when g >= 0x5000 and g <= 0x50FF, do: :X
  defp tag_action({g, 0x4000}) when g >= 0x6000 and g <= 0x60FF, do: :X
  defp tag_action({g, 0x3000}) when g >= 0x6000 and g <= 0x60FF, do: :X

  # ── Radiotherapy ────────────────────────────────────────────
  defp tag_action({0x300A, 0x0002}), do: :D
  defp tag_action({0x300A, 0x0003}), do: :X
  defp tag_action({0x300A, 0x0004}), do: :X
  defp tag_action({0x300A, 0x0006}), do: :X
  defp tag_action({0x300A, 0x0007}), do: :X
  defp tag_action({0x300A, 0x000E}), do: :X
  defp tag_action({0x300A, 0x0016}), do: :X
  defp tag_action({0x300A, 0x00C3}), do: :X
  defp tag_action({0x3006, 0x0002}), do: :D
  defp tag_action({0x3006, 0x0004}), do: :X
  defp tag_action({0x3006, 0x0006}), do: :X
  defp tag_action({0x3006, 0x0008}), do: :Z
  defp tag_action({0x3006, 0x0009}), do: :Z
  defp tag_action({0x3006, 0x0026}), do: :Z
  defp tag_action({0x3006, 0x0028}), do: :X
  defp tag_action({0x3006, 0x0038}), do: :X
  defp tag_action({0x3006, 0x0085}), do: :X
  defp tag_action({0x3006, 0x0088}), do: :X
  defp tag_action({0x3006, 0x00A6}), do: :Z
  defp tag_action({0x3008, 0x0054}), do: :X
  defp tag_action({0x3008, 0x0056}), do: :X
  defp tag_action({0x3008, 0x0250}), do: :X
  defp tag_action({0x3008, 0x0251}), do: :X
  defp tag_action({0x300E, 0x0004}), do: :Z
  defp tag_action({0x300E, 0x0005}), do: :Z
  defp tag_action({0x300E, 0x0008}), do: :X

  # ── Specimen ────────────────────────────────────────────────
  defp tag_action({0x0040, 0x050A}), do: :X
  defp tag_action({0x0040, 0x0512}), do: :D
  defp tag_action({0x0040, 0x0513}), do: :Z
  defp tag_action({0x0040, 0x051A}), do: :X
  defp tag_action({0x0040, 0x0551}), do: :D
  defp tag_action({0x0040, 0x0562}), do: :Z
  defp tag_action({0x0040, 0x0600}), do: :X
  defp tag_action({0x0040, 0x0602}), do: :X
  defp tag_action({0x0040, 0x0610}), do: :Z

  # ── Referenced sequences ────────────────────────────────────
  defp tag_action({0x0008, 0x1110}), do: :X
  defp tag_action({0x0008, 0x1111}), do: :X
  defp tag_action({0x0008, 0x1120}), do: :X
  defp tag_action({0x0008, 0x1140}), do: :X

  # ── Trailing padding ────────────────────────────────────────
  defp tag_action({0xFFFC, 0xFFFC}), do: :X

  # ── Default: remove unknown ─────────────────────────────────
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
    dummy = dummy_value(elem.vr)
    {%{elem | value: dummy, length: byte_size(dummy)}, uid_map}
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
    cleaned = "CLEANED"
    {%{elem | value: cleaned, length: byte_size(cleaned)}, uid_map}
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

  defp apply_action(:M, %DataElement{} = elem, _profile, uid_map) do
    modified = modify_temporal_value(elem.value, elem.vr)
    {%{elem | value: modified, length: byte_size(modified)}, uid_map}
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
    %{ds | elements: Map.filter(ds.elements, fn {tag, _} -> not Tag.private?(tag) end)}
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

  defp apply_profile_overrides(:U, _tag, %__MODULE__.Profile{retain_uids: true}), do: :K

  defp apply_profile_overrides(:X_or_C, _tag, %__MODULE__.Profile{clean_descriptions: true}),
    do: :C

  defp apply_profile_overrides(:X_or_C, _tag, _profile), do: :X

  defp apply_profile_overrides(_action, {group, _}, %__MODULE__.Profile{retain_safe_private: true})
       when rem(group, 2) == 1,
       do: :K

  defp apply_profile_overrides(_action, tag, %__MODULE__.Profile{retain_device_identity: true})
       when tag in [
              {0x0008, 0x1010},
              {0x0008, 0x1090},
              {0x0018, 0x1000},
              {0x0018, 0x1004},
              {0x0018, 0x1005},
              {0x0018, 0x1007},
              {0x0018, 0x1008},
              {0x0018, 0x1009},
              {0x0018, 0x100A},
              {0x0018, 0x1010},
              {0x0018, 0x1011}
            ],
       do: :K

  defp apply_profile_overrides(
         _action,
         tag,
         %__MODULE__.Profile{retain_patient_characteristics: true}
       )
       when tag in [{0x0010, 0x0040}, {0x0010, 0x1010}],
       do: :K

  defp apply_profile_overrides(
         _action,
         tag,
         %__MODULE__.Profile{retain_institution_identity: true}
       )
       when tag in [{0x0008, 0x0080}, {0x0008, 0x0081}, {0x0008, 0x1040}],
       do: :K

  defp apply_profile_overrides(action, tag, %__MODULE__.Profile{retain_long_full_dates: true}) do
    if temporal_tag?(tag), do: :K, else: action
  end

  defp apply_profile_overrides(
         action,
         tag,
         %__MODULE__.Profile{retain_long_modified_dates: true}
       ) do
    if temporal_tag?(tag), do: :M, else: action
  end

  defp apply_profile_overrides(
         _action,
         tag,
         %__MODULE__.Profile{clean_structured_content: true}
       )
       when tag in [{0x0040, 0xA730}, {0x0040, 0xA010}, {0x0040, 0xA040}, {0x0040, 0xA043}],
       do: :K

  defp apply_profile_overrides(
         _action,
         tag,
         %__MODULE__.Profile{clean_structured_content: true}
       )
       when tag in [{0x0040, 0xA123}, {0x0040, 0xA124}, {0x0040, 0xA160}],
       do: :C

  defp apply_profile_overrides(_action, tag, %__MODULE__.Profile{clean_graphics: true})
       when tag in [{0x0070, 0x0001}, {0x0070, 0x0008}],
       do: :K

  defp apply_profile_overrides(_action, tag, %__MODULE__.Profile{clean_graphics: true})
       when tag == {0x0070, 0x0006},
       do: :C

  defp apply_profile_overrides(action, _tag, _profile), do: action

  defp temporal_tag?(tag) do
    tag in [
      {0x0008, 0x0012},
      {0x0008, 0x0013},
      {0x0008, 0x0015},
      {0x0008, 0x0020},
      {0x0008, 0x0021},
      {0x0008, 0x0022},
      {0x0008, 0x0023},
      {0x0008, 0x002A},
      {0x0008, 0x0030},
      {0x0008, 0x0031},
      {0x0008, 0x0032},
      {0x0008, 0x0033}
    ]
  end

  defp modify_temporal_value(value, vr) do
    decoded =
      case value do
        binary when is_binary(binary) -> Dicom.Value.decode(binary, vr)
        other -> other
      end

    case {vr, decoded} do
      {:DA, date} when is_binary(date) -> shift_date_string(date)
      {:DT, datetime} when is_binary(datetime) -> shift_datetime_string(datetime)
      {:TM, time} when is_binary(time) -> String.trim(time)
      _ -> ""
    end
  end

  defp shift_date_string(date) do
    shift_date_prefix(date)
  end

  defp shift_datetime_string(datetime) do
    trimmed = String.trim(datetime)

    if byte_size(trimmed) >= 8 do
      <<date_part::binary-size(8), rest::binary>> = trimmed
      shift_date_prefix(date_part) <> rest
    else
      trimmed
    end
  end

  defp shift_date_prefix(date) do
    trimmed = String.trim(date)

    case Dicom.Value.to_date(trimmed) do
      {:ok, parsed} ->
        parsed
        |> shift_date_years(-10)
        |> Dicom.Value.from_date()

      {:error, _} ->
        trimmed
    end
  end

  defp shift_date_years(%Date{year: year, month: month, day: day}, delta_years) do
    target_year = year + delta_years
    target_day = min(day, last_day_of_month(target_year, month))
    {:ok, shifted} = Date.new(target_year, month, target_day)
    shifted
  end

  defp last_day_of_month(year, month) do
    {:ok, start_of_month} = Date.new(year, month, 1)
    start_of_month |> Date.end_of_month() |> Map.fetch!(:day)
  end
end
