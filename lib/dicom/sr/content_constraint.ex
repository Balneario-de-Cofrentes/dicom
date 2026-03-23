defmodule Dicom.SR.ContentConstraint do
  @moduledoc """
  PS3.16 content constraint validation for SR templates.

  Validates content trees against structural constraints defined by DICOM
  Structured Report templates. Catches malformed reports at build time before
  serialization.

  A constraint specifies expectations for a content item slot in a template:
  value type, relationship type, cardinality (VM), and optionally the expected
  concept name and CID for coded values.

  ## Violation types

  Violations are tagged tuples describing what went wrong and where:

    - `{:missing_mandatory, concept_meaning, path}` -- required item absent
    - `{:wrong_value_type, [expected: vt, got: vt, path: path]}` -- type mismatch
    - `{:wrong_relationship_type, [expected: rel, got: rel, path: path]}` -- rel mismatch
    - `{:vm_exceeded, [max: vm, count: n, path: path]}` -- too many items
    - `{:cid_warning, [code: code, cid: cid, path: path]}` -- code not in CID (soft)
    - `{:unexpected_children, [count: n, path: path]}` -- children on non-container
  """

  alias Dicom.SR.{Code, ContentItem, ContextGroup}

  @type vm :: :one | :one_or_more | :zero_or_more | :zero_or_one
  @type requirement :: :mandatory | :optional | :conditional

  @type violation ::
          {:missing_mandatory, String.t(), [String.t()]}
          | {:wrong_value_type, keyword()}
          | {:wrong_relationship_type, keyword()}
          | {:vm_exceeded, keyword()}
          | {:cid_warning, keyword()}
          | {:unexpected_children, keyword()}

  @type t :: %__MODULE__{
          concept_name: Code.t() | nil,
          value_type: ContentItem.value_type() | nil,
          relationship_type: String.t() | nil,
          requirement: requirement(),
          vm: vm(),
          children: [t()],
          cid: non_neg_integer() | nil
        }

  @enforce_keys [:value_type]
  defstruct [
    :concept_name,
    :value_type,
    :relationship_type,
    :cid,
    requirement: :mandatory,
    vm: :one,
    children: []
  ]

  @doc """
  Validates a single content item against a constraint.

  Returns `:ok` if the item satisfies the constraint, or `{:error, violations}`
  with a list of violation tuples.
  """
  @spec validate(ContentItem.t(), t()) :: :ok | {:error, [violation()]}
  def validate(%ContentItem{} = item, %__MODULE__{} = constraint) do
    validate_at_path(item, constraint, [])
  end

  @doc """
  Validates a full content tree (list of children) against a list of constraints.

  Each constraint is matched against children by concept name. Mandatory
  constraints that find no matching child produce a violation. Each matched
  child is validated recursively.
  """
  @spec validate_tree([ContentItem.t()], [t()]) :: :ok | {:error, [violation()]}
  def validate_tree(children, constraints) when is_list(children) and is_list(constraints) do
    validate_children(children, constraints, [])
  end

  # -- Internal validation ----------------------------------------------------

  defp validate_at_path(%ContentItem{} = item, %__MODULE__{} = constraint, path) do
    current_path = path ++ [item_label(item)]

    violations =
      []
      |> check_value_type(item, constraint, current_path)
      |> check_relationship_type(item, constraint, current_path)
      |> check_cid(item, constraint, current_path)
      |> check_children(item, constraint, current_path)

    case violations do
      [] -> :ok
      vs -> {:error, vs}
    end
  end

  defp validate_children(children, constraints, path) do
    violations =
      Enum.flat_map(constraints, fn constraint ->
        matching = find_matching(children, constraint)
        count = length(matching)

        missing_violations = check_cardinality(constraint, count, path)

        item_violations =
          Enum.flat_map(matching, fn item ->
            case validate_at_path(item, constraint, path) do
              :ok -> []
              {:error, vs} -> vs
            end
          end)

        missing_violations ++ item_violations
      end)

    case violations do
      [] -> :ok
      vs -> {:error, vs}
    end
  end

  # -- Value type check -------------------------------------------------------

  defp check_value_type(violations, _item, %__MODULE__{value_type: nil}, _path), do: violations

  defp check_value_type(
         violations,
         %ContentItem{value_type: actual},
         %__MODULE__{value_type: expected},
         path
       ) do
    if actual == expected do
      violations
    else
      [{:wrong_value_type, [expected: expected, got: actual, path: path]} | violations]
    end
  end

  # -- Relationship type check ------------------------------------------------

  defp check_relationship_type(violations, _item, %__MODULE__{relationship_type: nil}, _path),
    do: violations

  defp check_relationship_type(
         violations,
         %ContentItem{relationship_type: actual},
         %__MODULE__{relationship_type: expected},
         path
       ) do
    if actual == expected do
      violations
    else
      [{:wrong_relationship_type, [expected: expected, got: actual, path: path]} | violations]
    end
  end

  # -- CID membership check (soft warning) ------------------------------------

  defp check_cid(violations, _item, %__MODULE__{cid: nil}, _path), do: violations

  defp check_cid(violations, %ContentItem{value_type: vt}, _constraint, _path) when vt != :code,
    do: violations

  defp check_cid(violations, %ContentItem{value: %Code{} = code}, %__MODULE__{cid: cid}, path) do
    case ContextGroup.validate(code, cid) do
      :ok -> violations
      {:ok, :extensible} -> violations
      {:error, :unknown_cid} -> violations
      {:error, :not_in_cid} -> [{:cid_warning, [code: code, cid: cid, path: path]} | violations]
    end
  end

  defp check_cid(violations, _item, _constraint, _path), do: violations

  # -- Children / nested container validation ---------------------------------

  defp check_children(
         violations,
         %ContentItem{value_type: :container, children: children},
         %__MODULE__{children: child_constraints},
         path
       )
       when child_constraints != [] do
    case validate_children(children, child_constraints, path) do
      :ok -> violations
      {:error, child_violations} -> violations ++ child_violations
    end
  end

  defp check_children(violations, _item, _constraint, _path), do: violations

  # -- Cardinality checks -----------------------------------------------------

  defp check_cardinality(
         %__MODULE__{requirement: :mandatory, vm: :one, concept_name: cn},
         0,
         path
       ) do
    [{:missing_mandatory, concept_meaning(cn), path}]
  end

  defp check_cardinality(
         %__MODULE__{requirement: :mandatory, vm: :one_or_more, concept_name: cn},
         0,
         path
       ) do
    [{:missing_mandatory, concept_meaning(cn), path}]
  end

  defp check_cardinality(%__MODULE__{vm: :one}, count, path) when count > 1 do
    [{:vm_exceeded, [max: :one, count: count, path: path]}]
  end

  defp check_cardinality(%__MODULE__{vm: :zero_or_one}, count, path) when count > 1 do
    [{:vm_exceeded, [max: :zero_or_one, count: count, path: path]}]
  end

  defp check_cardinality(_constraint, _count, _path), do: []

  # -- Matching helpers -------------------------------------------------------

  defp find_matching(children, %__MODULE__{concept_name: nil, value_type: vt}) do
    Enum.filter(children, fn %ContentItem{value_type: child_vt} -> child_vt == vt end)
  end

  defp find_matching(children, %__MODULE__{concept_name: %Code{} = cn}) do
    Enum.filter(children, fn %ContentItem{concept_name: child_cn} ->
      code_matches?(child_cn, cn)
    end)
  end

  defp code_matches?(%Code{value: v1, scheme_designator: s1}, %Code{
         value: v2,
         scheme_designator: s2
       }) do
    v1 == v2 and s1 == s2
  end

  defp code_matches?(_, _), do: false

  # -- Label helpers ----------------------------------------------------------

  defp item_label(%ContentItem{concept_name: %Code{meaning: meaning}}), do: meaning
  defp item_label(_), do: "unknown"

  defp concept_meaning(%Code{meaning: meaning}), do: meaning
  defp concept_meaning(nil), do: "unspecified"
end
