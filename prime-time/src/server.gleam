import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{type Option, None}
import glisten.{Packet}
import logging
import parser
import protocol
import types.{type AppState, AppState}

pub fn process_responses(
  responses: List(Result(String, String)),
  conn: glisten.Connection(a),
  state: AppState,
) {
  case responses {
    [] -> glisten.continue(state)
    [Ok(resp), ..rest] -> {
      let assert Ok(_) = glisten.send(conn, bytes_tree.from_string(resp))
      process_responses(rest, conn, state)
    }
    [Error(err), ..] -> {
      logging.log(
        logging.Error,
        "Got error: " <> err <> " - closing connection",
      )
      glisten.stop()
    }
  }
}

fn get_client_source_string(conn: glisten.Connection(a)) -> String {
  let combine_with_sep = fn(xs, transform, sep) {
    let max_index = list.length(xs) - 1
    list.index_fold(xs, "", fn(acc: String, num, index) {
      let sep = case index {
        n if n == max_index -> ""
        _ -> sep
      }
      acc <> transform(num) <> sep
    })
  }
  case glisten.get_client_info(conn) {
    Ok(address) -> {
      let ip_str = case address.ip_address {
        glisten.IpV4(a, b, c, d) ->
          combine_with_sep([a, b, c, d], int.to_string, ".") <> ":"
        glisten.IpV6(a, b, c, d, e, f, g, h) ->
          // for IPv6, parts that are 0 can be omitted,
          // but I'm too lazy to add that
          "["
          <> combine_with_sep([a, b, c, d, e, f, g, h], int.to_base16, ":")
          <> "]"
          <> ":"
      }
      ip_str <> int.to_string(address.port)
    }
    Error(_) -> " from unknown address"
  }
}

// Connection initialization handler
pub fn on_init(
  conn: glisten.Connection(user_message),
) -> #(AppState, Option(process.Selector(AppState))) {
  // Log the connection info
  let remote_address = get_client_source_string(conn)
  logging.log(
    logging.Info,
    "New connection established from " <> remote_address,
  )

  #(types.AppState("", remote_address), None)
}

// this only triggers when the other side closes the TCP
// socket, so it won't log close info for connections ended
// using glisten.close()
pub fn on_close(state: AppState) -> Nil {
  logging.log(logging.Info, "Connection closed from " <> state.remote_address)
}

pub fn listener(
  state: AppState,
  msg: glisten.Message(a),
  conn: glisten.Connection(a),
) -> glisten.Next(AppState, glisten.Message(a)) {
  let assert Packet(msg) = msg
  let assert Ok(msg_str) = bit_array.to_string(msg)
  let to_process = state.left_over_buffer <> msg_str

  case parser.split_request_messages(to_process) {
    Error(_) -> {
      logging.log(logging.Error, "Malformed collection of messages")
      glisten.stop()
    }
    Ok(#(lines, remaining)) -> {
      lines
      |> list.map(protocol.handle_message)
      |> process_responses(conn, AppState(remaining, state.remote_address))
    }
  }
}
