defmodule Dicom.BenchmarkTest do
  @moduledoc """
  Performance benchmarks and regression tests for the DICOM library.

  These tests measure parse/write throughput and ensure performance
  doesn't regress. Each test verifies correctness AND measures timing.
  """
  use ExUnit.Case, async: true

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
      assert avg_us < 1000
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
      assert avg_us < 5000
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
      assert avg_us < 5000
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
      assert avg_us < 5000
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
      assert avg_us < 1000
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
      assert avg_us < 5000
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
      assert avg_us < 5000
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
      assert avg_us < 5000
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
      assert ns_per_op < 500
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
      assert avg_us < 2000
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
      assert avg_us < 10000
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
      assert avg_us < 10000
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
      assert avg_us < 10000
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
      assert ns_per_op < 500
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
end
