defmodule Dicom.JsonTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Dicom.{DataSet, DataElement, Json}

  # ── Encoder Tests ───────────────────────────────────────────────

  describe "Json.to_map/2 - basic structure" do
    test "returns empty map for empty data set" do
      ds = DataSet.new()
      assert Json.to_map(ds) == %{}
    end

    test "encodes tags as 8-char uppercase hex strings" do
      ds = DataSet.new() |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
      map = Json.to_map(ds)
      assert Map.has_key?(map, "00100010")
    end

    test "each element has vr key" do
      ds = DataSet.new() |> DataSet.put({0x0010, 0x0020}, :LO, "12345")
      map = Json.to_map(ds)
      assert map["00100020"]["vr"] == "LO"
    end
  end

  describe "Json.to_map/2 - string VRs" do
    test "encodes LO as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0010, 0x0020}, :LO, "PAT001")
      map = Json.to_map(ds)
      assert map["00100020"] == %{"vr" => "LO", "Value" => ["PAT001"]}
    end

    test "encodes SH as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0020, 0x0010}, :SH, "STUDY1")
      map = Json.to_map(ds)
      assert map["00200010"] == %{"vr" => "SH", "Value" => ["STUDY1"]}
    end

    test "encodes DA as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0008, 0x0020}, :DA, "20240101")
      map = Json.to_map(ds)
      assert map["00080020"] == %{"vr" => "DA", "Value" => ["20240101"]}
    end

    test "encodes TM as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0008, 0x0030}, :TM, "120000")
      map = Json.to_map(ds)
      assert map["00080030"] == %{"vr" => "TM", "Value" => ["120000"]}
    end

    test "encodes DT as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0008, 0x002A}, :DT, "20240101120000.000000")
      map = Json.to_map(ds)
      assert map["0008002A"] == %{"vr" => "DT", "Value" => ["20240101120000.000000"]}
    end

    test "encodes CS as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0008, 0x0060}, :CS, "CT")
      map = Json.to_map(ds)
      assert map["00080060"] == %{"vr" => "CS", "Value" => ["CT"]}
    end

    test "encodes UI as string Value (null-trimmed)" do
      ds = DataSet.new() |> DataSet.put({0x0008, 0x0018}, :UI, "1.2.3.4")
      map = Json.to_map(ds)
      assert map["00080018"] == %{"vr" => "UI", "Value" => ["1.2.3.4"]}
    end

    test "encodes AE as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0008, 0x0054}, :AE, "SCANNER1")
      map = Json.to_map(ds)
      assert map["00080054"] == %{"vr" => "AE", "Value" => ["SCANNER1"]}
    end

    test "encodes LT as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0020, 0x4000}, :LT, "Some comments here")
      map = Json.to_map(ds)
      assert map["00204000"] == %{"vr" => "LT", "Value" => ["Some comments here"]}
    end

    test "encodes ST as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0008, 0x0081}, :ST, "123 Main St")
      map = Json.to_map(ds)
      assert map["00080081"] == %{"vr" => "ST", "Value" => ["123 Main St"]}
    end

    test "encodes UT as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0008, 0x0119}, :UT, "long text value")
      map = Json.to_map(ds)
      assert map["00080119"] == %{"vr" => "UT", "Value" => ["long text value"]}
    end

    test "encodes UC as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0008, 0x0120}, :UC, "unlimited chars")
      map = Json.to_map(ds)
      assert map["00080120"] == %{"vr" => "UC", "Value" => ["unlimited chars"]}
    end

    test "encodes UR as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0008, 0x0121}, :UR, "https://example.com")
      map = Json.to_map(ds)
      assert map["00080121"] == %{"vr" => "UR", "Value" => ["https://example.com"]}
    end

    test "encodes DS as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0018, 0x0050}, :DS, "1.5")
      map = Json.to_map(ds)
      assert map["00180050"] == %{"vr" => "DS", "Value" => ["1.5"]}
    end

    test "encodes IS as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0020, 0x0013}, :IS, "42")
      map = Json.to_map(ds)
      assert map["00200013"] == %{"vr" => "IS", "Value" => ["42"]}
    end

    test "encodes AS as string Value" do
      ds = DataSet.new() |> DataSet.put({0x0010, 0x1010}, :AS, "045Y")
      map = Json.to_map(ds)
      assert map["00101010"] == %{"vr" => "AS", "Value" => ["045Y"]}
    end

    test "encodes multi-valued AE as separate Value entries" do
      ds = DataSet.new() |> DataSet.put({0x0008, 0x0054}, :AE, "SCANNER1\\SCANNER2")
      map = Json.to_map(ds)
      assert map["00080054"] == %{"vr" => "AE", "Value" => ["SCANNER1", "SCANNER2"]}
    end

    test "preserves meaningful trailing newlines in text VRs" do
      ds = DataSet.new() |> DataSet.put({0x0040, 0xA160}, :UT, "line1\n")

      assert Json.to_map(ds)["0040A160"] == %{"vr" => "UT", "Value" => ["line1\n"]}
    end
  end

  describe "Json.to_map/2 - PN (Person Name)" do
    test "encodes simple PN as Alphabetic component" do
      ds = DataSet.new() |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
      map = Json.to_map(ds)

      assert map["00100010"] == %{
               "vr" => "PN",
               "Value" => [%{"Alphabetic" => "DOE^JOHN"}]
             }
    end

    test "encodes PN with ideographic and phonetic components" do
      # Per PS3.5, PN components separated by = delimiter
      ds =
        DataSet.new()
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN=ドウ^ジョン=doe^john")

      map = Json.to_map(ds)

      assert map["00100010"] == %{
               "vr" => "PN",
               "Value" => [
                 %{
                   "Alphabetic" => "DOE^JOHN",
                   "Ideographic" => "ドウ^ジョン",
                   "Phonetic" => "doe^john"
                 }
               ]
             }
    end

    test "encodes PN with only alphabetic (no trailing =)" do
      ds = DataSet.new() |> DataSet.put({0x0010, 0x0010}, :PN, "SMITH^JANE")
      map = Json.to_map(ds)

      assert map["00100010"]["Value"] == [%{"Alphabetic" => "SMITH^JANE"}]
    end

    test "encodes multi-valued PN as multiple JSON values" do
      ds = DataSet.new() |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN\\SMITH^JANE")
      map = Json.to_map(ds)

      assert map["00100010"]["Value"] == [
               %{"Alphabetic" => "DOE^JOHN"},
               %{"Alphabetic" => "SMITH^JANE"}
             ]
    end

    test "decodes PN bytes using SpecificCharacterSet before JSON export" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0008, 0x0005}, :CS, "ISO_IR 100")
        |> DataSet.put({0x0010, 0x0010}, :PN, <<0x4D, 0xDC, 0x4C, 0x4C, 0x45, 0x52>>)

      map = Json.to_map(ds)

      assert map["00100010"]["Value"] == [%{"Alphabetic" => "MÜLLER"}]
    end

    test "decodes ISO_IR 13 text instead of splitting on raw 0x5C bytes" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0008, 0x0005}, :CS, "ISO_IR 13")
        |> DataSet.put({0x0010, 0x0010}, :PN, <<0x5C>>)

      map = Json.to_map(ds)

      assert map["00100010"]["Value"] == [%{"Alphabetic" => "¥"}]
    end

    test "raises when PN contains more than three component groups" do
      ds = DataSet.new() |> DataSet.put({0x0010, 0x0010}, :PN, "A=B=C=D")

      assert_raise ArgumentError, ~r/invalid PN value/, fn ->
        Json.to_map(ds)
      end
    end

    test "raises when exporting charset-sensitive text with multiple SpecificCharacterSet values" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0008, 0x0005}, :CS, "ISO_IR 100\\ISO_IR 101")
        |> DataSet.put({0x0010, 0x0010}, :PN, <<0xA1>>)

      assert_raise ArgumentError, ~r/multi-valued SpecificCharacterSet/, fn ->
        Json.to_map(ds)
      end
    end
  end

  describe "Json.to_map/2 - numeric VRs" do
    test "encodes US as number" do
      ds = DataSet.new() |> DataSet.put({0x0028, 0x0010}, :US, <<256::little-16>>)
      map = Json.to_map(ds)
      assert map["00280010"] == %{"vr" => "US", "Value" => [256]}
    end

    test "encodes UL as number" do
      ds = DataSet.new() |> DataSet.put({0x0002, 0x0000}, :UL, <<1000::little-32>>)
      map = Json.to_map(ds, include_file_meta: true)
      refute Map.has_key?(map, "00020000")
    end

    test "encodes SS as number" do
      ds = DataSet.new() |> DataSet.put({0x0028, 0x0106}, :SS, <<-100::little-signed-16>>)
      map = Json.to_map(ds)
      assert map["00280106"]["Value"] == [-100]
    end

    test "encodes SL as number" do
      ds = DataSet.new() |> DataSet.put({0x0018, 0x1310}, :SL, <<-50000::little-signed-32>>)
      map = Json.to_map(ds)
      assert map["00181310"]["Value"] == [-50000]
    end

    test "encodes FL as number" do
      ds = DataSet.new() |> DataSet.put({0x0028, 0x1052}, :FL, <<3.14::little-float-32>>)
      map = Json.to_map(ds)
      [value] = map["00281052"]["Value"]
      assert_in_delta value, 3.14, 0.001
    end

    test "encodes FD as number" do
      ds = DataSet.new() |> DataSet.put({0x0018, 0x0088}, :FD, <<2.718::little-float-64>>)
      map = Json.to_map(ds)
      [value] = map["00180088"]["Value"]
      assert_in_delta value, 2.718, 0.0001
    end
  end

  describe "Json.to_map/2 - AT (Attribute Tag)" do
    test "encodes AT as 8-char hex string" do
      ds =
        DataSet.new()
        |> DataSet.put(
          {0x0020, 0x5000},
          :AT,
          <<0x10, 0x00, 0x20, 0x00>>
        )

      map = Json.to_map(ds)
      assert map["00205000"]["vr"] == "AT"
      assert map["00205000"]["Value"] == ["00100020"]
    end

    test "encodes multi-valued AT as multiple hex strings" do
      ds =
        DataSet.new()
        |> DataSet.put(
          {0x0020, 0x5000},
          :AT,
          <<0x10, 0x00, 0x20, 0x00, 0x08, 0x00, 0x18, 0x00>>
        )

      map = Json.to_map(ds)
      assert map["00205000"]["Value"] == ["00100020", "00080018"]
    end

    test "raises for malformed AT binary values that are not a multiple of four bytes" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0020, 0x5000}, :AT, <<0x10, 0x00, 0x20, 0x00, 0xFF>>)

      assert_raise ArgumentError, ~r/invalid AT value length/, fn ->
        Json.to_map(ds)
      end
    end
  end

  describe "Json.to_map/2 - binary VRs" do
    test "encodes OB as InlineBinary (base64)" do
      binary = <<1, 2, 3, 4>>
      ds = DataSet.new() |> DataSet.put({0x7FE0, 0x0010}, :OB, binary)
      map = Json.to_map(ds)
      assert map["7FE00010"]["vr"] == "OB"
      assert map["7FE00010"]["InlineBinary"] == Base.encode64(binary)
    end

    test "encodes OW as InlineBinary (base64)" do
      binary = <<0, 1, 0, 2>>
      ds = DataSet.new() |> DataSet.put({0x7FE0, 0x0010}, :OW, binary)
      map = Json.to_map(ds)
      assert map["7FE00010"]["InlineBinary"] == Base.encode64(binary)
    end

    test "encodes UN as InlineBinary (base64)" do
      binary = <<255, 254, 253>>
      ds = DataSet.new() |> DataSet.put({0x0009, 0x0010}, :UN, binary)
      map = Json.to_map(ds)
      assert map["00090010"]["InlineBinary"] == Base.encode64(binary)
    end

    test "uses BulkDataURI when bulk_data_uri function is provided" do
      binary = <<1, 2, 3, 4>>
      ds = DataSet.new() |> DataSet.put({0x7FE0, 0x0010}, :OB, binary)

      map =
        Json.to_map(ds, bulk_data_uri: fn {0x7FE0, 0x0010}, :OB -> "http://example.com/pixel" end)

      assert map["7FE00010"]["BulkDataURI"] == "http://example.com/pixel"
      refute Map.has_key?(map["7FE00010"], "InlineBinary")
    end

    test "encodes encapsulated pixel data as InlineBinary" do
      fragments = [<<0::little-32>>, <<1, 2, 3, 4>>]
      elem = DataElement.new({0x7FE0, 0x0010}, :OB, {:encapsulated, fragments})
      ds = %DataSet{elements: %{{0x7FE0, 0x0010} => elem}}

      expected_binary =
        IO.iodata_to_binary([
          <<0xFE, 0xFF, 0x00, 0xE0, 4::little-32, 0::little-32>>,
          <<0xFE, 0xFF, 0x00, 0xE0, 4::little-32, 1, 2, 3, 4>>,
          <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
        ])

      map = Json.to_map(ds)

      assert map["7FE00010"]["InlineBinary"] == Base.encode64(expected_binary)
    end

    test "uses BulkDataURI for encapsulated pixel data without flattening fragments" do
      fragments = [<<0::little-32>>, <<1, 2, 3, 4>>]
      elem = DataElement.new({0x7FE0, 0x0010}, :OB, {:encapsulated, fragments})
      ds = %DataSet{elements: %{{0x7FE0, 0x0010} => elem}}

      map =
        Json.to_map(ds,
          bulk_data_uri: fn {0x7FE0, 0x0010}, :OB -> "http://example.com/encapsulated" end
        )

      assert map["7FE00010"]["BulkDataURI"] == "http://example.com/encapsulated"
      refute Map.has_key?(map["7FE00010"], "InlineBinary")
    end
  end

  describe "Json.to_map/2 - SQ (Sequence)" do
    test "encodes sequence with items" do
      item = %{
        {0x0008, 0x1150} => DataElement.new({0x0008, 0x1150}, :UI, "1.2.3.4"),
        {0x0008, 0x1155} => DataElement.new({0x0008, 0x1155}, :UI, "5.6.7.8")
      }

      ds = DataSet.new()
      elem = DataElement.new({0x0008, 0x1140}, :SQ, [item])
      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x1140}, elem)}

      map = Json.to_map(ds)
      assert map["00081140"]["vr"] == "SQ"
      [item_map] = map["00081140"]["Value"]
      assert item_map["00081150"]["Value"] == ["1.2.3.4"]
      assert item_map["00081155"]["Value"] == ["5.6.7.8"]
    end

    test "encodes empty sequence" do
      ds = DataSet.new()
      elem = DataElement.new({0x0008, 0x1140}, :SQ, [])
      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x1140}, elem)}

      map = Json.to_map(ds)
      assert map["00081140"] == %{"vr" => "SQ", "Value" => []}
    end

    test "encodes nested sequences" do
      inner_item = %{
        {0x0008, 0x1150} => DataElement.new({0x0008, 0x1150}, :UI, "1.2.3")
      }

      inner_sq_elem = DataElement.new({0x0040, 0xA730}, :SQ, [inner_item])

      outer_item = %{
        {0x0040, 0xA730} => inner_sq_elem,
        {0x0008, 0x1150} => DataElement.new({0x0008, 0x1150}, :UI, "9.8.7")
      }

      ds = DataSet.new()
      elem = DataElement.new({0x0008, 0x1115}, :SQ, [outer_item])
      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x1115}, elem)}

      map = Json.to_map(ds)
      [outer] = map["00081115"]["Value"]
      [inner] = outer["0040A730"]["Value"]
      assert inner["00081150"]["Value"] == ["1.2.3"]
    end

    test "propagates bulk_data_uri callback into sequence items" do
      item = %{
        {0x7FE0, 0x0010} => DataElement.new({0x7FE0, 0x0010}, :OB, <<1, 2, 3, 4>>)
      }

      ds = %DataSet{
        elements: %{
          {0x0008, 0x1111} => DataElement.new({0x0008, 0x1111}, :SQ, [item])
        }
      }

      map =
        Json.to_map(ds,
          bulk_data_uri: fn {0x7FE0, 0x0010}, :OB -> "http://example.com/nested-pixel" end
        )

      [encoded_item] = map["00081111"]["Value"]
      assert encoded_item["7FE00010"]["BulkDataURI"] == "http://example.com/nested-pixel"
      refute Map.has_key?(encoded_item["7FE00010"], "InlineBinary")
    end

    test "inherits top-level SpecificCharacterSet when encoding nested text values" do
      item = %{
        {0x0010, 0x0010} =>
          DataElement.new({0x0010, 0x0010}, :PN, <<0x4D, 0xDC, 0x4C, 0x4C, 0x45, 0x52>>)
      }

      ds =
        DataSet.new()
        |> DataSet.put({0x0008, 0x0005}, :CS, "ISO_IR 100")
        |> then(fn ds ->
          elem = DataElement.new({0x0008, 0x1111}, :SQ, [item])
          %{ds | elements: Map.put(ds.elements, {0x0008, 0x1111}, elem)}
        end)

      map = Json.to_map(ds)

      [encoded_item] = map["00081111"]["Value"]
      assert encoded_item["00100010"]["Value"] == [%{"Alphabetic" => "MÜLLER"}]
    end
  end

  describe "Json.to_map/2 - null/empty handling" do
    test "encodes nil value as element with vr only" do
      ds = DataSet.new()
      elem = %DataElement{tag: {0x0010, 0x0020}, vr: :LO, value: nil, length: 0}
      ds = %{ds | elements: Map.put(ds.elements, {0x0010, 0x0020}, elem)}

      map = Json.to_map(ds)
      assert map["00100020"] == %{"vr" => "LO"}
    end

    test "encodes empty string as element with vr only" do
      ds = DataSet.new() |> DataSet.put({0x0010, 0x0020}, :LO, "")
      map = Json.to_map(ds)
      assert map["00100020"] == %{"vr" => "LO"}
    end
  end

  describe "Json.to_map/2 - options" do
    test "excludes file meta by default" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

      map = Json.to_map(ds)
      refute Map.has_key?(map, "00020010")
      assert Map.has_key?(map, "00100010")
    end

    test "includes file meta when include_file_meta: true" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

      map = Json.to_map(ds, include_file_meta: true)
      assert Map.has_key?(map, "00020010")
      assert Map.has_key?(map, "00100010")
    end

    test "omits group length attributes from JSON output" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0000}, :UL, <<12::little-32>>)
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")

      map = Json.to_map(ds, include_file_meta: true)
      refute Map.has_key?(map, "00020000")
      assert Map.has_key?(map, "00020010")
    end
  end

  # ── Decoder Tests ───────────────────────────────────────────────

  describe "Json.from_map/1 - basic structure" do
    test "decodes empty map to empty data set" do
      assert {:ok, ds} = Json.from_map(%{})
      assert DataSet.size(ds) == 0
    end

    test "decodes tag from hex string" do
      json = %{"00100020" => %{"vr" => "LO", "Value" => ["PAT001"]}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0010, 0x0020}) == "PAT001"
    end
  end

  describe "Json.from_map/1 - string VRs" do
    test "decodes LO" do
      json = %{"00100020" => %{"vr" => "LO", "Value" => ["PAT001"]}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0010, 0x0020}) == "PAT001"
    end

    test "decodes CS" do
      json = %{"00080060" => %{"vr" => "CS", "Value" => ["CT"]}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0008, 0x0060}) == "CT"
    end

    test "decodes UI" do
      json = %{"00080018" => %{"vr" => "UI", "Value" => ["1.2.3.4"]}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0008, 0x0018}) == "1.2.3.4"
    end

    test "decodes DA" do
      json = %{"00080020" => %{"vr" => "DA", "Value" => ["20240101"]}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0008, 0x0020}) == "20240101"
    end

    test "decodes DS as string" do
      json = %{"00180050" => %{"vr" => "DS", "Value" => ["1.5"]}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0018, 0x0050}) == "1.5"
    end

    test "decodes DS as number" do
      json = %{"00180050" => %{"vr" => "DS", "Value" => [1.5]}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0018, 0x0050}) == "1.5"
    end

    test "decodes IS as string" do
      json = %{"00200013" => %{"vr" => "IS", "Value" => ["42"]}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0020, 0x0013}) == "42"
    end

    test "decodes IS as number" do
      json = %{"00200013" => %{"vr" => "IS", "Value" => [42]}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0020, 0x0013}) == "42"
    end

    test "decodes multi-valued AE by joining with backslashes" do
      json = %{"00080054" => %{"vr" => "AE", "Value" => ["SCANNER1", "SCANNER2"]}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0008, 0x0054}) == "SCANNER1\\SCANNER2"
    end
  end

  describe "Json.from_map/1 - PN" do
    test "decodes PN with Alphabetic only" do
      json = %{"00100010" => %{"vr" => "PN", "Value" => [%{"Alphabetic" => "DOE^JOHN"}]}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
    end

    test "decodes PN with all three components" do
      json = %{
        "00100010" => %{
          "vr" => "PN",
          "Value" => [
            %{
              "Alphabetic" => "DOE^JOHN",
              "Ideographic" => "ドウ^ジョン",
              "Phonetic" => "doe^john"
            }
          ]
        }
      }

      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN=ドウ^ジョン=doe^john"
    end

    test "decodes multiple person names" do
      json = %{
        "00100010" => %{
          "vr" => "PN",
          "Value" => [%{"Alphabetic" => "DOE^JOHN"}, %{"Alphabetic" => "SMITH^JANE"}]
        }
      }

      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN\\SMITH^JANE"
    end

    test "returns error when PN components are not strings" do
      json = %{
        "00100010" => %{
          "vr" => "PN",
          "Value" => [
            %{"Alphabetic" => 123, "Phonetic" => true}
          ]
        }
      }

      assert {:error,
              {:invalid_value, {0x0010, 0x0010}, :PN, :expected_string_person_name_components}} =
               Json.from_map(json)
    end
  end

  describe "Json.from_map/1 - numeric VRs" do
    test "decodes US" do
      json = %{"00280010" => %{"vr" => "US", "Value" => [256]}}
      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0028, 0x0010})
      assert elem.vr == :US
      assert elem.value == <<256::little-16>>
    end

    test "decodes SS" do
      json = %{"00280106" => %{"vr" => "SS", "Value" => [-100]}}
      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0028, 0x0106})
      assert elem.value == <<-100::little-signed-16>>
    end

    test "decodes FL" do
      json = %{"00281052" => %{"vr" => "FL", "Value" => [3.14]}}
      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0028, 0x1052})
      assert elem.vr == :FL
    end

    test "decodes FD" do
      json = %{"00180088" => %{"vr" => "FD", "Value" => [2.718]}}
      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0018, 0x0088})
      assert elem.vr == :FD
    end

    test "decodes UL" do
      json = %{"00020000" => %{"vr" => "UL", "Value" => [1000]}}
      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0002, 0x0000})
      assert elem.value == <<1000::little-32>>
    end

    test "decodes SL" do
      json = %{"00181310" => %{"vr" => "SL", "Value" => [-50000]}}
      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0018, 0x1310})
      assert elem.value == <<-50000::little-signed-32>>
    end

    test "decodes multi-valued US into concatenated binary" do
      json = %{"00280010" => %{"vr" => "US", "Value" => [256, 512]}}
      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0028, 0x0010})
      assert elem.value == <<256::little-16, 512::little-16>>
    end
  end

  describe "Json.from_map/1 - AT" do
    test "decodes AT from hex string" do
      json = %{"00205000" => %{"vr" => "AT", "Value" => ["00100020"]}}
      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0020, 0x5000})
      assert elem.vr == :AT
      assert elem.value == <<0x10, 0x00, 0x20, 0x00>>
    end

    test "decodes multiple AT values" do
      json = %{"00205000" => %{"vr" => "AT", "Value" => ["00100020", "00080018"]}}
      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0020, 0x5000})
      assert elem.value == <<0x10, 0x00, 0x20, 0x00, 0x08, 0x00, 0x18, 0x00>>
    end
  end

  describe "Json.from_map/1 - binary VRs" do
    test "decodes InlineBinary" do
      encoded = Base.encode64(<<1, 2, 3, 4>>)
      json = %{"7FE00010" => %{"vr" => "OB", "InlineBinary" => encoded}}
      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x7FE0, 0x0010}) == <<1, 2, 3, 4>>
    end

    test "keeps Pixel Data InlineBinary as raw binary even with compressed transfer syntax context" do
      encapsulated =
        IO.iodata_to_binary([
          <<0xFE, 0xFF, 0x00, 0xE0, 4::little-32, 0::little-32>>,
          <<0xFE, 0xFF, 0x00, 0xE0, 4::little-32, 1, 2, 3, 4>>,
          <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
        ])

      json = %{"7FE00010" => %{"vr" => "OB", "InlineBinary" => Base.encode64(encapsulated)}}

      assert {:ok, ds} = Json.from_map(json, transfer_syntax_uid: Dicom.UID.jpeg_baseline())

      assert DataSet.get(ds, {0x7FE0, 0x0010}) == encapsulated
    end

    test "keeps Pixel Data as raw binary without compressed transfer syntax context" do
      encapsulated =
        IO.iodata_to_binary([
          <<0xFE, 0xFF, 0x00, 0xE0, 4::little-32, 0::little-32>>,
          <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
        ])

      json = %{"7FE00010" => %{"vr" => "OB", "InlineBinary" => Base.encode64(encapsulated)}}

      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x7FE0, 0x0010}) == encapsulated
    end

    test "returns an error for unresolved BulkDataURI by default" do
      json = %{"7FE00010" => %{"vr" => "OB", "BulkDataURI" => "http://example.com/pixel"}}

      assert {:error,
              {:unresolved_bulk_data_uri, {0x7FE0, 0x0010}, :OB, "http://example.com/pixel"}} =
               Json.from_map(json)
    end

    test "resolves BulkDataURI when a resolver is provided" do
      json = %{"7FE00010" => %{"vr" => "OB", "BulkDataURI" => "memory://pixel"}}

      assert {:ok, ds} =
               Json.from_map(json,
                 bulk_data_resolver: fn {0x7FE0, 0x0010}, :OB, "memory://pixel" ->
                   {:ok, <<1, 2, 3, 4>>}
                 end
               )

      assert DataSet.get(ds, {0x7FE0, 0x0010}) == <<1, 2, 3, 4>>
    end

    test "keeps resolved Pixel Data BulkDataURI as raw binary even with compressed transfer syntax context" do
      encapsulated =
        IO.iodata_to_binary([
          <<0xFE, 0xFF, 0x00, 0xE0, 4::little-32, 0::little-32>>,
          <<0xFE, 0xFF, 0x00, 0xE0, 4::little-32, 1, 2, 3, 4>>,
          <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
        ])

      json = %{"7FE00010" => %{"vr" => "OB", "BulkDataURI" => "memory://pixel"}}

      assert {:ok, ds} =
               Json.from_map(json,
                 transfer_syntax_uid: Dicom.UID.jpeg_baseline(),
                 bulk_data_resolver: fn {0x7FE0, 0x0010}, :OB, "memory://pixel" ->
                   {:ok, encapsulated}
                 end
               )

      assert DataSet.get(ds, {0x7FE0, 0x0010}) == encapsulated
    end
  end

  describe "Json.from_map/1 - SQ" do
    test "decodes sequence" do
      json = %{
        "00081140" => %{
          "vr" => "SQ",
          "Value" => [
            %{
              "00081150" => %{"vr" => "UI", "Value" => ["1.2.3.4"]},
              "00081155" => %{"vr" => "UI", "Value" => ["5.6.7.8"]}
            }
          ]
        }
      }

      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0008, 0x1140})
      assert elem.vr == :SQ
      assert is_list(elem.value)
      [item] = elem.value
      assert item[{0x0008, 0x1150}].value == "1.2.3.4"
    end

    test "decodes empty sequence" do
      json = %{"00081140" => %{"vr" => "SQ", "Value" => []}}
      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0008, 0x1140})
      assert elem.value == []
    end
  end

  describe "Json.from_map/1 - null/empty handling" do
    test "element with vr only (no Value key) creates nil-value element" do
      json = %{"00100020" => %{"vr" => "LO"}}
      assert {:ok, ds} = Json.from_map(json)
      elem = DataSet.get_element(ds, {0x0010, 0x0020})
      assert elem.vr == :LO
      assert elem.value == nil
    end
  end

  describe "Json.from_map/1 - error handling" do
    test "returns error for invalid tag format" do
      json = %{"ZZZZZZZZ" => %{"vr" => "LO", "Value" => ["test"]}}
      assert {:error, _reason} = Json.from_map(json)
    end

    test "returns error for missing vr" do
      json = %{"00100020" => %{"Value" => ["test"]}}
      assert {:error, _reason} = Json.from_map(json)
    end

    test "returns error for invalid nested sequence tag" do
      json = %{
        "00081110" => %{
          "vr" => "SQ",
          "Value" => [
            %{"BADTAG" => %{"vr" => "UI", "Value" => ["1.2.3"]}}
          ]
        }
      }

      assert {:error, {:invalid_tag, "BADTAG"}} = Json.from_map(json)
    end

    test "returns error for invalid nested sequence item type" do
      json = %{
        "00081110" => %{
          "vr" => "SQ",
          "Value" => ["not-a-map"]
        }
      }

      assert {:error, :invalid_sequence_item} = Json.from_map(json)
    end

    test "returns error for mixed JSON representations on one element" do
      json = %{
        "7FE00010" => %{
          "vr" => "OB",
          "InlineBinary" => Base.encode64(<<1, 2, 3, 4>>),
          "BulkDataURI" => "http://example.com/pixel"
        }
      }

      assert {:error, {:multiple_value_representations, {0x7FE0, 0x0010}}} =
               Json.from_map(json)
    end
  end

  describe "Json.to_map/2 - AT with tag tuple" do
    test "encodes AT from pre-decoded tag tuple" do
      ds = DataSet.new()

      elem = %DataElement{
        tag: {0x0020, 0x5000},
        vr: :AT,
        value: {0x0010, 0x0020},
        length: 4
      }

      ds = %{ds | elements: Map.put(ds.elements, {0x0020, 0x5000}, elem)}
      map = Json.to_map(ds)
      assert map["00205000"]["Value"] == ["00100020"]
    end
  end

  describe "Json.to_map/2 - numeric VR with pre-decoded number" do
    test "encodes numeric value that is already a number" do
      ds = DataSet.new()

      elem = %DataElement{
        tag: {0x0028, 0x0010},
        vr: :US,
        value: 256,
        length: 2
      }

      ds = %{ds | elements: Map.put(ds.elements, {0x0028, 0x0010}, elem)}
      map = Json.to_map(ds)
      assert map["00280010"]["Value"] == [256]
    end
  end

  describe "Json.to_map/2 - PN with ideographic only" do
    test "encodes PN with two components (alphabetic=ideographic)" do
      ds = DataSet.new() |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN=ドウ^ジョン")
      map = Json.to_map(ds)

      assert map["00100010"]["Value"] == [
               %{"Alphabetic" => "DOE^JOHN", "Ideographic" => "ドウ^ジョン"}
             ]
    end
  end

  describe "Json.to_map/2 - bulk_data_uri returning nil" do
    test "falls back to InlineBinary when bulk_fn returns nil" do
      binary = <<1, 2, 3, 4>>
      ds = DataSet.new() |> DataSet.put({0x7FE0, 0x0010}, :OB, binary)

      map = Json.to_map(ds, bulk_data_uri: fn _tag, _vr -> nil end)

      assert map["7FE00010"]["InlineBinary"] == Base.encode64(binary)
      refute Map.has_key?(map["7FE00010"], "BulkDataURI")
    end
  end

  describe "Json.from_map/1 - PN with ideographic only" do
    test "decodes PN with two components" do
      json = %{
        "00100010" => %{
          "vr" => "PN",
          "Value" => [
            %{"Alphabetic" => "DOE^JOHN", "Ideographic" => "ドウ^ジョン"}
          ]
        }
      }

      assert {:ok, ds} = Json.from_map(json)
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN=ドウ^ジョン"
    end
  end

  describe "Json.from_map/1 - invalid base64" do
    test "returns error for invalid InlineBinary" do
      json = %{"7FE00010" => %{"vr" => "OB", "InlineBinary" => "!!!invalid!!!"}}

      assert {:error, {:invalid_value, {0x7FE0, 0x0010}, :OB, :invalid_base64}} =
               Json.from_map(json)
    end
  end

  describe "Json.from_map/1 - invalid tag length" do
    test "returns error for tag with wrong length" do
      json = %{"001" => %{"vr" => "LO", "Value" => ["test"]}}
      assert {:error, _} = Json.from_map(json)
    end
  end

  describe "Json.from_map/1 - file meta routing" do
    test "routes group 0002 to file_meta" do
      json = %{"00020010" => %{"vr" => "UI", "Value" => ["1.2.840.10008.1.2.1"]}}
      assert {:ok, ds} = Json.from_map(json)
      assert ds.file_meta != %{}
      assert DataSet.get(ds, {0x0002, 0x0010}) == "1.2.840.10008.1.2.1"
    end
  end

  describe "Json.from_map/1 - Value with unmatched type" do
    test "element with Value containing unsupported type returns an error" do
      json = %{"00100020" => %{"vr" => "LO", "Value" => [42]}}

      assert {:error, {:invalid_value, {0x0010, 0x0020}, :LO, :expected_string_values}} =
               Json.from_map(json)
    end

    test "binary VR with Value array returns an error" do
      json = %{"7FE00010" => %{"vr" => "OB", "Value" => ["abcd"]}}

      assert {:error, {:invalid_value, {0x7FE0, 0x0010}, :OB, :expected_binary_representation}} =
               Json.from_map(json)
    end
  end

  describe "Json.to_map/2 - fallback encode_value" do
    test "non-binary non-list non-number value raises instead of dropping the payload" do
      ds = DataSet.new()

      elem = %DataElement{
        tag: {0x0028, 0x0010},
        vr: :US,
        value: {1, 2, 3},
        length: 0
      }

      ds = %{ds | elements: Map.put(ds.elements, {0x0028, 0x0010}, elem)}

      assert_raise ArgumentError, ~r/unsupported value for VR US/, fn ->
        Json.to_map(ds)
      end
    end

    test "encodes numeric VR with multi-value binary" do
      binary = <<1::little-16, 2::little-16, 3::little-16>>
      ds = DataSet.new() |> DataSet.put({0x0028, 0x0010}, :US, binary)
      map = Json.to_map(ds)
      assert map["00280010"]["Value"] == [1, 2, 3]
    end

    test "raises when numeric VR binary cannot be decoded cleanly" do
      ds = DataSet.new() |> DataSet.put({0x0028, 0x0010}, :US, <<1>>)

      assert_raise ArgumentError, ~r/invalid binary value for numeric VR US/, fn ->
        Json.to_map(ds)
      end
    end
  end

  describe "Json.from_map/1 - unknown VR" do
    test "returns error for unknown VR string" do
      json = %{"00100020" => %{"vr" => "XX", "Value" => ["test"]}}
      assert {:error, :unknown_vr} = Json.from_map(json)
    end
  end

  describe "Json.from_map/1 - missing VR" do
    test "returns error when vr key absent" do
      json = %{"00100020" => %{"Value" => ["test"]}}
      assert {:error, :missing_vr} = Json.from_map(json)
    end
  end

  # ── Roundtrip Tests ─────────────────────────────────────────────

  describe "roundtrip: to_map -> from_map" do
    test "roundtrips string elements" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0010, 0x0020}, :LO, "PAT001")
        |> DataSet.put({0x0008, 0x0060}, :CS, "CT")
        |> DataSet.put({0x0008, 0x0020}, :DA, "20240101")

      map = Json.to_map(ds)
      assert {:ok, ds2} = Json.from_map(map)

      assert DataSet.get(ds2, {0x0010, 0x0020}) == "PAT001"
      assert DataSet.get(ds2, {0x0008, 0x0060}) == "CT"
      assert DataSet.get(ds2, {0x0008, 0x0020}) == "20240101"
    end

    test "roundtrips PN elements" do
      ds = DataSet.new() |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
      map = Json.to_map(ds)
      assert {:ok, ds2} = Json.from_map(map)
      assert DataSet.get(ds2, {0x0010, 0x0010}) == "DOE^JOHN"
    end

    test "roundtrips binary elements" do
      binary = <<1, 2, 3, 4, 5, 6>>
      ds = DataSet.new() |> DataSet.put({0x7FE0, 0x0010}, :OB, binary)
      map = Json.to_map(ds)
      assert {:ok, ds2} = Json.from_map(map)
      assert DataSet.get(ds2, {0x7FE0, 0x0010}) == binary
    end

    test "roundtrips encapsulated pixel data without flattening fragments" do
      value = {:encapsulated, [<<0::little-32>>, <<1, 2, 3, 4>>]}

      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.jpeg_baseline())
        |> DataSet.put({0x7FE0, 0x0010}, :OB, value)

      map = Json.to_map(ds, include_file_meta: true)

      assert {:ok, ds2} = Json.from_map(map)

      expected_binary =
        IO.iodata_to_binary([
          <<0xFE, 0xFF, 0x00, 0xE0, 4::little-32, 0::little-32>>,
          <<0xFE, 0xFF, 0x00, 0xE0, 4::little-32, 1, 2, 3, 4>>,
          <<0xFE, 0xFF, 0xDD, 0xE0, 0::little-32>>
        ])

      assert DataSet.get(ds2, {0x7FE0, 0x0010}) == expected_binary
    end

    test "JSON roundtrip of compressed Pixel Data remains writable" do
      ds =
        %DataSet{
          file_meta: %{
            {0x0002, 0x0002} =>
              DataElement.new({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2"),
            {0x0002, 0x0003} => DataElement.new({0x0002, 0x0003}, :UI, Dicom.UID.generate()),
            {0x0002, 0x0010} => DataElement.new({0x0002, 0x0010}, :UI, Dicom.UID.jpeg_baseline())
          },
          elements: %{
            {0x7FE0, 0x0010} =>
              DataElement.new(
                {0x7FE0, 0x0010},
                :OB,
                {:encapsulated, [<<0::little-32>>, <<1, 2, 3, 4>>]}
              )
          }
        }

      map = Json.to_map(ds, include_file_meta: true)
      assert {:ok, ds2} = Json.from_map(map)
      assert {:ok, _binary} = Dicom.P10.Writer.serialize(ds2)
    end

    test "roundtrips sequence elements" do
      item = %{
        {0x0008, 0x1150} => DataElement.new({0x0008, 0x1150}, :UI, "1.2.3.4")
      }

      ds = DataSet.new()
      elem = DataElement.new({0x0008, 0x1140}, :SQ, [item])
      ds = %{ds | elements: Map.put(ds.elements, {0x0008, 0x1140}, elem)}

      map = Json.to_map(ds)
      assert {:ok, ds2} = Json.from_map(map)
      elem2 = DataSet.get_element(ds2, {0x0008, 0x1140})
      [item2] = elem2.value
      assert item2[{0x0008, 0x1150}].value == "1.2.3.4"
    end
  end
end
