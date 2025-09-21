import gleam/bit_array
import gleam/int
import gleam/io
import gleam/result
import protolib.{split_request_messages}

pub fn parse_message(data: String) -> Result(#(String, String), String) {
  case split_request_messages(data, "\n") {
    protolib.Split(elements: messages, remaining:) -> todo
  }
}
