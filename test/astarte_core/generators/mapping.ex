defmodule Astarte.Core.Properties.Generators.Mapping do
  use PropCheck

  alias Astarte.Core.Properties.Generators.Utils
  alias Astarte.Core.Mapping
  alias Astarte.Core.CQLUtils

  # def mapping(mapping_opts) do
  #   let params <- mapping_params() do
  #     Mapping.changeset(%Mapping{}, params, mapping_opts) |> Ecto.Changeset.apply_action!(:insert)
  #   end
  # end

  def mapping(opts) do
    interface_name = Keyword.fetch!(opts, :interface_name)
    interface_major = Keyword.fetch!(opts, :interface_major)
    interface_id = Keyword.fetch!(opts, :interface_id)
    interface_type = Keyword.get(opts, :interface_type)
    build_mapping(interface_name, interface_major, interface_id, interface_type)
  end

  # # properties
  defp build_mapping(interface_name, interface_major, interface_id, :properties) do
    let [
      endpoint <- endpoint(),
      value_type <- value_type(),
      allow_unset <- allow_unset(),
      doc <- doc(),
      description <- description()
    ] do
      endpoint_id = CQLUtils.endpoint_id(interface_name, interface_major, endpoint)

      %Mapping{
        endpoint: endpoint,
        value_type: value_type,
        allow_unset: allow_unset,
        doc: doc,
        description: description,
        interface_id: interface_id,
        endpoint_id: endpoint_id
      }
    end
  end

  # # datastream
  defp build_mapping(interface_name, interface_major, interface_id, :datastream) do
    let [
      endpoint <- endpoint(),
      value_type <- value_type(),
      reliability <- reliability(),
      retention <- retention(),
      expiry <- expiry(),
      database_retention_policy <- database_retention_policy(),
      database_retention_ttl <- range(60, 20 * 365 * 24 * 60 * 60),
      doc <- doc(),
      description <- description()
    ] do
      # TODO: remember to change it when changing endpoint value
      endpoint_id = CQLUtils.endpoint_id(interface_name, interface_major, endpoint)

      %Mapping{
        endpoint: endpoint,
        value_type: value_type,
        retention: retention,
        reliability: reliability,
        expiry: expiry,
        database_retention_policy: database_retention_policy,
        # 1 = no_ttl
        database_retention_ttl:
          if database_retention_policy != :no_ttl do
            database_retention_ttl
          else
            nil
          end,
        doc: doc,
        description: description,
        interface_id: interface_id,
        endpoint_id: endpoint_id
      }
    end
  end

  def allow_unset() do
    boolean()
  end

  def mapping_to_params(%Mapping{
        endpoint: endpoint,
        value_type: value_type,
        retention: retention,
        reliability: reliability,
        expiry: expiry,
        database_retention_policy: database_retention_policy,
        database_retention_ttl: database_retention_ttl,
        allow_unset: allow_unset,
        description: description,
        doc: doc
      }) do
    %{
      "endpoint" => endpoint,
      "type" => Atom.to_string(value_type),
      "retention" =>
        if retention != nil do
          Atom.to_string(retention)
        else
          nil
        end,
      "reliability" =>
        if reliability != nil do
          Atom.to_string(reliability)
        else
          nil
        end,
      "expiry" =>
        if expiry != nil do
          inspect(expiry)
        else
          nil
        end,
      "database_retention_policy" =>
        if database_retention_policy != nil do
          Atom.to_string(database_retention_policy)
        else
          nil
        end,
      "database_retention_ttl" => database_retention_ttl,
      "allow_unset" => allow_unset,
      "description" => description,
      "doc" => doc
    }
  end

  def endpoint() do
    such_that(s <- endpoint_no_length(), when: String.length(s) > 2 and String.length(s) < 256)
  end

  defp endpoint_no_length() do
    let [
      n <- frequency([{75, range(0, 2)}, {20, range(3, 5)}, {5, range(6, 64)}]),
      pars <- vector(^n, endpoint_element())
    ] do
      "/#{Enum.join(pars, "/")}"
    end
  end

  defp value_type() do
    oneof([
      :double,
      :integer,
      :boolean,
      :longinteger,
      :string,
      :binaryblob,
      :datetime,
      :doublearray,
      :integerarray,
      :booleanarray,
      :longintegerarray,
      :stringarray,
      :binaryblobarray,
      :datetimearray
    ])
  end

  defp retention() do
    oneof([:discard, :volatile, :stored])
  end

  defp reliability() do
    oneof([:unreliable, :guaranteed, :unique])
  end

  defp expiry() do
    non_neg_integer()
  end

  defp database_retention_policy() do
    # default: no_ttl
    oneof([:no_ttl, :use_ttl])
  end

  defp doc() do
    utf8(1_000)
  end

  defp description() do
    utf8(100_000)
  end

  def endpoint_element() do
    frequency([{35, endpoint_param()}, {65, endpoint_static()}])
  end

  def endpoint_param() do
    let val <- endpoint_static() do
      "%{#{val}}"
    end
  end

  def endpoint_static() do
    let s <- Utils.letter_or_underscore() do
      let c <- list(Utils.alphanumeric_or_underscore()) do
        Enum.join([s, c])
      end
    end
  end
end
