defmodule Dicom.TestHelpers do
  @moduledoc false

  alias Dicom.DataSet

  @doc """
  Builds a minimal valid DataSet with the three required File Meta elements.

  Used across writer, reader, and compliance tests.
  """
  def minimal_data_set do
    DataSet.new()
    |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
    |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
    |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_little_endian())
  end

  @doc """
  Pads a binary value to even length with a null byte if needed.
  """
  def pad_to_even(value) when is_binary(value) do
    if rem(byte_size(value), 2) == 1 do
      value <> <<0>>
    else
      value
    end
  end

  @doc """
  Builds a complete Explicit VR element binary (Little Endian).
  Handles both short and long VR length formats.
  """
  def elem_explicit({group, element}, vr, value) do
    value_binary = pad_to_even(value)
    vr_str = Atom.to_string(vr)

    if Dicom.VR.long_length?(vr) do
      <<group::little-16, element::little-16>> <>
        vr_str <> <<0::16, byte_size(value_binary)::little-32>> <> value_binary
    else
      <<group::little-16, element::little-16>> <>
        vr_str <> <<byte_size(value_binary)::little-16>> <> value_binary
    end
  end

  @doc """
  Builds a File Meta Information Group Length element (0002,0000) for the given meta binary.
  """
  def build_group_length_element(meta_binary) when is_binary(meta_binary) do
    length_value = <<byte_size(meta_binary)::little-32>>
    <<0x02, 0x00, 0x00, 0x00, "UL", byte_size(length_value)::little-16>> <> length_value
  end

  def build_group_length_element(meta_elements) when is_list(meta_elements) do
    build_group_length_element(IO.iodata_to_binary(meta_elements))
  end

  @doc """
  Builds an Implicit VR element binary (Little Endian).
  Tag (4 bytes) + Length (4 bytes) + Value.
  """
  def elem_implicit({group, element}, value) do
    value_binary = pad_to_even(value)

    <<group::little-16, element::little-16, byte_size(value_binary)::little-32>> <> value_binary
  end

  @doc """
  Builds a complete encapsulated pixel data binary: BOT + fragments + sequence delimiter.
  Accepts a list of fragment binaries (first element is BOT data, rest are data fragments).
  """
  def build_encapsulated_fragments(fragments) when is_list(fragments) do
    items =
      Enum.map(fragments, fn fragment ->
        <<0xFE, 0xFF, 0x00, 0xE0, byte_size(fragment)::little-32>> <> fragment
      end)

    IO.iodata_to_binary([items, <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>])
  end

  @doc """
  Wraps data set binary content with a valid P10 preamble and Explicit VR LE file meta.
  """
  def build_p10_with_data(data_binary) do
    ts_uid = pad_to_even("1.2.840.10008.1.2.1")
    ts_elem = <<0x02, 0x00, 0x10, 0x00, "UI", byte_size(ts_uid)::little-16>> <> ts_uid
    group_length = build_group_length_element(ts_elem)

    <<0::1024, "DICM">> <> group_length <> ts_elem <> data_binary
  end
end
