defmodule Dicom.PrivateTagTest do
  use ExUnit.Case, async: true

  alias Dicom.{DataSet, PrivateTag}

  describe "private?/1" do
    test "returns true for odd-group tags" do
      assert PrivateTag.private?({0x0009, 0x0010})
      assert PrivateTag.private?({0x0011, 0x1001})
      assert PrivateTag.private?({0x00FF, 0x0010})
    end

    test "returns false for even-group tags" do
      refute PrivateTag.private?({0x0008, 0x0010})
      refute PrivateTag.private?({0x0010, 0x0010})
      refute PrivateTag.private?({0x7FE0, 0x0010})
    end

    test "returns false for group 0x0001 (command group)" do
      refute PrivateTag.private?({0x0001, 0x0010})
      refute PrivateTag.private?({0x0001, 0x1000})
    end
  end

  describe "private_block/1" do
    test "extracts block number from private data element" do
      # (0009,1002) -> block 0x10
      assert PrivateTag.private_block({0x0009, 0x1002}) == 0x10
      # (0009,FF02) -> block 0xFF
      assert PrivateTag.private_block({0x0009, 0xFF02}) == 0xFF
    end

    test "extracts block number from creator element" do
      # (0009,0010) -> block 0x10
      assert PrivateTag.private_block({0x0009, 0x0010}) == 0x10
      # (0009,00FF) -> block 0xFF
      assert PrivateTag.private_block({0x0009, 0x00FF}) == 0xFF
    end

    test "returns 0 for element 0x0000 (group length)" do
      assert PrivateTag.private_block({0x0009, 0x0000}) == 0x00
    end
  end

  describe "creator_tag/1" do
    test "returns creator tag for a private data element" do
      # Private data at (0009,1001) -> creator at (0009,0010)
      assert PrivateTag.creator_tag({0x0009, 0x1001}) == {0x0009, 0x0010}
      # Private data at (0009,10FF) -> creator at (0009,0010)
      assert PrivateTag.creator_tag({0x0009, 0x10FF}) == {0x0009, 0x0010}
      # Private data at (0011,FF01) -> creator at (0011,00FF)
      assert PrivateTag.creator_tag({0x0011, 0xFF01}) == {0x0011, 0x00FF}
    end

    test "returns same tag for creator elements" do
      # Creator elements are their own creator tags
      assert PrivateTag.creator_tag({0x0009, 0x0010}) == {0x0009, 0x0010}
      assert PrivateTag.creator_tag({0x0009, 0x00FF}) == {0x0009, 0x00FF}
    end
  end

  describe "creator_element?/1" do
    test "returns true for private creator elements (0010-00FF)" do
      assert PrivateTag.creator_element?({0x0009, 0x0010})
      assert PrivateTag.creator_element?({0x0009, 0x00FF})
      assert PrivateTag.creator_element?({0x0011, 0x0042})
    end

    test "returns false for private data elements" do
      refute PrivateTag.creator_element?({0x0009, 0x1001})
      refute PrivateTag.creator_element?({0x0009, 0xFF01})
    end

    test "returns false for element 0x0000 through 0x000F" do
      refute PrivateTag.creator_element?({0x0009, 0x0000})
      refute PrivateTag.creator_element?({0x0009, 0x000F})
    end

    test "returns false for even groups" do
      refute PrivateTag.creator_element?({0x0010, 0x0010})
    end

    test "returns false for group 0x0001" do
      refute PrivateTag.creator_element?({0x0001, 0x0010})
    end
  end

  describe "creator_for/2" do
    test "returns the creator string for a private data element" do
      ds =
        DataSet.from_list([
          {{0x0009, 0x0010}, :LO, "ACME MEDICAL"},
          {{0x0009, 0x1001}, :LO, "some data"}
        ])

      assert PrivateTag.creator_for(ds, {0x0009, 0x1001}) == "ACME MEDICAL"
    end

    test "returns correct creator when multiple blocks exist" do
      ds =
        DataSet.from_list([
          {{0x0009, 0x0010}, :LO, "ACME MEDICAL"},
          {{0x0009, 0x0011}, :LO, "OTHER VENDOR"},
          {{0x0009, 0x1001}, :LO, "acme data"},
          {{0x0009, 0x1101}, :LO, "other data"}
        ])

      assert PrivateTag.creator_for(ds, {0x0009, 0x1001}) == "ACME MEDICAL"
      assert PrivateTag.creator_for(ds, {0x0009, 0x1101}) == "OTHER VENDOR"
    end

    test "returns nil when creator is missing" do
      ds = DataSet.from_list([{{0x0009, 0x1001}, :LO, "orphan data"}])
      assert PrivateTag.creator_for(ds, {0x0009, 0x1001}) == nil
    end

    test "returns nil for non-private tags" do
      ds = DataSet.from_list([{{0x0010, 0x0010}, :PN, "DOE^JOHN"}])
      assert PrivateTag.creator_for(ds, {0x0010, 0x0010}) == nil
    end
  end

  describe "validate_creators/1" do
    test "returns :ok for data set with all creators present" do
      ds =
        DataSet.from_list([
          {{0x0010, 0x0010}, :PN, "DOE^JOHN"},
          {{0x0009, 0x0010}, :LO, "ACME MEDICAL"},
          {{0x0009, 0x1001}, :LO, "acme data"},
          {{0x0009, 0x1002}, :LO, "more acme data"}
        ])

      assert {:ok, ^ds} = PrivateTag.validate_creators(ds)
    end

    test "returns :ok for data set with no private tags" do
      ds = DataSet.from_list([{{0x0010, 0x0010}, :PN, "DOE^JOHN"}])
      assert {:ok, ^ds} = PrivateTag.validate_creators(ds)
    end

    test "returns :ok for data set with only creator elements (no data)" do
      ds = DataSet.from_list([{{0x0009, 0x0010}, :LO, "ACME MEDICAL"}])
      assert {:ok, ^ds} = PrivateTag.validate_creators(ds)
    end

    test "returns error for private data missing creator" do
      ds =
        DataSet.from_list([
          {{0x0009, 0x1001}, :LO, "orphan data"},
          {{0x0009, 0x1002}, :LO, "more orphan data"}
        ])

      assert {:error, missing} = PrivateTag.validate_creators(ds)
      assert {{0x0009, 0x1001}, :missing_creator} in missing
      assert {{0x0009, 0x1002}, :missing_creator} in missing
    end

    test "returns error only for blocks missing creators" do
      ds =
        DataSet.from_list([
          {{0x0009, 0x0010}, :LO, "ACME MEDICAL"},
          {{0x0009, 0x1001}, :LO, "acme data"},
          {{0x0009, 0x1101}, :LO, "orphan from block 0x11"}
        ])

      assert {:error, missing} = PrivateTag.validate_creators(ds)
      assert [{{0x0009, 0x1101}, :missing_creator}] = missing
    end

    test "validates across multiple private groups" do
      ds =
        DataSet.from_list([
          {{0x0009, 0x0010}, :LO, "VENDOR A"},
          {{0x0009, 0x1001}, :LO, "data a"},
          {{0x0011, 0x2001}, :LO, "orphan in group 0011"}
        ])

      assert {:error, missing} = PrivateTag.validate_creators(ds)
      assert [{{0x0011, 0x2001}, :missing_creator}] = missing
    end

    test "empty data set validates successfully" do
      ds = DataSet.new()
      assert {:ok, ^ds} = PrivateTag.validate_creators(ds)
    end
  end
end
