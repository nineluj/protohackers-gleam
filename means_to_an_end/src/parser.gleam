import gleam/bit_array
import gleam/int
import gleam/io
import gleam/result
import types.{
  type ParseFailure, type Request, Insert, InvalidInputFailure,
  NotEnoughBytesFailure, Query, Request,
}

pub fn parse_message(
  data: BitArray,
) -> Result(#(Request, BitArray), ParseFailure) {
  // ensure that there are at least 9 bytes to read
  use _ <- result.try(case bit_array.byte_size(data) {
    len if len >= 9 -> Ok(Nil)
    _ -> Error(NotEnoughBytesFailure(data))
  })

  use #(char, n0, n1, rest) <- result.try(case data {
    <<
      char:int-signed-big-8,
      n0:int-signed-big-32,
      n1:int-signed-big-32,
      rest:bytes,
    >> -> Ok(#(char, n0, n1, rest))
    _ -> Error(InvalidInputFailure("Not enough data"))
  })

  use request_type <- result.try(case char {
    // ascii 'I'
    73 -> Ok(Insert)
    // ascii 'Q'
    81 -> Ok(Query)
    _ -> {
      io.println("Received char: " <> int.to_string(char))
      let slice_result = case bit_array.slice(data, 0, 9) {
        Ok(slice) -> bit_array.inspect(slice)
        Error(_) -> "Unable to slice"
      }
      io.println("First few bytes: " <> slice_result)
      Error(InvalidInputFailure("Invalid operation " <> int.to_string(char)))
    }
  })

  Ok(#(Request(request_type, n0, n1), rest))
}
