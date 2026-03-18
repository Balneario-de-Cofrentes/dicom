defmodule Dicom.P10.DeflatedTest do
  use ExUnit.Case, async: true

  alias Dicom.DataSet
  alias Dicom.P10.Deflated

  describe "Deflated Explicit VR Little Endian" do
    test "raw deflate helper roundtrips without a zlib wrapper" do
      data = IO.iodata_to_binary(List.duplicate("ABCD", 32))
      compressed = Deflated.compress(data)

      refute binary_part(compressed, 0, 2) == <<0x78, 0x9C>>
      assert {:ok, ^data} = Deflated.decompress(compressed)
    end

    test "raw deflate helper rejects invalid payloads" do
      assert {:error, :invalid_deflated_data} = Deflated.decompress(<<1, 2, 3, 4, 5>>)
    end

    test "roundtrips through write and read" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
        |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.deflated_explicit_vr_little_endian())
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
        |> DataSet.put({0x0008, 0x0060}, :CS, "CT")

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)

      assert DataSet.get(parsed, {0x0010, 0x0010}) |> String.trim() == "DOE^JOHN"
      assert DataSet.get(parsed, {0x0008, 0x0060}) |> String.trim() == "CT"
    end

    test "deflated binary is smaller than uncompressed for repetitive data" do
      # Create a data set with highly repetitive data (zlib needs enough data to compress)
      value = String.duplicate("ABCDEFGHIJKLMNOP", 500)

      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
        |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.deflated_explicit_vr_little_endian())
        |> DataSet.put({0x0010, 0x0010}, :PN, value)

      {:ok, deflated_binary} = Dicom.P10.Writer.serialize(ds)

      ds_explicit =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
        |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_little_endian())
        |> DataSet.put({0x0010, 0x0010}, :PN, value)

      {:ok, explicit_binary} = Dicom.P10.Writer.serialize(ds_explicit)

      assert byte_size(deflated_binary) < byte_size(explicit_binary)
    end

    test "writes raw deflate payloads without a zlib wrapper header" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
        |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
        |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.deflated_explicit_vr_little_endian())
        |> DataSet.put({0x0010, 0x0010}, :PN, String.duplicate("DOE^JOHN", 16))

      {:ok, binary} = Dicom.P10.Writer.serialize(ds)

      <<_preamble::binary-size(128), "DICM", _tag::binary-size(4), _vr::binary-size(2),
        _length::little-16, group_length::little-32, rest::binary>> = binary

      <<_file_meta::binary-size(group_length), payload::binary>> = rest

      refute binary_part(payload, 0, 2) == <<0x78, 0x9C>>
      assert {:ok, _} = Deflated.decompress(payload)
    end
  end
end
