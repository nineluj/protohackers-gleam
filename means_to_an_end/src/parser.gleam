import gleam/bit_array
import gleam/int
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
    <<char:int-8, n0:int-signed-32, n1:int-signed-32, rest:bytes>> ->
      Ok(#(char, n0, n1, rest))
    _ -> Error(InvalidInputFailure("Not enough data"))
  })

  use request_type <- result.try(case <<char:int-8>> {
    <<"I">> -> Ok(Insert)
    <<"Q">> -> Ok(Query)
    _ -> Error(InvalidInputFailure("Invalid operation " <> int.to_string(char)))
  })

  Ok(#(Request(request_type, n0, n1), rest))
}
