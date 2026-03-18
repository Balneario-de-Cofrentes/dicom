defmodule Dicom.P10.WriterTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataElement, DataSet}

  import Dicom.TestHelpers, only: [minimal_data_set: 0]

  describe "serialize/1" do
    test "produces valid P10 binary with preamble and DICM prefix" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      # 128-byte preamble + 4-byte DICM
      assert byte_size(binary) >= 132
      assert binary_part(binary, 0, 128) == <<0::1024>>
      assert binary_part(binary, 128, 4) == "DICM"
    end

    test "auto-generates File Meta Information Group Length (0002,0000)" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      # Parse the result back — group length must be present
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)
      group_length = DataSet.get(parsed, {0x0002, 0x0000})
      assert is_binary(group_length) or is_integer(group_length)
    end

    test "auto-generates File Meta Information Version (0002,0001)" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      {:ok, parsed} = Dicom.P10.Reader.parse(binary)
      version = DataSet.get(parsed, {0x0002, 0x0001})
      assert version == <<0x00, 0x01>>
    end

    test "auto-generates Implementation Class UID (0002,0012)" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      {:ok, parsed} = Dicom.P10.Reader.parse(binary)
      impl_uid = DataSet.get(parsed, {0x0002, 0x0012})
      assert is_binary(impl_uid) and byte_size(impl_uid) > 0
    end

    test "pads odd-length string values with space" do
      ds =
        minimal_data_set()
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE")

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      # "DOE" has odd length 3, should be padded to 4 with space
      raw_value = get_raw_element(parsed, {0x0010, 0x0010})
      assert rem(byte_size(raw_value), 2) == 0
    end

    test "pads odd-length UI values with null byte" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      # All UI values in file meta should have even length
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)
      raw_ts = get_raw_element(parsed, {0x0002, 0x0010})
      assert rem(byte_size(raw_ts), 2) == 0
    end

    test "roundtrips a data set through write and read" do
      ds =
        minimal_data_set()
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
        |> DataSet.put({0x0010, 0x0020}, :LO, "12345")
        |> DataSet.put({0x0020, 0x000D}, :UI, "1.2.3.4.5.6.7.8.9")
        |> DataSet.put({0x0008, 0x0060}, :CS, "CT")

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      assert DataSet.get(parsed, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
      assert DataSet.get(parsed, {0x0010, 0x0020}) |> String.trim() == "12345"
      assert DataSet.get(parsed, {0x0008, 0x0060}) |> String.trim() == "CT"
    end

    test "File Meta elements are always Explicit VR Little Endian" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      # Skip preamble + DICM, check first file meta element has VR bytes
      <<_preamble::binary-size(128), "DICM", rest::binary>> = binary

      # First element should be (0002,0000) with UL VR
      <<0x02, 0x00, 0x00, 0x00, "UL", _::binary>> = rest
    end

    test "returns an error when required File Meta Information is missing" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5")

      assert {:error, {:missing_required_meta, {0x0002, 0x0010}}} =
               Dicom.P10.Writer.serialize(ds)
    end

    test "returns an error when a required UID value is empty" do
      ds = put_file_meta(minimal_data_set(), {0x0002, 0x0010}, :UI, "")

      assert {:error, {:invalid_meta_value, {0x0002, 0x0010}}} =
               Dicom.P10.Writer.serialize(ds)
    end

    test "returns an error when a required UID value is not valid" do
      ds = put_file_meta(minimal_data_set(), {0x0002, 0x0003}, :UI, "not-a-uid")

      assert {:error, {:invalid_uid_in_file_meta, {0x0002, 0x0003}}} =
               Dicom.P10.Writer.serialize(ds)
    end

    test "returns a structured error for invalid element value shapes" do
      ds =
        minimal_data_set()
        |> then(fn ds ->
          elem = DataElement.new({0x0010, 0x0010}, :PN, %{bad: :shape})
          %{ds | elements: Map.put(ds.elements, {0x0010, 0x0010}, elem)}
        end)

      assert {:error, {:invalid_element_value, {0x0010, 0x0010}, :PN, Protocol.UndefinedError}} =
               Dicom.P10.Writer.serialize(ds)
    end

    test "returns a structured error for unsupported numeric element values" do
      ds =
        minimal_data_set()
        |> then(fn ds ->
          elem = DataElement.new({0x0028, 0x0010}, :US, [1, 2])
          %{ds | elements: Map.put(ds.elements, {0x0028, 0x0010}, elem)}
        end)

      assert {:error, {:invalid_element_value, {0x0028, 0x0010}, :US, ArgumentError}} =
               Dicom.P10.Writer.serialize(ds)
    end

    test "returns an error when compressed transfer syntax uses native Pixel Data" do
      ds =
        minimal_data_set()
        |> put_file_meta({0x0002, 0x0010}, :UI, Dicom.UID.jpeg_baseline())
        |> DataSet.put({0x7FE0, 0x0010}, :OB, <<1, 2, 3, 4>>)

      assert {:error,
              {:compressed_transfer_syntax_requires_encapsulated_pixel_data,
               "1.2.840.10008.1.2.4.50"}} =
               Dicom.P10.Writer.serialize(ds)
    end

    test "returns an error when uncompressed transfer syntax uses encapsulated Pixel Data" do
      ds =
        minimal_data_set()
        |> DataSet.put({0x7FE0, 0x0010}, :OB, {:encapsulated, [<<0::little-32>>, <<1, 2, 3, 4>>]})

      assert {:error,
              {:encapsulated_pixel_data_requires_compressed_transfer_syntax,
               "1.2.840.10008.1.2.1"}} =
               Dicom.P10.Writer.serialize(ds)
    end

    test "allows encapsulated Pixel Data with a compressed transfer syntax" do
      ds =
        minimal_data_set()
        |> put_file_meta({0x0002, 0x0010}, :UI, Dicom.UID.jpeg_baseline())
        |> DataSet.put({0x7FE0, 0x0010}, :OB, {:encapsulated, [<<0::little-32>>, <<1, 2, 3, 4>>]})

      assert {:ok, _binary} = Dicom.P10.Writer.serialize(ds)
    end

    test "returns an error when encapsulated Pixel Data uses VR other than OB" do
      ds =
        minimal_data_set()
        |> put_file_meta({0x0002, 0x0010}, :UI, Dicom.UID.jpeg_baseline())
        |> DataSet.put({0x7FE0, 0x0010}, :OW, {:encapsulated, [<<0::little-32>>, <<1, 2, 3, 4>>]})

      assert {:error, {:invalid_encapsulated_pixel_data_vr, :OW}} =
               Dicom.P10.Writer.serialize(ds)
    end

    test "returns an error when encapsulated Pixel Data fragments have odd length" do
      ds =
        minimal_data_set()
        |> put_file_meta({0x0002, 0x0010}, :UI, Dicom.UID.jpeg_baseline())
        |> DataSet.put({0x7FE0, 0x0010}, :OB, {:encapsulated, [<<0::little-32>>, <<1, 2, 3>>]})

      assert {:error, {:invalid_encapsulated_fragment_length, 1}} =
               Dicom.P10.Writer.serialize(ds)
    end

    test "returns an error when encapsulated Pixel Data BOT is not a multiple of four bytes" do
      ds =
        minimal_data_set()
        |> put_file_meta({0x0002, 0x0010}, :UI, Dicom.UID.jpeg_baseline())
        |> DataSet.put({0x7FE0, 0x0010}, :OB, {:encapsulated, [<<0, 1>>, <<1, 2, 3, 4>>]})

      assert {:error, :invalid_basic_offset_table} = Dicom.P10.Writer.serialize(ds)
    end

    test "returns an error when BOT offset count does not match NumberOfFrames" do
      ds =
        minimal_data_set()
        |> put_file_meta({0x0002, 0x0010}, :UI, Dicom.UID.jpeg_baseline())
        |> DataSet.put({0x0028, 0x0008}, :IS, "2")
        |> DataSet.put(
          {0x7FE0, 0x0010},
          :OB,
          {:encapsulated, [<<0::little-32>>, <<1, 2, 3, 4>>, <<5, 6, 7, 8>>]}
        )

      assert {:error, :invalid_basic_offset_table} = Dicom.P10.Writer.serialize(ds)
    end

    test "returns an error when BOT offsets do not start at fragment boundaries" do
      ds =
        minimal_data_set()
        |> put_file_meta({0x0002, 0x0010}, :UI, Dicom.UID.jpeg_baseline())
        |> DataSet.put({0x0028, 0x0008}, :IS, "2")
        |> DataSet.put(
          {0x7FE0, 0x0010},
          :OB,
          {:encapsulated, [<<2::little-32, 10::little-32>>, <<1, 2>>, <<3, 4>>]}
        )

      assert {:error, :invalid_basic_offset_table} = Dicom.P10.Writer.serialize(ds)
    end

    test "returns an error for compressed Pixel Data binaries that only mimic encapsulated framing" do
      raw = <<0xFE, 0xFF, 0x00, 0xE0, 0::little-32, 0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>

      ds =
        minimal_data_set()
        |> put_file_meta({0x0002, 0x0010}, :UI, Dicom.UID.jpeg_baseline())
        |> DataSet.put({0x7FE0, 0x0010}, :OB, raw)

      assert {:error,
              {:compressed_transfer_syntax_requires_encapsulated_pixel_data,
               "1.2.840.10008.1.2.4.50"}} = Dicom.P10.Writer.serialize(ds)
    end
  end

  describe "validate_file_meta/1" do
    test "returns :ok for valid file meta" do
      ds = minimal_data_set()
      assert :ok = Dicom.P10.Writer.validate_file_meta(ds)
    end

    test "returns error when Transfer Syntax UID is missing" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5")

      assert {:error, {:missing_required_meta, {0x0002, 0x0010}}} =
               Dicom.P10.Writer.validate_file_meta(ds)
    end

    test "returns error when Media Storage SOP Class UID is missing" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5")
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      assert {:error, {:missing_required_meta, {0x0002, 0x0002}}} =
               Dicom.P10.Writer.validate_file_meta(ds)
    end

    test "returns error when Media Storage SOP Instance UID is missing" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      assert {:error, {:missing_required_meta, {0x0002, 0x0003}}} =
               Dicom.P10.Writer.validate_file_meta(ds)
    end

    test "returns error when a required UID value is empty" do
      ds = put_file_meta(minimal_data_set(), {0x0002, 0x0010}, :UI, "")

      assert {:error, {:invalid_meta_value, {0x0002, 0x0010}}} =
               Dicom.P10.Writer.validate_file_meta(ds)
    end

    test "returns error when a required UID has the wrong VR" do
      ds = put_file_meta(minimal_data_set(), {0x0002, 0x0002}, :LO, "1.2.840.10008.5.1.4.1.1.2")

      assert {:error, {:invalid_meta_vr, {0x0002, 0x0002}, :UI}} =
               Dicom.P10.Writer.validate_file_meta(ds)
    end

    test "returns error when a required UID value is invalid" do
      ds = put_file_meta(minimal_data_set(), {0x0002, 0x0003}, :UI, "not-a-uid")

      assert {:error, {:invalid_uid_in_file_meta, {0x0002, 0x0003}}} =
               Dicom.P10.Writer.validate_file_meta(ds)
    end

    test "returns error when UN VR is used in file meta (PS3.10 7.1)" do
      ds = minimal_data_set()
      # Add a UN VR element to file meta
      un_elem = DataElement.new({0x0002, 0x0016}, :UN, "BADSCANNER")
      ds = %{ds | file_meta: Map.put(ds.file_meta, {0x0002, 0x0016}, un_elem)}

      assert {:error, {:un_vr_in_file_meta, {0x0002, 0x0016}}} =
               Dicom.P10.Writer.validate_file_meta(ds)
    end

    test "returns error when Private Information (0002,0102) present without Creator UID (0002,0100)" do
      ds = minimal_data_set()
      pi_elem = DataElement.new({0x0002, 0x0102}, :OB, <<1, 2, 3, 4>>)
      ds = %{ds | file_meta: Map.put(ds.file_meta, {0x0002, 0x0102}, pi_elem)}

      assert {:error, {:missing_private_information_creator, {0x0002, 0x0102}}} =
               Dicom.P10.Writer.validate_file_meta(ds)
    end

    test "accepts Private Information when Creator UID is also present" do
      ds = minimal_data_set()
      creator_elem = DataElement.new({0x0002, 0x0100}, :UI, "1.2.3.4.5.6.7.8.9")
      pi_elem = DataElement.new({0x0002, 0x0102}, :OB, <<1, 2, 3, 4>>)

      ds = %{
        ds
        | file_meta:
            ds.file_meta
            |> Map.put({0x0002, 0x0100}, creator_elem)
            |> Map.put({0x0002, 0x0102}, pi_elem)
      }

      assert :ok = Dicom.P10.Writer.validate_file_meta(ds)
    end

    test "returns error when Private Information Creator UID is invalid" do
      ds = minimal_data_set()
      creator_elem = DataElement.new({0x0002, 0x0100}, :UI, "not-a-uid")
      pi_elem = DataElement.new({0x0002, 0x0102}, :OB, <<1, 2, 3, 4>>)

      ds = %{
        ds
        | file_meta:
            ds.file_meta
            |> Map.put({0x0002, 0x0100}, creator_elem)
            |> Map.put({0x0002, 0x0102}, pi_elem)
      }

      assert {:error, {:invalid_uid_in_file_meta, {0x0002, 0x0100}}} =
               Dicom.P10.Writer.validate_file_meta(ds)
    end
  end

  describe "implicit VR encoding" do
    test "roundtrips sequence in Implicit VR Little Endian" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
        |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.implicit_vr_little_endian())

      # Add a sequence element
      inner_elem = DataElement.new({0x0008, 0x1150}, :UI, "1.2.3")
      sq_items = [%{{0x0008, 0x1150} => inner_elem}]
      sq_elem = DataElement.new({0x0008, 0x1140}, :SQ, sq_items)
      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x1140}, sq_elem)}

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      seq = DataSet.get(parsed, {0x0008, 0x1140})
      assert is_list(seq)
      assert length(seq) == 1
    end
  end

  describe "to_binary value encoding" do
    test "encodes integer values according to the VR width" do
      ds =
        minimal_data_set()

      # Put a DataElement with raw integer value
      int_elem = DataElement.new({0x0028, 0x0010}, :US, 512)
      ds = %{ds | elements: Map.put(ds.elements, {0x0028, 0x0010}, int_elem)}

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      raw = parsed.elements[{0x0028, 0x0010}].value
      assert raw == <<512::little-16>>
    end

    test "encodes non-binary non-integer values via to_string" do
      ds = minimal_data_set()

      # Put a DataElement with an atom value — to_string will convert
      atom_elem = DataElement.new({0x0010, 0x0010}, :PN, :test_name)
      ds = %{ds | elements: Map.put(ds.elements, {0x0010, 0x0010}, atom_elem)}

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      assert DataSet.get(parsed, {0x0010, 0x0010}) |> String.trim() == "test_name"
    end

    test "encodes integer values using transfer syntax endianness" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
        |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_big_endian())

      int_elem = DataElement.new({0x0028, 0x0010}, :US, 512)
      ds = %{ds | elements: Map.put(ds.elements, {0x0028, 0x0010}, int_elem)}

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      raw = parsed.elements[{0x0028, 0x0010}].value
      assert raw == <<512::big-16>>
    end
  end

  # Helpers

  defp get_raw_element(%DataSet{} = ds, tag) do
    {group, _} = tag
    source = if group == 0x0002, do: ds.file_meta, else: ds.elements

    case Map.get(source, tag) do
      %DataElement{value: value} -> value
      nil -> nil
    end
  end

  defp put_file_meta(%DataSet{} = ds, tag, vr, value) do
    %{ds | file_meta: Map.put(ds.file_meta, tag, DataElement.new(tag, vr, value))}
  end

  describe "implementation version name" do
    test "output binary contains DICOM_0.5.0 version name" do
      ds = minimal_data_set()
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      assert binary =~ "DICOM_0.5.0"
    end
  end
end
