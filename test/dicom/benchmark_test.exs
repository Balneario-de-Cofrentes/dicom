defmodule Dicom.BenchmarkTest do
  @moduledoc """
  Lightweight performance benchmarks for the DICOM library.

  These tests verify correctness and print timing measurements.
  Hard performance budgets are opt-in via `DICOM_ENFORCE_BENCHMARKS=1`,
  because microbenchmark thresholds are too noisy to serve as reliable
  default gates on arbitrary developer or CI machines.
  """
  use ExUnit.Case, async: true

  @enforce_benchmark_thresholds System.get_env("DICOM_ENFORCE_BENCHMARKS") in [
                                  "1",
                                  "true",
                                  "TRUE"
                                ]

  alias Dicom.DataSet

  import Dicom.TestHelpers,
    only: [pad_to_even: 1, elem_explicit: 3, build_group_length_element: 1]

  describe "parse throughput" do
    test "parses a 50-element data set efficiently" do
      binary = build_large_p10(50)
      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert map_size(ds.elements) == 50

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..1000, do: Dicom.P10.Reader.parse(binary)
        end)

      avg_us = time_us / 1000
      IO.puts("\n  [bench] parse 50-elem: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 1000, "parse 50-elem")
    end

    test "parses a 200-element data set efficiently" do
      binary = build_large_p10(200)
      {:ok, ds} = Dicom.P10.Reader.parse(binary)
      assert map_size(ds.elements) == 200

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..500, do: Dicom.P10.Reader.parse(binary)
        end)

      avg_us = time_us / 500
      IO.puts("\n  [bench] parse 200-elem: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 5000, "parse 200-elem")
    end

    test "parses data set with sequences efficiently" do
      binary = build_p10_with_sequences(10, 5)
      {:ok, _} = Dicom.P10.Reader.parse(binary)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..500, do: Dicom.P10.Reader.parse(binary)
        end)

      avg_us = time_us / 500
      IO.puts("\n  [bench] parse 10-seq×5-items: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 5000, "parse 10-seq×5-items")
    end

    test "parses large pixel data efficiently" do
      pixel_size = 1_048_576
      binary = build_p10_with_pixel_data(pixel_size)
      {:ok, _} = Dicom.P10.Reader.parse(binary)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..100, do: Dicom.P10.Reader.parse(binary)
        end)

      avg_us = time_us / 100
      IO.puts("\n  [bench] parse 1MB pixel: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 5000, "parse 1MB pixel")
    end
  end

  describe "write throughput" do
    test "serializes a 50-element data set efficiently" do
      ds = build_data_set(50)
      {:ok, _} = Dicom.P10.Writer.serialize(ds)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..1000, do: Dicom.P10.Writer.serialize(ds)
        end)

      avg_us = time_us / 1000
      IO.puts("\n  [bench] write 50-elem: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 1000, "write 50-elem")
    end

    test "serializes a 200-element data set efficiently" do
      ds = build_data_set(200)
      {:ok, _} = Dicom.P10.Writer.serialize(ds)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..500, do: Dicom.P10.Writer.serialize(ds)
        end)

      avg_us = time_us / 500
      IO.puts("\n  [bench] write 200-elem: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 5000, "write 200-elem")
    end

    test "serializes data set with sequences efficiently" do
      ds = build_data_set_with_sequences(10, 5)
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, parsed} = Dicom.P10.Reader.parse(binary)
      assert map_size(parsed.elements) == 10

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..500, do: Dicom.P10.Writer.serialize(ds)
        end)

      avg_us = time_us / 500
      IO.puts("\n  [bench] write 10-seq×5-items: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 5000, "write 10-seq×5-items")
    end
  end

  describe "roundtrip throughput" do
    test "roundtrips a 100-element data set efficiently" do
      ds = build_data_set(100)
      {:ok, binary} = Dicom.P10.Writer.serialize(ds)
      {:ok, _} = Dicom.P10.Reader.parse(binary)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..500 do
            {:ok, bin} = Dicom.P10.Writer.serialize(ds)
            Dicom.P10.Reader.parse(bin)
          end
        end)

      avg_us = time_us / 500
      IO.puts("\n  [bench] roundtrip 100-elem: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 5000, "roundtrip 100-elem")
    end
  end

  describe "VR.from_binary hot path" do
    test "VR lookup throughput" do
      vrs = ["PN", "UI", "CS", "LO", "DA", "TM", "SH", "OB", "SQ", "US", "UL", "SS"]

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..100_000 do
            Enum.each(vrs, &Dicom.VR.from_binary/1)
          end
        end)

      ops = 100_000 * length(vrs)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] VR.from_binary: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 500, "VR.from_binary")
    end
  end

  describe "stream parse throughput" do
    test "stream-parses a 50-element data set efficiently" do
      binary = build_large_p10(50)
      {:ok, _} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()
          end
        end)

      avg_us = time_us / 1000
      IO.puts("\n  [bench] stream parse 50-elem: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 2000, "stream parse 50-elem")
    end

    test "stream-parses a 200-element data set efficiently" do
      binary = build_large_p10(200)
      {:ok, _} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..500 do
            binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()
          end
        end)

      avg_us = time_us / 500
      IO.puts("\n  [bench] stream parse 200-elem: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 10000, "stream parse 200-elem")
    end

    test "stream-parses data set with sequences efficiently" do
      binary = build_p10_with_sequences(10, 5)
      {:ok, _} = binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..500 do
            binary |> Dicom.P10.Stream.parse() |> Dicom.P10.Stream.to_data_set()
          end
        end)

      avg_us = time_us / 500
      IO.puts("\n  [bench] stream parse 10-seq×5-items: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 10000, "stream parse 10-seq×5-items")
    end

    test "stream event enumeration (no materialization) is fast" do
      binary = build_large_p10(200)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..500 do
            binary
            |> Dicom.P10.Stream.parse()
            |> Stream.filter(&match?({:element, _}, &1))
            |> Enum.count()
          end
        end)

      avg_us = time_us / 500
      IO.puts("\n  [bench] stream enumerate 200-elem: #{Float.round(avg_us, 1)} µs/op")
      assert_within_budget(avg_us, 10000, "stream enumerate 200-elem")
    end
  end

  describe "Dictionary.Registry.lookup hot path" do
    test "dictionary lookup throughput" do
      tags = [
        {0x0010, 0x0010},
        {0x0010, 0x0020},
        {0x0020, 0x000D},
        {0x0020, 0x000E},
        {0x0008, 0x0060},
        {0x0028, 0x0010},
        {0x0028, 0x0011},
        {0x7FE0, 0x0010},
        {0x0008, 0x0018},
        {0x0002, 0x0010}
      ]

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..100_000 do
            Enum.each(tags, &Dicom.Dictionary.Registry.lookup/1)
          end
        end)

      ops = 100_000 * length(tags)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] Registry.lookup: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 500, "Registry.lookup")
    end
  end

  # ── v0.4.0 Benchmarks ────────────────────────────────────────────────

  describe "VR metadata hot paths" do
    test "VR.description throughput" do
      vrs = Dicom.VR.all()

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..100_000 do
            Enum.each(vrs, &Dicom.VR.description/1)
          end
        end)

      ops = 100_000 * length(vrs)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] VR.description: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 500, "VR.description")
    end

    test "VR.max_length throughput" do
      vrs = Dicom.VR.all()

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..100_000 do
            Enum.each(vrs, &Dicom.VR.max_length/1)
          end
        end)

      ops = 100_000 * length(vrs)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] VR.max_length: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 500, "VR.max_length")
    end

    test "VR.fixed_length? throughput" do
      vrs = Dicom.VR.all()

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..100_000 do
            Enum.each(vrs, &Dicom.VR.fixed_length?/1)
          end
        end)

      ops = 100_000 * length(vrs)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] VR.fixed_length?: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 500, "VR.fixed_length?")
    end
  end

  describe "Tag parsing hot paths" do
    test "Tag.parse throughput (parenthesized)" do
      tags = ["(0010,0010)", "(0020,000D)", "(7FE0,0010)", "(0008,0060)", "(0028,0010)"]

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..100_000 do
            Enum.each(tags, &Dicom.Tag.parse/1)
          end
        end)

      ops = 100_000 * length(tags)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] Tag.parse: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 1000, "Tag.parse")
    end

    test "Tag.from_keyword throughput" do
      keywords = ["PatientName", "StudyInstanceUID", "Modality", "Rows", "PixelData"]

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..50_000 do
            Enum.each(keywords, &Dicom.Tag.from_keyword/1)
          end
        end)

      ops = 50_000 * length(keywords)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] Tag.from_keyword: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 5000, "Tag.from_keyword")
    end
  end

  describe "Date/Time conversion hot paths" do
    test "Value.to_date throughput" do
      dates = ["20240315", "19800101", "20001231", "20250101", "19000101"]

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..100_000 do
            Enum.each(dates, &Dicom.Value.to_date/1)
          end
        end)

      ops = 100_000 * length(dates)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] Value.to_date: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 2000, "Value.to_date")
    end

    test "Value.to_time throughput" do
      times = ["140000", "235959.999999", "1430", "12", "000000"]

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..100_000 do
            Enum.each(times, &Dicom.Value.to_time/1)
          end
        end)

      ops = 100_000 * length(times)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] Value.to_time: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 2000, "Value.to_time")
    end

    test "Value.to_datetime throughput" do
      datetimes = ["20240315140000", "20240315140000.000000+0100", "19800101000000"]

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..50_000 do
            Enum.each(datetimes, &Dicom.Value.to_datetime/1)
          end
        end)

      ops = 50_000 * length(datetimes)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] Value.to_datetime: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 10000, "Value.to_datetime")
    end
  end

  describe "DataSet ergonomics hot paths" do
    test "DataSet.from_list throughput" do
      elements =
        for i <- 1..20 do
          group = 0x0008 + rem(i, 8) * 0x0008
          element = div(i, 8) * 2 + 0x0100
          {{group, element}, :LO, "VALUE_#{i}"}
        end

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..10_000 do
            DataSet.from_list(elements)
          end
        end)

      avg_us = time_us / 10_000
      IO.puts("\n  [bench] DataSet.from_list(20): #{Float.round(avg_us, 1)} µs/op")
      assert avg_us < 500
    end

    test "DataSet bracket access throughput" do
      ds = build_data_set(50)
      tags = Enum.map(ds, & &1.tag) |> Enum.take(10)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..100_000 do
            Enum.each(tags, fn tag -> ds[tag] end)
          end
        end)

      ops = 100_000 * length(tags)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] ds[tag]: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 500, "ds[tag]")
    end

    test "DataSet decoded_value throughput" do
      ds =
        DataSet.from_list([
          {{0x0010, 0x0010}, :PN, "DOE^JOHN "},
          {{0x0028, 0x0010}, :US, <<256::little-16>>},
          {{0x0008, 0x0060}, :CS, "CT "}
        ])

      tags = [{0x0010, 0x0010}, {0x0028, 0x0010}, {0x0008, 0x0060}]

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..100_000 do
            Enum.each(tags, &DataSet.decoded_value(ds, &1))
          end
        end)

      ops = 100_000 * length(tags)
      ns_per_op = time_us * 1000 / ops
      IO.puts("\n  [bench] decoded_value: #{Float.round(ns_per_op, 1)} ns/op (#{ops} ops)")
      assert_within_budget(ns_per_op, 1000, "decoded_value")
    end
  end

  describe "Protocol implementation hot paths" do
    test "Enum.count on DataSet throughput" do
      ds = build_data_set(100)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..50_000, do: Enum.count(ds)
        end)

      avg_us = time_us / 50_000
      IO.puts("\n  [bench] Enum.count(100-elem): #{Float.round(avg_us * 1000, 1)} ns/op")
      assert avg_us < 50
    end

    test "Inspect protocol throughput" do
      ds = build_data_set(50)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..10_000, do: inspect(ds)
        end)

      avg_us = time_us / 10_000
      IO.puts("\n  [bench] inspect(50-elem ds): #{Float.round(avg_us, 1)} µs/op")
      assert avg_us < 500
    end

    test "Enum.map on DataSet throughput" do
      ds = build_data_set(50)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..10_000, do: Enum.map(ds, & &1.tag)
        end)

      avg_us = time_us / 10_000
      IO.puts("\n  [bench] Enum.map(50-elem): #{Float.round(avg_us, 1)} µs/op")
      assert avg_us < 500
    end
  end

  describe "De-identification throughput" do
    test "de-identifies a realistic data set efficiently" do
      ds = build_realistic_data_set()

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..5_000 do
            Dicom.DeIdentification.apply(ds)
          end
        end)

      avg_us = time_us / 5_000
      IO.puts("\n  [bench] DeIdentification.apply: #{Float.round(avg_us, 1)} µs/op")
      assert avg_us < 1000
    end
  end

  describe "DICOM JSON hot paths" do
    test "JSON to_map throughput" do
      ds = build_data_set(50)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..5_000, do: Dicom.Json.to_map(ds)
        end)

      avg_us = time_us / 5_000
      IO.puts("\n  [bench] Json.to_map(50-elem): #{Float.round(avg_us, 1)} µs/op")
      assert avg_us < 2000
    end

    test "JSON roundtrip throughput" do
      ds = build_data_set(20)

      {time_us, _} =
        :timer.tc(fn ->
          for _ <- 1..5_000 do
            m = Dicom.Json.to_map(ds)
            Dicom.Json.from_map(m)
          end
        end)

      avg_us = time_us / 5_000
      IO.puts("\n  [bench] Json roundtrip 20-elem: #{Float.round(avg_us, 1)} µs/op")
      assert avg_us < 2000
    end
  end

  # ---- Helpers ----

  defp build_large_p10(n) do
    ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
    group_length = build_group_length_element(ts_elem)

    data_elems =
      for i <- 1..n do
        group = 0x0008 + rem(i, 8) * 0x0008
        element = div(i, 8) * 2 + 0x0100
        value = pad_to_even("VALUE_#{String.pad_leading(Integer.to_string(i), 6, "0")}")
        elem_explicit({group, element}, :LO, value)
      end

    <<0::1024, "DICM">> <> group_length <> ts_elem <> IO.iodata_to_binary(data_elems)
  end

  defp build_p10_with_sequences(num_sequences, items_per_seq) do
    ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
    group_length = build_group_length_element(ts_elem)

    seq_elems =
      for s <- 1..num_sequences do
        tag = {0x0008, 0x1100 + s * 2}

        items =
          for i <- 1..items_per_seq do
            inner_value = pad_to_even("1.2.3.#{s}.#{i}")

            inner =
              <<0x08, 0x00, 0x50, 0x11, "UI", byte_size(inner_value)::little-16>> <> inner_value

            <<0xFE, 0xFF, 0x00, 0xE0, byte_size(inner)::little-32>> <> inner
          end

        items_binary = IO.iodata_to_binary(items)
        {g, e} = tag

        <<g::little-16, e::little-16, "SQ", 0::16, byte_size(items_binary)::little-32>> <>
          items_binary
      end

    <<0::1024, "DICM">> <> group_length <> ts_elem <> IO.iodata_to_binary(seq_elems)
  end

  defp build_p10_with_pixel_data(size) do
    ts_elem = elem_explicit({0x0002, 0x0010}, :UI, "1.2.840.10008.1.2.1")
    group_length = build_group_length_element(ts_elem)

    pixel_data = :crypto.strong_rand_bytes(size)

    pixel_elem =
      <<0xE0, 0x7F, 0x10, 0x00, "OW", 0::16, byte_size(pixel_data)::little-32>> <> pixel_data

    <<0::1024, "DICM">> <> group_length <> ts_elem <> pixel_elem
  end

  defp build_data_set_with_sequences(num_sequences, items_per_seq) do
    ds =
      DataSet.new()
      |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
      |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
      |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_little_endian())

    Enum.reduce(1..num_sequences, ds, fn s, acc ->
      tag = {0x0008, 0x1100 + s * 2}

      items =
        for i <- 1..items_per_seq do
          %{{0x0008, 0x1150} => Dicom.DataElement.new({0x0008, 0x1150}, :UI, "1.2.3.#{s}.#{i}")}
        end

      elem = Dicom.DataElement.new(tag, :SQ, items)
      %{acc | elements: Map.put(acc.elements, tag, elem)}
    end)
  end

  defp build_realistic_data_set do
    DataSet.new()
    |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
    |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
    |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_little_endian())
    |> DataSet.put({0x0010, 0x0010}, :PN, "DOE^JOHN")
    |> DataSet.put({0x0010, 0x0020}, :LO, "PAT001")
    |> DataSet.put({0x0010, 0x0030}, :DA, "19800101")
    |> DataSet.put({0x0010, 0x0040}, :CS, "M")
    |> DataSet.put({0x0008, 0x0050}, :SH, "ACC123")
    |> DataSet.put({0x0008, 0x0090}, :PN, "SMITH^JANE^DR")
    |> DataSet.put({0x0020, 0x000D}, :UI, "1.2.3.4.5.6.7.8.9.10")
    |> DataSet.put({0x0020, 0x000E}, :UI, "1.2.3.4.5.6.7.8.9.11")
    |> DataSet.put({0x0008, 0x0018}, :UI, "1.2.3.4.5.6.7.8.9.12")
    |> DataSet.put({0x0008, 0x0060}, :CS, "CT")
    |> DataSet.put({0x0008, 0x1030}, :LO, "CT HEAD W/O CONTRAST")
    |> DataSet.put({0x0020, 0x0013}, :IS, "1")
  end

  defp build_data_set(n) do
    ds =
      DataSet.new()
      |> DataSet.put({0x0002, 0x0002}, :UI, "1.2.840.10008.5.1.4.1.1.2")
      |> DataSet.put({0x0002, 0x0003}, :UI, "1.2.3.4.5.6.7.8.9.0")
      |> DataSet.put({0x0002, 0x0010}, :UI, Dicom.UID.explicit_vr_little_endian())

    Enum.reduce(1..n, ds, fn i, acc ->
      group = 0x0008 + rem(i, 8) * 0x0008
      element = div(i, 8) * 2 + 0x0100

      DataSet.put(
        acc,
        {group, element},
        :LO,
        "VALUE_#{String.pad_leading(Integer.to_string(i), 6, "0")}"
      )
    end)
  end

  defp assert_within_budget(value, budget, label) do
    if @enforce_benchmark_thresholds do
      assert value < budget
    else
      IO.puts(
        "  [bench] threshold skipped for #{label}; set DICOM_ENFORCE_BENCHMARKS=1 to enforce"
      )
    end
  end
end
