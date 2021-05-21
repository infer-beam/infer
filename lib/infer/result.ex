defmodule Infer.Result do
  @moduledoc """
  Result type definition `t:t()` and helpers to work with it.
  """

  @typedoc """
  Possible return values from resolving predicates.
  """
  @type t() :: {:ok, any()} | {:not_loaded, any()} | {:error, any()}

  @doc """
  Returns `{:ok, true}` if `fun` evaluates to `{:ok, true}` for all elements in `enum`.
  Otherwise, returns `{:not_loaded, data_reqs}` if any yield that.
  Otherwise, returns `{:ok, false}`.

  ## Examples

      iex> [
      ...>   {:ok, true},
      ...>   {:not_loaded, []},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.all?()
      {:ok, false}

      iex> [
      ...>   {:ok, true},
      ...>   {:not_loaded, []},
      ...>   {:ok, true},
      ...> ]
      ...> |> Infer.Result.all?()
      {:not_loaded, []}

      iex> [
      ...>   {:ok, true},
      ...>   {:ok, true},
      ...> ]
      ...> |> Infer.Result.all?()
      {:ok, true}
  """
  def all?(enum, mapper \\ nil) do
    mapper = mapper || (& &1)

    Enum.reduce_while(enum, {:ok, true}, fn elem, acc ->
      combine(acc, mapper.(elem), :all?)
    end)
  end

  @doc """
  Returns `{:ok, true}` if `fun` evaluates to `{:ok, true}` for any element in `enum`.
  Otherwise, returns `{:not_loaded, data_reqs}` if any yields that.
  Otherwise, returns `{:ok, false}`.

  ## Examples

      iex> [
      ...>   {:ok, true},
      ...>   {:not_loaded, []},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.any?()
      {:ok, true}

      iex> [
      ...>   {:ok, false},
      ...>   {:not_loaded, []},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.any?()
      {:not_loaded, []}

      iex> [
      ...>   {:ok, false},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.any?()
      {:ok, false}
  """
  def any?(enum, mapper \\ nil) do
    mapper = mapper || (& &1)

    Enum.reduce_while(enum, {:ok, false}, fn elem, acc ->
      combine(acc, mapper.(elem), :any?)
    end)
  end

  @doc """
  Returns `{:ok, elem}` with the first `elem` for which `fun` evaluates to `{:ok, true}`.
  Returns `{:not_loaded, data_reqs}` combining all `elem`s before that yield `{:not_loaded, data_reqs}`.
  Otherwise, returns `{:ok, default}`.

  ## Examples

      iex> [
      ...>   {:ok, true},
      ...>   {:not_loaded, []},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.first()
      {:ok, {:ok, true}}

      iex> [
      ...>   {:ok, false},
      ...>   {:not_loaded, [1]},
      ...>   {:not_loaded, [2]},
      ...>   {:ok, true},
      ...>   {:not_loaded, [3]},
      ...> ]
      ...> |> Infer.Result.first()
      {:not_loaded, [1, 2]}

      iex> [
      ...>   {:ok, false},
      ...>   {:ok, false},
      ...> ]
      ...> |> Infer.Result.first()
      {:ok, nil}
  """
  def first(enum, mapper \\ nil, result_mapper \\ nil, default \\ nil) do
    mapper = mapper || (& &1)
    result_mapper = result_mapper || (& &1)

    Enum.reduce_while(enum, {:ok, false}, fn elem, acc ->
      combine(acc, mapper.(elem), :first)
      |> case do
        {:halt, {:ok, true}} -> {:halt, {:ok, result_mapper.(elem)}}
        other -> other
      end
    end)
    |> case do
      {:ok, false} -> {:ok, default}
      other -> other
    end
  end

  @doc """
  The convenience functions `all?/2`, `any?/2` and `first/2` use this under the hood.

  Passed to `Enum.reduce_while/3` to combine 2 results on each call.

  Result is either
    - `{:error, e}`
    - `{:not_loaded, data_reqs}` if the result could not be determined without loading more data
    - `{:ok, result}` depending on third arg (see below)

  Third arg can be either
    - `:any?` (logical `OR`)
    - `:all?` (logical `AND`)
    - `:first` to return `{:ok, result}` on first match

  `{:not_loaded, all_reqs}` is only returned if the data is really needed.

  For example, using `:all?` with 3 conditions A, B and C, where

      iex> [
      ...>   {:ok, true},       # A
      ...>   {:not_loaded, []}, # B
      ...>   {:ok, false},      # C
      ...> ]
      ...> |> Enum.reduce_while({:ok, true}, &Infer.Result.combine(&2, &1, :all?))
      {:ok, false}

  The overall result is `{:ok, false}`.
  While B would need more data to be loaded, C can already determind and is `false`,
  so and any additional data loaded will not change that.

  Another example, using `:first` with 5 conditions A, B, C, D and E, where

      iex> [
      ...>   {:ok, false},       # A
      ...>   {:not_loaded, [1]}, # B
      ...>   {:not_loaded, [2]}, # C
      ...>   {:ok, true},        # D
      ...>   {:not_loaded, [3]}, # E
      ...> ]
      ...> |> Enum.reduce_while({:ok, false}, &Infer.Result.combine(&2, &1, :first))
      {:not_loaded, [1, 2]}

  The overall result is `{:not_loaded, data_reqs1 + data_reqs2}`.
  While D can already be determined and is `{:ok, true}`, B and C come first and need more data
  to be loaded, so they can be determined and returned if either is `{:ok, true}` first.
  All data requirements that might be needed are returned together in the result (those of B and C),
  while those of E can be ruled out, as D already returns `{:ok, true}` and comes first.
  """
  def combine(_acc, {:error, e}, _), do: {:halt, {:error, e}}
  def combine({:not_loaded, r1}, {:not_loaded, r2}, _), do: {:cont, {:not_loaded, r1 ++ r2}}
  def combine(_acc, {:not_loaded, reqs}, _), do: {:cont, {:not_loaded, reqs}}

  def combine({:not_loaded, reqs}, {:ok, true}, :first), do: {:halt, {:not_loaded, reqs}}
  def combine({:not_loaded, reqs}, {:ok, false}, :first), do: {:cont, {:not_loaded, reqs}}
  def combine({:ok, false}, {:ok, true}, :first), do: {:halt, {:ok, true}}
  def combine(acc, {:ok, false}, :first), do: {:cont, acc}

  def combine(_acc, {:ok, true}, :any?), do: {:halt, {:ok, true}}
  def combine(_acc, {:ok, false}, :all?), do: {:halt, {:ok, false}}
  def combine(acc, {:ok, false}, :any?), do: {:cont, acc}
  def combine(acc, {:ok, true}, :all?), do: {:cont, acc}
end
