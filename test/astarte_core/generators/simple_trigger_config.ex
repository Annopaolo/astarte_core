defmodule Astarte.Core.Properties.Generators.SimpleTriggerConfigGenerator do
  use PropCheck

  alias Astarte.Core.Properties.Generators.Mapping
  alias Astarte.Core.Properties.Generators.Interface
  alias Astarte.Core.Properties.Generators.Utils
  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleTriggerConfig

  def simple_trigger_config() do
    oneof([data_trigger(), device_trigger()])
  end

  def simple_trigger_config(interface) do
    oneof([data_trigger(interface), device_trigger()])
  end

  def data_trigger() do
    let [
      %{group_name: group_name, device_id: device_id} <- trigger_common(),
      data_trigger_condition <- data_trigger_condition(),
      value_match_operator <- value_match_operator(),
      match_path <- match_path(),
      known_value <- oneof([known_value(), nil])
    ] do
      %SimpleTriggerConfig{
        group_name: group_name,
        device_id: device_id,
        type: "data_trigger",
        on: data_trigger_condition,
        interface_name: "*",
        interface_major: nil,
        value_match_operator: value_match_operator,
        match_path: match_path,
        known_value: known_value
      }
      |> rectify_interface_vs_match_vs_on()
      |> validate_value_match_match_path()
      |> validate_value_match_op_known_value()
    end
  end

  def data_trigger(interface) do
    let [
      %{group_name: group_name, device_id: device_id} <- trigger_common(),
      data_trigger_condition <- data_trigger_condition(),
      value_match_operator <- value_match_operator(),
      # TODO must be one of the interface's possible paths
      match_path <- match_path(interface),
      known_value <- oneof([known_value(), nil])
    ] do
      %SimpleTriggerConfig{
        group_name: group_name,
        device_id: device_id,
        type: "data_trigger",
        on: data_trigger_condition,
        interface_name: interface.interface_name,
        interface_major: interface.interface_major,
        value_match_operator: value_match_operator,
        match_path: match_path,
        known_value: known_value
      }
      |> rectify_interface_vs_match_vs_on()
      |> validate_value_match_match_path()
      |> validate_value_match_op_known_value()
    end
  end

  def simple_trigger_config_to_params(%SimpleTriggerConfig{
        group_name: group_name,
        device_id: device_id,
        type: type,
        on: data_trigger_condition,
        interface_name: nterface_name,
        interface_major: interface_major,
        value_match_operator: value_match_operator,
        match_path: match_path,
        known_value: known_value
      }) do
    %{
      "group_name" => group_name,
      "device_id" => device_id,
      "type" => type,
      "on" => data_trigger_condition,
      "interface_name" => nterface_name,
      "interface_major" => interface_major,
      "value_match_operator" => value_match_operator,
      "match_path" => match_path,
      "known_value" => known_value
    }
  end

  defp rectify_interface_vs_match_vs_on(config = %SimpleTriggerConfig{interface_name: "*"}) do
    %SimpleTriggerConfig{config | on: "incoming_data", match_path: "/*"}
  end

  defp rectify_interface_vs_match_vs_on(config) do
    config
  end

  defp validate_value_match_match_path(config = %SimpleTriggerConfig{match_path: "/*"}) do
    %SimpleTriggerConfig{config | value_match_operator: "*"}
  end

  defp validate_value_match_match_path(config) do
    config
  end

  defp validate_value_match_op_known_value(
         config = %SimpleTriggerConfig{value_match_operator: "*"}
       ) do
    %SimpleTriggerConfig{config | known_value: nil}
  end

  defp validate_value_match_op_known_value(config) do
    config
  end

  def value_match_operator() do
    oneof([
      "*",
      "==",
      "!=",
      ">",
      ">=",
      "<",
      "<=",
      "contains",
      "not_contains"
    ])
  end

  def match_path() do
    oneof(["/*", Mapping.endpoint()])
  end

  def match_path(interface) do
    let n <- range(0, length(interface.mappings)) do
      # Lord forgive me
      mapping = get_in(interface.mappings, [Access.at(n)])

      let path <- generate_path_from_endpoint(mapping.endpoint) do
        path
      end
    end
  end

  defp generate_path_from_endpoint(endpoint) do
    endpoint
    |> String.split("/")
    |> Enum.map(fn part ->
      if String.starts_with?(part, "%") do
        let new_part <- Utils.letter_string() do
          new_part
        end
      else
        part
      end
    end)
    |> Enum.join("/")
  end

  def known_value() do
    utf8()
  end

  def device_trigger() do
    let [
      %{group_name: group_name, device_id: device_id} <- trigger_common(),
      device_trigger_condition <- device_trigger_condition()
    ] do
      %SimpleTriggerConfig{
        group_name: group_name,
        device_id: device_id,
        type: "device_trigger",
        on: device_trigger_condition
      }
    end
  end

  def trigger_common() do
    let group_name <- oneof([group_name(), nil]) do
      if group_name == nil do
        let device_id <- device_id() do
          %{group_name: nil, device_id: device_id}
        end
      else
        %{group_name: group_name, device_id: nil}
      end
    end
  end

  def data_trigger_condition() do
    oneof([
      "incoming_data",
      "value_change",
      "value_change_applied",
      "path_created",
      "path_removed",
      "value_stored"
    ])
  end

  def device_trigger_condition() do
    oneof([
      "device_connected",
      "device_disconnected",
      "device_empty_cache_received",
      "device_error"
    ])
  end

  def group_name() do
    # let name <- non_empty(utf8()) do
    #   # TODO change into meaningful prefixes
    #   name |> String.replace_prefix("~", "a") |> String.replace_prefix("@", "a")
    # end
    such_that(name <- non_empty(utf8()), when: not String.starts_with?(name, ["@", "~"]))
  end

  def device_id() do
    oneof(["*", Device.random_device_id() |> Device.encode_device_id()])
  end
end
