defmodule Astarte.Core.Properties.Generators.Utils do
  use PropCheck

  def letter_string do
    let l <- non_empty(letter()) do
      Enum.join(l)
    end
  end

  def alphanumeric_or_underscore() do
    oneof(
      Enum.concat([?_..?_, ?a..?z, ?A..?Z, ?0..?9])
      |> Enum.map(fn x -> <<x::utf8>> end)
    )
  end

  def letter_or_underscore() do
    oneof(
      Enum.concat([?_..?_, ?a..?z, ?A..?Z])
      |> Enum.map(fn x -> <<x::utf8>> end)
    )
  end

  def letter() do
    oneof(
      Enum.concat([?a..?z, ?A..?Z])
      |> Enum.map(fn x -> <<x::utf8>> end)
    )
  end

  def alphanumeric() do
    oneof(
      Enum.concat([?a..?z, ?A..?Z, ?0..?9])
      |> Enum.map(fn x -> <<x::utf8>> end)
    )
  end
end
