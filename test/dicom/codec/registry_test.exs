defmodule Dicom.Codec.RegistryTest do
  use ExUnit.Case, async: false

  alias Dicom.Codec.Registry

  # Reset the registry between tests since it uses persistent_term
  setup do
    Registry.reset()
    on_exit(fn -> Registry.reset() end)
    :ok
  end

  # ── A dummy codec for testing ───────────────────────────────────

  defmodule DummyCodec do
    @behaviour Dicom.Codec

    @impl true
    def decode(_data, _metadata), do: {:ok, <<>>}

    @impl true
    def encode(_data, _metadata), do: {:ok, <<>>}

    @impl true
    def transfer_syntax_uids, do: ["1.2.3.4.5.6.7.8.9"]
  end

  defmodule MultiUidCodec do
    @behaviour Dicom.Codec

    @impl true
    def decode(_data, _metadata), do: {:ok, <<>>}

    @impl true
    def encode(_data, _metadata), do: {:ok, <<>>}

    @impl true
    def transfer_syntax_uids, do: ["9.8.7.6.5", "9.8.7.6.6"]
  end

  # ── Built-in registration ───────────────────────────────────────

  describe "built-in codecs" do
    test "RLE codec is registered automatically on first lookup" do
      assert {:ok, Dicom.Codec.RLE} = Registry.lookup("1.2.840.10008.1.2.5")
    end

    test "RLE appears in registered/0" do
      registered = Registry.registered()
      assert {"1.2.840.10008.1.2.5", Dicom.Codec.RLE} in registered
    end
  end

  # ── register/1 ──────────────────────────────────────────────────

  describe "register/1" do
    test "registers a codec module for its UIDs" do
      assert :ok = Registry.register(DummyCodec)
      assert {:ok, DummyCodec} = Registry.lookup("1.2.3.4.5.6.7.8.9")
    end

    test "registers a codec with multiple UIDs" do
      assert :ok = Registry.register(MultiUidCodec)
      assert {:ok, MultiUidCodec} = Registry.lookup("9.8.7.6.5")
      assert {:ok, MultiUidCodec} = Registry.lookup("9.8.7.6.6")
    end

    test "overwrites existing registration for same UID" do
      Registry.register(DummyCodec)
      Registry.register(MultiUidCodec)

      # DummyCodec's UID should still be DummyCodec
      assert {:ok, DummyCodec} = Registry.lookup("1.2.3.4.5.6.7.8.9")
    end

    test "does not remove built-in codecs" do
      Registry.register(DummyCodec)
      assert {:ok, Dicom.Codec.RLE} = Registry.lookup("1.2.840.10008.1.2.5")
    end
  end

  # ── lookup/1 ────────────────────────────────────────────────────

  describe "lookup/1" do
    test "returns :error for unknown UID" do
      assert :error = Registry.lookup("99.99.99.99")
    end

    test "returns {:ok, module} for registered UID" do
      assert {:ok, Dicom.Codec.RLE} = Registry.lookup("1.2.840.10008.1.2.5")
    end
  end

  # ── deregister/1 ────────────────────────────────────────────────

  describe "deregister/1" do
    test "removes a registered codec" do
      Registry.register(DummyCodec)
      assert {:ok, DummyCodec} = Registry.lookup("1.2.3.4.5.6.7.8.9")

      assert :ok = Registry.deregister("1.2.3.4.5.6.7.8.9")
      assert :error = Registry.lookup("1.2.3.4.5.6.7.8.9")
    end

    test "is a no-op for unknown UID" do
      assert :ok = Registry.deregister("99.99.99.99")
    end

    test "does not affect other registered codecs" do
      Registry.register(DummyCodec)
      Registry.deregister("1.2.3.4.5.6.7.8.9")
      assert {:ok, Dicom.Codec.RLE} = Registry.lookup("1.2.840.10008.1.2.5")
    end
  end

  # ── registered/0 ────────────────────────────────────────────────

  describe "registered/0" do
    test "returns all registered pairs" do
      Registry.register(DummyCodec)
      registered = Registry.registered()

      assert {"1.2.840.10008.1.2.5", Dicom.Codec.RLE} in registered
      assert {"1.2.3.4.5.6.7.8.9", DummyCodec} in registered
    end
  end

  # ── reset/0 ─────────────────────────────────────────────────────

  describe "reset/0" do
    test "removes custom codecs but keeps built-ins" do
      Registry.register(DummyCodec)
      assert {:ok, DummyCodec} = Registry.lookup("1.2.3.4.5.6.7.8.9")

      Registry.reset()
      assert :error = Registry.lookup("1.2.3.4.5.6.7.8.9")
      assert {:ok, Dicom.Codec.RLE} = Registry.lookup("1.2.840.10008.1.2.5")
    end
  end
end
