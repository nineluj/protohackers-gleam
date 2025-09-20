import gleam/bit_array
import gleam/bytes_tree
import gleam/option.{None, Some}
import glisten.{Packet}
import logging
import parser.{parse_message}
import protocol
import protolib.{get_client_source_string}
import types.{type AppState, type ServerState, AppState, ServerState}

// Connection initialization handler
pub fn on_init(conn: glisten.Connection(user_message)) {
  // Log the connection info
  let remote_address = get_client_source_string(conn)
  logging.log(
    logging.Info,
    "New connection established from " <> remote_address,
  )

  #(types.ServerState(remote_address, <<>>, types.AppState([])), None)
}

// this only triggers when the other side closes the TCP
// socket, so it won't log close info for connections ended
// using glisten.close()
pub fn on_close(state: ServerState) -> Nil {
  logging.log(logging.Info, "Connection closed from " <> state.remote_address)
}

pub fn listener(
  state: ServerState,
  msg: glisten.Message(a),
  conn: glisten.Connection(a),
) -> glisten.Next(ServerState, glisten.Message(a)) {
  let assert Packet(msg) = msg

  case parse_message(bit_array.append(to: msg, suffix: state.left_over_bytes)) {
    Error(types.InvalidInputFailure(reason)) -> {
      logging.log(
        logging.Error,
        "Closing connection with "
          <> state.remote_address
          <> " . Reason: "
          <> reason,
      )
      glisten.stop()
    }
    Error(types.NotEnoughBytesFailure(data)) -> {
      glisten.continue(types.ServerState(
        state.remote_address,
        data,
        state.app_state,
      ))
    }
    Ok(#(request, left_over)) -> {
      let #(new_app_state, response) =
        protocol.handle_request(request, state.app_state)
      let new_state =
        ServerState(state.remote_address, left_over, new_app_state)

      case response {
        None -> glisten.continue(new_state)
        Some(v) -> {
          let assert Ok(_) =
            glisten.send(conn, bytes_tree.from_bit_array(<<v:size(8)>>))
          glisten.continue(new_state)
        }
      }
    }
  }
}
