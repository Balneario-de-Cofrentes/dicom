defmodule Dicom.P10.Stream.Event do
  @moduledoc """
  Event types emitted by the streaming DICOM P10 parser.

  The streaming parser emits a sequence of events as it traverses a DICOM
  P10 binary. This enables processing DICOM data without loading the entire
  file into memory.

  ## Event Sequence

  A typical DICOM file produces events in this order:

      :file_meta_start
      {:element, %DataElement{tag: {0x0002, ...}}}   # file meta elements
      {:file_meta_end, transfer_syntax_uid}
      {:element, %DataElement{tag: {0x0008, ...}}}   # data set elements
      {:sequence_start, tag, length}                  # if SQ present
        {:item_start, length}
          {:element, ...}                             # item elements
        :item_end
      :sequence_end
      {:pixel_data_start, tag, vr}                   # if encapsulated
        {:pixel_data_fragment, 0, binary}            # BOT + fragments
      :pixel_data_end
      :end

  Reference: DICOM PS3.5 Section 7.
  """

  @type t ::
          :file_meta_start
          | {:file_meta_end, String.t()}
          | {:element, Dicom.DataElement.t()}
          | {:sequence_start, Dicom.DataElement.tag(), non_neg_integer() | :undefined}
          | :sequence_end
          | {:item_start, non_neg_integer() | :undefined}
          | :item_end
          | {:pixel_data_start, Dicom.DataElement.tag(), Dicom.VR.t()}
          | {:pixel_data_fragment, non_neg_integer(), binary()}
          | :pixel_data_end
          | :end
          | {:error, term()}
end
