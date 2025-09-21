import gleam/bit_array
import gleam/bytes_tree
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import glisten.{Packet}
import logging
import protolib.{get_client_source_string}
import types.{
  type ServerState, RegisteredUserConnection, ServerState,
  UnregisteredConnection,
}

const greeting_message = "Welcome to budgetchat! What can I call you? Enter name: "

fn send_username_prompt_message(conn: glisten.Connection(a)) {
  glisten.send(conn, bytes_tree.from_string(greeting_message))
}

// Connection initialization handler
pub fn on_init(conn: glisten.Connection(a)) {
  // Log the connection info
  let remote_address = get_client_source_string(conn)
  logging.log(
    logging.Info,
    "New connection established from " <> remote_address,
  )

  let assert Ok(_) = send_username_prompt_message(conn)
  #(ServerState(remote_address, UnregisteredConnection), None)
}

// this only triggers when the other side closes the TCP
// socket, so it won't log close info for connections ended
// using glisten.close()
pub fn on_close(state: ServerState) -> Nil {
  logging.log(logging.Info, "Connection closed from " <> state.remote_address)
}

fn validate_name(name: String) -> Bool {
  case string.length(name) {
    0 -> False
    _ -> {
      name
      |> string.to_utf_codepoints
      |> list.all(fn(codepoint) {
        let code = string.utf_codepoint_to_int(codepoint)
        // a-z: 97-122, A-Z: 65-90, 0-9: 48-57
        { code >= 97 && code <= 122 }
        || { code >= 65 && code <= 90 }
        || { code >= 48 && code <= 57 }
      })
    }
  }
}

fn handle_name_setting(
  state: ServerState,
  conn: glisten.Connection(a),
  msg: String,
) {
  let requested_name = msg

  logging.log(logging.Info, "Got name: [" <> requested_name <> "]")

  case validate_name(requested_name) {
    True -> {
      // todo, display existing client names
      // todo, broadcast join message to other clients
      logging.log(
        logging.Debug,
        "Accepted name " <> "[" <> requested_name <> "]",
      )
      glisten.continue(ServerState(
        state.remote_address,
        RegisteredUserConnection(requested_name),
      ))
    }
    False -> {
      let assert Ok(_) =
        glisten.send(
          conn,
          bytes_tree.from_string(
            "Invalid username provided: " <> requested_name,
          ),
        )
      glisten.stop()
    }
  }
}

pub fn listener(
  state: ServerState,
  msg: glisten.Message(a),
  conn: glisten.Connection(a),
) -> glisten.Next(ServerState, glisten.Message(a)) {
  let assert Packet(msg) = msg
  let assert Ok(msg) = bit_array.to_string(msg)
  // todo: wait to receive more data if not enough text,
  // and process multiple messages if receive more than one message

  // remove the trailing newline
  let msg = string.slice(msg, 0, string.length(msg) - 1)

  case state.connection_state {
    UnregisteredConnection -> {
      handle_name_setting(state, conn, msg)
    }
    RegisteredUserConnection(username:) -> todo
  }

  glisten.continue(state)
}
