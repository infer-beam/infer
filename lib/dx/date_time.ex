defmodule Dx.DateTime do
  @moduledoc false

  use Dx.Defd_

  @moduledx_ args: %{all: :preload_scope}

  defscope after?(left, right, generate_fallback) do
    quote do: {:gt, unquote(left), unquote(right), unquote(generate_fallback.())}
  end

  defscope before?(left, right, generate_fallback) do
    quote do: {:lt, unquote(left), unquote(right), unquote(generate_fallback.())}
  end

  defscope compare(left, right, generate_fallback) do
    quote do: {:compare, unquote(left), unquote(right), unquote(generate_fallback.())}
  end
end
