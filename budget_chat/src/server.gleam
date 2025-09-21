import gleam/bit_array
import gleam/bytes_tree
import gleam/option.{None, Some}
import glisten.{Packet}
import logging
import parser
import protocol
import protolib.{get_client_source_string}
import types.{type ServerState, type UserAction, AppState, ServerState}

pub fn on_init(conn: glisten.Connection(user_message)) {
  // Log the connection info
  let remote_address = get_client_source_string(conn)
  logging.log(
    logging.Info,
    "New connection established from " <> remote_address,
  )

  #(ServerState(remote_address, <<>>, AppState(types.Anonymous)), None)
}

// this only triggers when the other side closes the TCP
// socket, so it won't log close info for connections ended
// using glisten.close()
pub fn on_close(state: ServerState) -> Nil {
  logging.log(logging.Info, "Connection closed from " <> state.remote_address)
}

pub fn listener(
  state: ServerState,
  msg: glisten.Message(UserAction),
  conn: glisten.Connection(a),
) -> glisten.Next(ServerState, glisten.Message(a)) {
  case msg {
    Packet(msg) -> {
      let assert Ok(msg_str) = bit_array.to_string(msg)
      case parser.parse_message(msg_str) {
        Error(_) -> todo
        Ok(_) -> todo
      }
    }
    // user messages are received from other actors
    glisten.User(action) -> {
      let resp = protocol.handle_user_action(state.app_state, action)
      case resp {
        None -> glisten.continue(state)
        Some(v) -> {
          let assert Ok(_) = glisten.send(conn, bytes_tree.from_string(v))
          glisten.continue(state)
        }
      }
    }
  }
}
