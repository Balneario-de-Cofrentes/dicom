defmodule Dicom.DataSetTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataElement, DataSet}

  doctest Dicom.DataSet

  setup do
    ds =
      DataSet.new()
      |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
      |> DataSet.put({0x0008, 0x0060}, :CS, "CT")
      |> DataSet.put({0x0010, 0x0020}, :LO, "PAT001")

    %{ds: ds}
  end

  describe "has_tag?/2" do
    test "returns true for present tag", %{ds: ds} do
      assert DataSet.has_tag?(ds, {0x0010, 0x0010})
    end

    test "returns false for missing tag", %{ds: ds} do
      refute DataSet.has_tag?(ds, {0x0099, 0x0099})
    end

    test "works for file_meta tags" do
      ds = DataSet.put(DataSet.new(), {0x0002, 0x0010}, :UI, "1.2.840.10008.1.2")
      assert DataSet.has_tag?(ds, {0x0002, 0x0010})
    end
  end

  describe "get/3 with default" do
    test "returns value when present", %{ds: ds} do
      assert DataSet.get(ds, {0x0010, 0x0010}, "DEFAULT") == "DOE^JOHN"
    end

    test "returns default when absent", %{ds: ds} do
      assert DataSet.get(ds, {0x0099, 0x0099}, "DEFAULT") == "DEFAULT"
    end
  end

  describe "fetch/2" do
    test "returns {:ok, value} for present tag", %{ds: ds} do
      assert {:ok, "DOE^JOHN"} = DataSet.fetch(ds, {0x0010, 0x0010})
    end

    test "returns :error for missing tag", %{ds: ds} do
      assert :error = DataSet.fetch(ds, {0x0099, 0x0099})
    end
  end

  describe "merge/2" do
    test "second data set wins on conflict", %{ds: ds} do
      other = DataSet.from_list([{{0x0010, 0x0010}, :PN, "SMITH^JANE"}])
      merged = DataSet.merge(ds, other)
      assert DataSet.get(merged, {0x0010, 0x0010}) == "SMITH^JANE"
    end

    test "preserves elements from both" do
      ds1 = DataSet.from_list([{{0x0010, 0x0010}, :PN, "DOE^JOHN"}])
      ds2 = DataSet.from_list([{{0x0008, 0x0060}, :CS, "MR"}])
      merged = DataSet.merge(ds1, ds2)
      assert DataSet.get(merged, {0x0010, 0x0010}) == "DOE^JOHN"
      assert DataSet.get(merged, {0x0008, 0x0060}) == "MR"
    end

    test "merges file_meta as well" do
      ds1 = DataSet.put(DataSet.new(), {0x0002, 0x0010}, :UI, "1.2.840.10008.1.2")
      ds2 = DataSet.put(DataSet.new(), {0x0002, 0x0012}, :UI, "1.2.3")
      merged = DataSet.merge(ds1, ds2)
      assert DataSet.has_tag?(merged, {0x0002, 0x0010})
      assert DataSet.has_tag?(merged, {0x0002, 0x0012})
    end
  end

  describe "from_list/1" do
    test "creates empty data set from empty list" do
      ds = DataSet.from_list([])
      assert DataSet.size(ds) == 0
    end

    test "creates data set with multiple elements" do
      ds =
        DataSet.from_list([
          {{0x0010, 0x0010}, :PN, "DOE^JOHN"},
          {{0x0008, 0x0060}, :CS, "CT"},
          {{0x0028, 0x0010}, :US, <<256::little-16>>}
        ])

      assert DataSet.size(ds) == 3
      assert DataSet.get(ds, {0x0010, 0x0010}) == "DOE^JOHN"
    end

    test "routes group 0002 to file_meta" do
      ds = DataSet.from_list([{{0x0002, 0x0010}, :UI, "1.2.840.10008.1.2"}])
      assert DataSet.has_tag?(ds, {0x0002, 0x0010})
      assert ds.file_meta != %{}
    end
  end

  describe "decoded_value/2" do
    test "decodes binary US to integer" do
      ds = DataSet.from_list([{{0x0028, 0x0010}, :US, <<256::little-16>>}])
      assert DataSet.decoded_value(ds, {0x0028, 0x0010}) == 256
    end

    test "trims PN string" do
      ds = DataSet.from_list([{{0x0010, 0x0010}, :PN, "DOE^JOHN "}])
      assert DataSet.decoded_value(ds, {0x0010, 0x0010}) == "DOE^JOHN"
    end

    test "returns nil for missing tag", %{ds: ds} do
      assert DataSet.decoded_value(ds, {0x0099, 0x0099}) == nil
    end

    test "returns non-binary values as-is" do
      ds =
        %DataSet{
          elements: %{
            {0x0008, 0x1115} => %Dicom.DataElement{
              tag: {0x0008, 0x1115},
              vr: :SQ,
              value: [%{}],
              length: 0
            }
          }
        }

      assert DataSet.decoded_value(ds, {0x0008, 0x1115}) == [%{}]
    end

    test "returns nil for malformed fixed-width numeric binaries" do
      ds = DataSet.from_list([{{0x0028, 0x0010}, :US, <<1>>}])
      assert DataSet.decoded_value(ds, {0x0028, 0x0010}) == nil
    end

    test "returns nil for malformed DS lexical values" do
      ds = DataSet.from_list([{{0x0028, 0x1050}, :DS, "1.2.3"}])
      assert DataSet.decoded_value(ds, {0x0028, 0x1050}) == nil
    end

    test "returns nil for malformed IS lexical values" do
      ds = DataSet.from_list([{{0x0010, 0x0020}, :IS, "+12garbage"}])
      assert DataSet.decoded_value(ds, {0x0010, 0x0020}) == nil
    end

    test "decodes multi-valued AT values into tag tuples" do
      binary = <<0x0010::little-16, 0x0020::little-16, 0x0008::little-16, 0x0018::little-16>>
      ds = DataSet.from_list([{{0x0020, 0x5000}, :AT, binary}])

      assert DataSet.decoded_value(ds, {0x0020, 0x5000}) == [
               {0x0010, 0x0020},
               {0x0008, 0x0018}
             ]
    end
  end

  describe "Access behaviour (ds[tag])" do
    test "bracket access returns value", %{ds: ds} do
      assert ds[{0x0010, 0x0010}] == "DOE^JOHN"
    end

    test "bracket access returns nil for missing key", %{ds: ds} do
      assert ds[{0x0099, 0x0099}] == nil
    end

    test "get_and_update/3 updates a value", %{ds: ds} do
      {old, new_ds} =
        Access.get_and_update(ds, {0x0010, 0x0010}, fn current ->
          {current, "SMITH^JANE"}
        end)

      assert old == "DOE^JOHN"
      assert DataSet.get(new_ds, {0x0010, 0x0010}) == "SMITH^JANE"
    end

    test "get_and_update/3 with :pop" do
      ds = DataSet.from_list([{{0x0010, 0x0010}, :PN, "DOE^JOHN"}])

      {old, new_ds} = Access.get_and_update(ds, {0x0010, 0x0010}, fn _ -> :pop end)

      assert old == "DOE^JOHN"
      refute DataSet.has_tag?(new_ds, {0x0010, 0x0010})
    end

    test "pop/2 removes and returns value", %{ds: ds} do
      {value, new_ds} = Access.pop(ds, {0x0010, 0x0010})
      assert value == "DOE^JOHN"
      refute DataSet.has_tag?(new_ds, {0x0010, 0x0010})
    end

    test "pop/2 returns nil for missing key", %{ds: ds} do
      {value, same_ds} = Access.pop(ds, {0x0099, 0x0099})
      assert value == nil
      assert same_ds == ds
    end
  end

  describe "Enumerable protocol" do
    test "Enum.count/1", %{ds: ds} do
      assert Enum.count(ds) == 3
    end

    test "Enum.map/2 extracts tags", %{ds: ds} do
      tags = Enum.map(ds, & &1.tag)
      assert {0x0008, 0x0060} in tags
      assert {0x0010, 0x0010} in tags
      assert {0x0010, 0x0020} in tags
    end

    test "Enum.filter/2 by VR", %{ds: ds} do
      pn_elements = Enum.filter(ds, fn elem -> elem.vr == :PN end)
      assert length(pn_elements) == 1
      assert hd(pn_elements).tag == {0x0010, 0x0010}
    end

    test "for comprehension works", %{ds: ds} do
      values = for elem <- ds, do: elem.value
      assert "DOE^JOHN" in values
      assert "CT" in values
    end

    test "elements are sorted by tag", %{ds: ds} do
      tags = Enum.map(ds, & &1.tag)
      assert tags == Enum.sort(tags)
    end

    test "Enum.member?/2" do
      ds = DataSet.from_list([{{0x0010, 0x0010}, :PN, "DOE^JOHN"}])
      elem = DataSet.get_element(ds, {0x0010, 0x0010})
      assert Enum.member?(ds, elem)
      refute Enum.member?(ds, :not_an_element)
    end

    test "includes file_meta in enumeration" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2")
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")

      tags = Enum.map(ds, & &1.tag)
      assert {0x0002, 0x0010} in tags
      assert {0x0010, 0x0010} in tags
      # file_meta should come first (lower group number)
      assert hd(tags) == {0x0002, 0x0010}
    end
  end

  describe "Inspect protocol" do
    test "shows element count and patient/modality", %{ds: ds} do
      output = inspect(ds)
      assert output =~ "3 elements"
      assert output =~ "patient="
      assert output =~ "DOE^JOHN"
      assert output =~ "modality=CT"
    end

    test "omits patient/modality when absent" do
      ds = DataSet.from_list([{{0x0028, 0x0010}, :US, <<256::little-16>>}])
      output = inspect(ds)
      assert output =~ "1 elements"
      refute output =~ "patient="
      refute output =~ "modality="
    end

    test "empty data set" do
      ds = DataSet.new()
      output = inspect(ds)
      assert output =~ "0 elements"
    end
  end

  describe "Enumerable slice" do
    test "Enum.slice/2 works", %{ds: ds} do
      sliced = Enum.slice(ds, 0, 2)
      assert length(sliced) == 2
    end

    test "Enum.take/2 works", %{ds: ds} do
      taken = Enum.take(ds, 1)
      assert length(taken) == 1
    end

    test "Enum.at/2 works", %{ds: ds} do
      first = Enum.at(ds, 0)
      assert %Dicom.DataElement{} = first
    end

    test "empty data set enumeration" do
      ds = DataSet.new()
      assert Enum.count(ds) == 0
      assert Enum.to_list(ds) == []
    end
  end

  describe "Access - get_and_update for new tag" do
    test "creates element with VR from dictionary", %{ds: ds} do
      # StudyDate is in dictionary as DA
      {old, new_ds} =
        Access.get_and_update(ds, {0x0008, 0x0020}, fn current ->
          {current, "20240315"}
        end)

      assert old == nil
      assert DataSet.get(new_ds, {0x0008, 0x0020}) == "20240315"
    end

    test "creates element with :UN for unknown tags" do
      ds = DataSet.new()

      {_, new_ds} =
        Access.get_and_update(ds, {0x0099, 0x0099}, fn _ ->
          {nil, "test"}
        end)

      elem = DataSet.get_element(new_ds, {0x0099, 0x0099})
      assert elem.vr == :UN
    end
  end

  describe "DataElement Inspect protocol" do
    test "shows tag, VR, and short value" do
      elem = Dicom.DataElement.new({0x0010, 0x0010}, :PN, "DOE^JOHN")
      output = inspect(elem)
      assert output =~ "(0010,0010)"
      assert output =~ "PN"
      assert output =~ "DOE^JOHN"
    end

    test "truncates long binary values" do
      long_value = String.duplicate("A", 100)
      elem = Dicom.DataElement.new({0x0010, 0x0010}, :LT, long_value)
      output = inspect(elem)
      assert output =~ "..."
    end

    test "shows SQ item count" do
      elem = %Dicom.DataElement{tag: {0x0008, 0x1115}, vr: :SQ, value: [%{}, %{}], length: 0}
      output = inspect(elem)
      assert output =~ "2 items"
    end

    test "shows encapsulated fragment count" do
      elem = %Dicom.DataElement{
        tag: {0x7FE0, 0x0010},
        vr: :OB,
        value: {:encapsulated, [<<1>>, <<2>>, <<3>>]},
        length: 0
      }

      output = inspect(elem)
      assert output =~ "3 fragments"
    end

    test "shows byte count for non-printable binary" do
      elem = Dicom.DataElement.new({0x7FE0, 0x0010}, :OB, <<0xFF, 0xD8, 0xFF, 0xE0>>)
      output = inspect(elem)
      assert output =~ "4 bytes"
    end

    test "shows non-binary non-list value via inspect" do
      # Exercise format_value(other, _vr, opts) clause
      elem = %Dicom.DataElement{tag: {0x0028, 0x0010}, vr: :US, value: 256, length: 0}
      output = inspect(elem)
      assert output =~ "(0028,0010)"
      assert output =~ "US"
      assert output =~ "256"
    end

    test "shows byte count for long non-printable binary" do
      # Exercise the >64 bytes non-printable path
      long_binary = :crypto.strong_rand_bytes(100)
      elem = Dicom.DataElement.new({0x7FE0, 0x0010}, :OW, long_binary)
      output = inspect(elem)
      assert output =~ "100 bytes"
    end
  end

  describe "Inspect protocol - DataSet edge cases" do
    test "shows file meta count in element total" do
      ds =
        DataSet.new()
        |> DataSet.put({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2")
        |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
        |> DataSet.put({0x0008, 0x0060}, :CS, "MR")

      output = inspect(ds)
      assert output =~ "3 elements"
      assert output =~ "DOE^JOHN"
      assert output =~ "modality=MR"
    end

    test "shows modality only when present without patient" do
      ds = DataSet.from_list([{{0x0008, 0x0060}, :CS, "CT"}])
      output = inspect(ds)
      assert output =~ "modality=CT"
      refute output =~ "patient="
    end

    test "inspect_short handles non-binary patient name value" do
      # Simulate a pre-decoded or non-standard patient name value (e.g. integer)
      elem = %DataElement{tag: {0x0010, 0x0010}, vr: :PN, value: 42, length: 0}
      ds = %DataSet{file_meta: %{}, elements: %{{0x0010, 0x0010} => elem}}
      output = inspect(ds)
      assert output =~ "patient=42"
    end
  end
end
