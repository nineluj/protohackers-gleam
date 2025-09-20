import gleam/float
import gleam/int
import gleam/json
import parser
import prime_math
import types

pub fn create_is_prime_response(status: Bool) -> String {
  json.object([
    #("method", json.string("isPrime")),
    #("prime", json.bool(status)),
  ])
  |> json.to_string
  <> "\n"
}

pub fn handle_message(msg_str: String) -> Result(String, String) {
  case parser.parse_message(msg_str) {
    Error(_) -> Error("Bad json")
    Ok(request) -> {
      case request.method {
        "isPrime" -> {
          let prime = case request.number {
            types.IntValue(n) -> prime_math.is_prime(n)
            types.FloatValue(f) -> {
              let trunc = float.truncate(f)
              case int.to_float(trunc) == f {
                True -> prime_math.is_prime(trunc)
                False -> False
              }
            }
          }
          let response = create_is_prime_response(prime)
          Ok(response)
        }
        _ -> Error("Wrong method type")
      }
    }
  }
}
