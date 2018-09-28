defmodule Astarte.Core.Mapping.ValueTypeTest do
  use ExUnit.Case
  alias Astarte.Core.Mapping.ValueType

  test "valid values are accepted" do
    assert ValueType.validate_value(:double, 1.1) == :ok
    assert ValueType.validate_value(:double, 1.0) == :ok
    assert ValueType.validate_value(:double, 1) == :ok
    assert ValueType.validate_value(:double, 0xCAFECAFECAFE) == :ok

    assert ValueType.validate_value(:integer, 15) == :ok
    assert ValueType.validate_value(:integer, 0x7FFFFFFF) == :ok

    assert ValueType.validate_value(:longinteger, 0xCAFECAFECAFE) == :ok

    assert ValueType.validate_value(:string, "Astarte です") == :ok

    assert ValueType.validate_value(:boolean, true) == :ok
    assert ValueType.validate_value(:boolean, false) == :ok

    assert ValueType.validate_value(:binaryblob, <<0, 1, 2, 3, 4>>) == :ok

    assert ValueType.validate_value(:datetime, 1_538_131_554_304) == :ok
    assert ValueType.validate_value(:datetime, %Bson.UTC{ms: 1_538_131_554_304}) == :ok
  end

  test "invalid values are not accepted" do
    assert ValueType.validate_value(:double, true) == {:error, :unexpected_value_type}
    assert ValueType.validate_value(:double, "1.0") == {:error, :unexpected_value_type}

    assert ValueType.validate_value(:integer, 2.7) == {:error, :unexpected_value_type}

    assert ValueType.validate_value(:integer, 0xCAFECAFECAFE) == {:error, :unexpected_value_type}

    assert ValueType.validate_value(:longinteger, 1.1) == {:error, :unexpected_value_type}

    assert ValueType.validate_value(:longinteger, 0xCAFECAFECAFECAFECAFECAFE) ==
             {:error, :unexpected_value_type}

    assert ValueType.validate_value(:string, <<0xFFFF::16>>) == {:error, :unexpected_value_type}

    assert ValueType.validate_value(:string, :not_a_string) == {:error, :unexpected_value_type}

    assert ValueType.validate_value(:boolean, 5) == {:error, :unexpected_value_type}

    assert ValueType.validate_value(:boolean, :not_boolean) == {:error, :unexpected_value_type}

    assert ValueType.validate_value(:boolean, nil) == {:error, :unexpected_value_type}
    assert ValueType.validate_value(:boolean, "true") == {:error, :unexpected_value_type}

    assert ValueType.validate_value(:binaryblob, 9) == {:error, :unexpected_value_type}

    assert ValueType.validate_value(:datetime, 22.3) == {:error, :unexpected_value_type}

    assert ValueType.validate_value(:datetime, :not_a_date) == {:error, :unexpected_value_type}
  end
end
