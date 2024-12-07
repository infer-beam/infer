defmodule Dx.DateTime do
  @moduledoc false

  use Dx.Defd_

  @impl true
  def __dx_fun_info(_fun_name, _arity) do
    %FunInfo{args: %{all: :preload_scope}}
  end

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
