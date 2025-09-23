import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process.{type Selector}
import gleam/list
import gleam/option.{type Option, Some}
import gleam/string
import glisten.{Packet, User}
import group_registry
import logging
import protolib.{get_client_source_string}
import types.{
  type ChatMessage, type ServerState, RegisteredUserConnection, ServerState,
  UnregisteredConnection, UserJoined, UserLeft, UserMessage,
}
import validation.{validate_name}

const greeting_message = "Welcome to budgetchat! What can I call you? Enter name: "

const chat_room = "main_chat"

fn broadcast_to_others(
  registry: group_registry.GroupRegistry(ChatMessage),
  sender_subject: process.Subject(ChatMessage),
  message: ChatMessage,
) {
  group_registry.members(registry, chat_room)
  |> list.filter(fn(member) { member != sender_subject })
  |> list.each(fn(member) { process.send(member, message) })
}

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
    let chat_subject = group_registry.join(registry, chat_room, self)
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

  // If user was registered, broadcast that they left
  case state.connection_state {
    RegisteredUserConnection(username) -> {
      broadcast_to_others(
        state.registry,
        state.chat_subject,
        UserLeft(username),
      )
    }
    UnregisteredConnection -> Nil
  }
}

fn handle_name_setting(
  state: ServerState,
  conn: glisten.Connection(a),
  msg: String,
) {
  let requested_name = msg

  logging.log(logging.Debug, "Got name: [" <> requested_name <> "]")
  case validate_name(requested_name) {
    True -> {
      // todo, display existing client names
      // todo, broadcast join message to other clients
      logging.log(
        logging.Debug,
        "Accepted name " <> "[" <> requested_name <> "]",
      )
      let assert Ok(_) =
        // todo: this is just for testing, replace this with the list of
        // already connected users for the final implementation
        glisten.send(
          conn,
          bytes_tree.from_string(
            "Name: " <> "[" <> requested_name <> "] was accepted\n",
          ),
        )
      broadcast_to_others(
        state.registry,
        state.chat_subject,
        UserJoined(requested_name),
      )
      glisten.continue(ServerState(
        state.registry,
        state.chat_subject,
        state.remote_address,
        RegisteredUserConnection(requested_name),
      ))
    }
    False -> {
      let assert Ok(_) =
        glisten.send(
          conn,
          bytes_tree.from_string(
            "Invalid username provided: " <> "[" <> requested_name <> "]",
          ),
        )
      glisten.stop()
    }
  }
}

pub fn handler(
  state: ServerState,
  msg: glisten.Message(ChatMessage),
  conn: glisten.Connection(ChatMessage),
) -> glisten.Next(ServerState, glisten.Message(a)) {
  case msg {
    Packet(msg) -> {
      let assert Ok(msg) = bit_array.to_string(msg)
      // todo: wait to receive more data if not enough text,
      // and process multiple messages if receive more than one message

      // remove the trailing newline
      let msg = string.slice(msg, 0, string.length(msg) - 1)

      case state.connection_state {
        UnregisteredConnection -> {
          handle_name_setting(state, conn, msg)
        }
        RegisteredUserConnection(username:) -> {
          logging.log(
            logging.Info,
            "User [" <> username <> "] sent message: " <> msg,
          )
          broadcast_to_others(
            state.registry,
            state.chat_subject,
            UserMessage(username, msg),
          )
          glisten.continue(state)
        }
      }
    }
    User(cmd) -> {
      let _ = case cmd {
        UserMessage(sender, msg) -> {
          logging.log(
            logging.Debug,
            "Forwarding ["
              <> sender
              <> "]'s message to ["
              <> state.remote_address
              <> "]",
          )
          // forward the message to the TCP client
          let formatted_message = "[" <> sender <> "] " <> msg <> "\n"
          let assert Ok(_) =
            glisten.send(conn, bytes_tree.from_string(formatted_message))
        }
        UserJoined(user) -> {
          let formatted_message = "* " <> user <> " has entered the room\n"
          let assert Ok(_) =
            glisten.send(conn, bytes_tree.from_string(formatted_message))
        }
        UserLeft(user) -> {
          let formatted_message = "* " <> user <> " has left the room\n"
          let assert Ok(_) =
            glisten.send(conn, bytes_tree.from_string(formatted_message))
        }
      }
      glisten.continue(state)
    }
  }
}
