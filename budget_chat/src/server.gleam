import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process.{type Selector}
import gleam/option.{type Option, Some}
import gleam/string
import glisten.{Packet, User}
import group_registry
import logging
import protocol
import protolib.{get_client_source_string}
import types.{
  type ChatMessage, type ServerState, ServerState, UnregisteredConnection,
}

const greeting_message = "Welcome to budgetchat! What can I call you? Enter name: "

fn send_username_prompt_message(conn: glisten.Connection(a)) {
  glisten.send(conn, bytes_tree.from_string(greeting_message))
}

pub fn create_on_init(registry: group_registry.GroupRegistry(ChatMessage)) {
  fn(conn: glisten.Connection(a)) -> #(
    ServerState,
    Option(Selector(ChatMessage)),
  ) {
    // Log the connection info
    let remote_address = get_client_source_string(conn)
    logging.log(
      logging.Info,
      "New connection established from " <> remote_address,
    )

    let self = process.self()
    let chat_subject = group_registry.join(registry, protocol.chat_room, self)
    let selector = process.new_selector() |> process.select(chat_subject)

    let assert Ok(_) = send_username_prompt_message(conn)
    #(
      ServerState(
        registry,
        chat_subject,
        remote_address,
        UnregisteredConnection,
      ),
      Some(selector),
    )
  }
}

// this only triggers when the other side closes the TCP
// socket, so it won't log close info for connections ended
// using glisten.close()
pub fn on_close(state: ServerState) -> Nil {
  logging.log(logging.Info, "Connection closed from " <> state.remote_address)
  protocol.on_close(state)
}

pub fn handler(
  state: ServerState,
  msg: glisten.Message(ChatMessage),
  conn: glisten.Connection(ChatMessage),
) -> glisten.Next(ServerState, glisten.Message(a)) {
  let handler_response = case msg {
    Packet(msg) -> {
      let assert Ok(msg) = bit_array.to_string(msg)
      // todo: wait to receive more data if not enough text,
      // and process multiple messages if receive more than one message

      // remove the trailing newline
      let msg = string.slice(msg, 0, string.length(msg) - 1)

      protocol.handle_packet_message(state, msg)
    }
    User(cmd) -> {
      protocol.handle_chat_message(state, cmd)
    }
  }

  case handler_response {
    Error(error_msg) -> {
      let assert Ok(_) = glisten.send(conn, bytes_tree.from_string(error_msg))
      glisten.stop()
    }
    Ok(types.HandlerResponse(new_state, message_to_send)) -> {
      let _ = case message_to_send {
        Some(v) -> {
          let assert Ok(_) = glisten.send(conn, bytes_tree.from_string(v))
          Nil
        }
        option.None -> Nil
      }
      glisten.continue(new_state)
    }
  }
}
