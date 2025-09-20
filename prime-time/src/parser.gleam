import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/list
import gleam/string
import logging
import types

/// Parses out a MethodNumberRequest string
pub fn parse_message(
  msg_str: String,
) -> Result(types.MethodNumberRequest, json.DecodeError) {
  let number_decoder =
    decode.one_of(decode.int |> decode.map(types.IntValue), or: [
      decode.float |> decode.map(types.FloatValue),
    ])

  let method_number_request_decoder = {
    use method <- decode.field("method", decode.string)
    use number <- decode.field("number", number_decoder)
    decode.success(types.MethodNumberRequest(method:, number:))
  }
  let result = json.parse(from: msg_str, using: method_number_request_decoder)
  case result {
    Error(err) -> {
      logging.log(logging.Error, "JSON parse error: " <> string.inspect(err))
      // Add this
      Error(err)
    }
    Ok(req) -> {
      logging.log(
        logging.Info,
        "Parsed request: method="
          <> req.method
          <> ", number="
          <> string.inspect(req.number),
      )
      // Add this
      Ok(req)
    }
  }
}

pub fn split_request_messages(
  msg_str: String,
) -> Result(#(List(String), String), Nil) {
  split_messages_helper(msg_str, [])
}

fn split_messages_helper(
  remaining: String,
  acc: List(String),
) -> Result(#(List(String), String), Nil) {
  case string.split_once(remaining, on: "\n") {
    Error(_) -> {
      // No more newlines - remaining is leftover buffer
      Ok(#(list.reverse(acc), remaining))
    }
    Ok(#(line, rest)) -> {
      split_messages_helper(rest, [line, ..acc])
    }
  }
}
