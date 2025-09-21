import gleam/int
import gleam/list
import gleam/string
import glisten

pub fn get_client_source_string(conn: glisten.Connection(a)) -> String {
  case glisten.get_client_info(conn) {
    Ok(address) -> {
      glisten.ip_address_to_string(address.ip_address)
      <> ":"
      <> int.to_string(address.port)
    }
    Error(_) -> " from unknown address"
  }
}

pub type Split {
  Split(elements: List(String), remaining: String)
}

pub fn split_request_messages(msg_str: String, on: String) -> Split {
  split_messages_helper(msg_str, on, [])
}

fn split_messages_helper(
  remaining: String,
  on: String,
  acc: List(String),
) -> Split {
  case string.split_once(remaining, on:) {
    Error(_) -> {
      // No more newlines - remaining is leftover buffer
      Split(list.reverse(acc), remaining)
    }
    Ok(#(line, rest)) -> {
      split_messages_helper(rest, on, [line, ..acc])
    }
  }
}
