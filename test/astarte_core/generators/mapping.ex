defmodule Astarte.Core.Properties.Generators.MappingGenerator do
  use PropCheck

  alias Astarte.Core.Properties.Generators.Utils

  def mapping_params() do
    let endpoint <- endpoint() do
      let value_type <- value_type() do
        let retention <- retention() do
          let reliability <- reliability() do
            let expiry <- expiry() do
              let doc <- doc() do
                let description <- description() do
                  let database_retention_policy <- database_retention_policy() do
                    let database_retention_ttl <- range(60, 20 * 365 * 24 * 60 * 60) do
                      %{
                        "endpoint" => endpoint,
                        "type" => value_type,
                        "retention" => retention,
                        "reliability" => reliability,
                        "expiry" => expiry,
                        "database_retention_policy" => database_retention_policy,
                        "database_retention_ttl" =>
                          if database_retention_policy != "no_ttl" do
                            database_retention_ttl
                          else
                            ""
                          end,
                        "doc" => doc,
                        "description" => description
                      }
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  defp endpoint() do
    such_that(s <- endpoint_string(), when: String.length(s) > 2 and String.length(s) < 256)
  end

  defp endpoint_string() do
    let n <- frequency([{70, range(1, 3)}, {20, range(4, 5)}, {10, range(6, 64)}]) do
      let pars <- vector(n, endpoint_element()) do
        "/#{Enum.join(pars, "/")}"
      end
    end
  end

  defp value_type() do
    oneof([
      "double",
      "integer",
      "boolean",
      "longinteger",
      "string",
      "binaryblob",
      "datetime",
      "doublearray",
      "integerarray",
      "booleanarray",
      "longintegerarray",
      "stringarray",
      "binaryblobarray",
      "datetimearray"
    ])
  end

  defp retention() do
    oneof(["discard", "volatile", "stored"])
  end

  defp reliability() do
    oneof(["unreliable", "guaranteed", "unique"])
  end

  defp expiry() do
    non_neg_integer()
  end

  defp database_retention_policy() do
    # default: no_ttl
    oneof(["no_ttl", "use_ttl"])
  end

  defp doc() do
    utf8(1_000)
  end

  defp description() do
    utf8(100_000)
  end

  defp endpoint_element() do
    frequency([{35, endpoint_param()}, {65, endpoint_static()}])
  end

  defp endpoint_param() do
    let val <- endpoint_static() do
      "%{#{val}}"
    end
  end

  defp endpoint_static() do
    let s <- Utils.letter_or_underscore() do
      let c <- list(Utils.alphanumeric_or_underscore()) do
        Enum.join([s, c])
      end
    end
  end
end
