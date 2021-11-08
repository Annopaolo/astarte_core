defmodule Astarte.Core.Properties.Generators.Interface do
  use PropCheck

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Properties.Generators.Utils
  alias Astarte.Core.Properties.Generators.Mapping, as: MappingGenerator
  alias Astarte.Core.Mapping
  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping.EndpointsAutomaton

  def object_aggregated_interface() do
    such_that(int <- interface(), when: int.aggregation == :object)
  end

  def individual_aggregated_interface() do
    such_that(int <- interface(), when: int.aggregation == :individual)
  end

  def interface() do
    let [
      interface_opts <- interface_opts(),
      mappings <- mappings(^interface_opts),
      minor <- interface_minor(),
      ownership <- interface_ownership(),
      aggregation <- interface_aggregation()
    ] do
      interface_type = Keyword.fetch!(interface_opts, :interface_type)

      new_aggregation =
        if interface_type == :datastream,
          do: aggregation,
          else: :individual

      make_interface(interface_opts, mappings, minor, ownership, new_aggregation)
    end
  end

  defp make_interface(interface_opts, mappings, minor, ownership, aggregation) do
    interface = %Interface{
      interface_name: Keyword.fetch!(interface_opts, :interface_name),
      version_major: Keyword.fetch!(interface_opts, :interface_major),
      type: Keyword.fetch!(interface_opts, :interface_type),
      version_minor: minor,
      aggregation: aggregation,
      ownership: ownership,
      mappings: mappings
    }

    let res <- edit_endpoints_if_needed(interface) do
      res |> cleanup_mappings() |> remove_conflicting_endpoints() |> drop_duplicate_endpoints()
    end
  end

  defp drop_duplicate_endpoints(interface) do
    new_mappings =
      Enum.uniq_by(interface.mappings, fn mapping ->
        Mapping.normalize_endpoint(mapping.endpoint)
        String.downcase(mapping.endpoint)
      end)

    %Interface{interface | mappings: new_mappings}
  end

  defp remove_conflicting_endpoints(interface) do
    new_mappings =
      interface.mappings
      |> Enum.reduce([], fn mapping, acc ->
        tested = [mapping | acc]

        case EndpointsAutomaton.build(tested) do
          {:ok, _} -> tested
          _ -> acc
        end
      end)

    %Interface{interface | mappings: new_mappings}
  end

  defp edit_endpoints_if_needed(interface = %Interface{aggregation: :object}) do
    such_that(int <- edit_endpoints_for_object_aggregation(interface), when: are_ok(int.mappings))
  end

  defp edit_endpoints_if_needed(interface = %Interface{aggregation: :individual}),
    do: interface

  # useless branch
  defp edit_endpoints_for_object_aggregation(interface = %Interface{aggregation: :individual}),
    do: interface

  defp edit_endpoints_for_object_aggregation(interface = %Interface{aggregation: :object}) do
    let [
      endpoint_length <- frequency([{75, range(1, 3)}, {20, range(4, 5)}, {5, range(6, 64)}])
    ] do
      interface_name = interface.interface_name
      interface_major = interface.version_major

      # generate a N endpoint strings,
      # and substitute them in the interface

      let new_endpoints <-
            make_object_aggregated_endpoints(
              length(interface.mappings),
              endpoint_length,
              endpoint_length
            ) do
        new_mappings =
          Enum.zip(interface.mappings, new_endpoints)
          |> Enum.map(fn {old, new_string} ->
            %Mapping{
              old
              | endpoint: new_string,
                endpoint_id: CQLUtils.endpoint_id(interface_name, interface_major, new_string)
            }
          end)

        %Interface{interface | mappings: uniform_attributes(new_mappings)}
      end
    end
  end

  defp uniform_attributes([]), do: []

  defp uniform_attributes(mappings) do
    chosen_one = List.first(mappings)

    Enum.map(mappings, fn mapping ->
      %Mapping{
        mapping
        | retention: chosen_one.retention,
          reliability: chosen_one.reliability,
          expiry: chosen_one.expiry,
          allow_unset: chosen_one.allow_unset,
          explicit_timestamp: chosen_one.explicit_timestamp
      }
    end)
  end

  defp make_object_aggregated_endpoints(
         endpoints_number,
         _endpoint_length = 0,
         _max_endpoint_length
       ) do
    vector(endpoints_number, "")
  end

  defp make_object_aggregated_endpoints(
         endpoints_number,
         endpoint_length,
         max_endpoint_length
       ) do
    let [
      endpoints <-
        make_object_aggregated_endpoints(
          endpoints_number,
          endpoint_length - 1,
          max_endpoint_length
        ),
      parametric? <- boolean()
    ] do
      if parametric? do
        let part <- MappingGenerator.endpoint_param() do
          Enum.map(endpoints, fn string -> "#{string}/#{part}" end)
        end
      else
        if endpoint_length == max_endpoint_length do
          # all prefixes up to now are the same, we must distinguish the endpoints
          Enum.map(endpoints, fn string ->
            let part <- MappingGenerator.endpoint_static() do
              "#{string}/#{part}"
            end
          end)
        else
          # we are building a prefix, so we need to keep endpoints equal
          let part <- MappingGenerator.endpoint_static() do
            Enum.map(endpoints, fn string -> "#{string}/#{part}" end)
          end
        end
      end
    end
  end

  # properties
  defp cleanup_mappings(interface = %Interface{type: :properties}) do
    new_mappings =
      interface.mappings
      |> Enum.map(fn mapping ->
        %Mapping{
          mapping
          | expiry: nil,
            retention: nil,
            reliability: nil,
            database_retention_policy: nil,
            database_retention_ttl: nil,
            explicit_timestamp: nil
        }
      end)

    # properties interfaces cannot have object aggregation
    %Interface{interface | mappings: new_mappings, aggregation: :individual}
  end

  # datastream
  defp cleanup_mappings(interface = %Interface{type: :datastream, mappings: mappings}) do
    new_mappings =
      mappings
      |> Enum.map(fn mapping ->
        %Mapping{
          mapping
          | allow_unset: nil
        }
      end)

    %Interface{interface | mappings: new_mappings}
  end

  def interface_to_params(%Interface{
        interface_name: interface_name,
        version_major: interface_major,
        type: interface_type,
        version_minor: minor,
        aggregation: aggregation,
        ownership: ownership,
        mappings: mappings
      }) do
    %{
      "interface_name" => interface_name,
      "version_major" => interface_major,
      "type" => Atom.to_string(interface_type),
      "version_minor" => minor,
      "aggregation" => Atom.to_string(aggregation),
      "ownership" => Atom.to_string(ownership),
      "mappings" => mappings |> Enum.map(fn m -> MappingGenerator.mapping_to_params(m) end)
    }
  end

  def interface_name() do
    such_that(name <- interface_name_no_length(), when: String.length(name) <= 128)
  end

  defp interface_name_no_length() do
    let [
      ending <- interface_name_part(),
      n <- frequency([{70, range(0, 3)}, {20, range(4, 5)}, {10, non_neg_integer()}]),
      parts <- vector(^n, interface_name_part())
    ] do
      beginning = "#{Enum.join(parts, ".")}"

      case beginning do
        "" -> ending
        _ -> "#{beginning}.#{ending}"
      end
    end
  end

  def interface_major() do
    pos_integer()
  end

  def interface_minor() do
    pos_integer()
  end

  def interface_type() do
    oneof([:datastream, :properties])
  end

  def interface_ownership() do
    oneof([:device, :server])
  end

  def interface_aggregation() do
    oneof([:individual, :object])
  end

  def interface_opts do
    let [name <- interface_name(), major <- interface_major(), type <- interface_type()] do
      [
        interface_name: name,
        interface_major: major,
        interface_type: type,
        interface_id: CQLUtils.interface_id(name, major)
      ]
    end
  end

  def mappings(mapping_opts) do
    # TODO check 1024
    let [
      n <-
        frequency([{2, exactly(1)}, {80, range(2, 4)}, {17, range(4, 8)}, {1, range(9, 1024)}]),
      mappings <- vector(^n, MappingGenerator.mapping(mapping_opts))
    ] do
      mappings
    end
  end

  defp interface_name_part() do
    let s <- Utils.letter() do
      let c <- list(Utils.alphanumeric()) do
        Enum.join([s, c])
      end
    end
  end

  defp are_ok(mappings) do
    Enum.all?(mappings, fn mapping ->
      String.length(mapping.endpoint) > 2 and String.length(mapping.endpoint) < 256
    end)
  end
end
