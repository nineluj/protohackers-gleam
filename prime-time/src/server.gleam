import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option, None}
import glisten.{Packet}
import logging
import parser
import protocol
import protolib.{get_client_source_string}
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
