defmodule Dicom.SR.ImageLibrary do
  @moduledoc """
  Builder for a TID 1600 Image Library container.

  Groups source image references into an Image Library structure suitable
  for inclusion in SR documents such as TID 1500 Measurement Reports.

  Structure:

      CONTAINER: Image Library
        └── CONTAINS: IMAGE references (1-n)
  """

  alias Dicom.SR.{Codes, ContentItem, Reference}

  @spec build([Reference.t()]) :: ContentItem.t()
  def build(references) when is_list(references) and references != [] do
    ContentItem.container(Codes.image_library(),
      relationship_type: "CONTAINS",
      children:
        Enum.map(references, fn %Reference{} = reference ->
          ContentItem.image(Codes.source(), reference, relationship_type: "CONTAINS")
        end)
    )
  end
end
