defmodule Dicom.SR do
  @moduledoc """
  Structured Reporting helpers and template builders.

  This namespace provides a reusable SR foundation over the existing
  `Dicom.DataSet` primitives:

  - coded entries
  - content items and relationship trees
  - observation context helpers
  - SR document construction
  - focused builders for selected PS3.16 templates

  The current implementation aims for high practical conformance on the
  generated content trees, while scoping itself to the template builders
  implemented in `Dicom.SR.Templates`.
  """
end
