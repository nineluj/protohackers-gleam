import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process.{type Selector, type Subject}
import gleam/option.{type Option, Some}
import gleam/string
import glisten.{Packet, User}
import logging
import protolib.{get_client_source_string}
import types.{
  type Command, type ServerState, RegisteredUserConnection, ServerState,
  UnregisteredConnection,
}
import validation.{validate_name}

const greeting_message = "Welcome to budgetchat! What can I call you? Enter name: "

fn send_username_prompt_message(conn: glisten.Connection(a)) {
  glisten.send(conn, bytes_tree.from_string(greeting_message))
}

pub fn create_on_init(subj: Subject(Command), selector: Selector(Command)) {
  fn(conn: glisten.Connection(a)) -> #(ServerState, Option(Selector(Command))) {
    // Log the connection info
    let remote_address = get_client_source_string(conn)
    logging.log(
      logging.Info,
      "New connection established from " <> remote_address,
    )

    let assert Ok(_) = send_username_prompt_message(conn)
    #(ServerState(subj, remote_address, UnregisteredConnection), Some(selector))
  }
}

// this only triggers when the other side closes the TCP
// socket, so it won't log close info for connections ended
// using glisten.close()
pub fn on_close(state: ServerState) -> Nil {
  logging.log(logging.Info, "Connection closed from " <> state.remote_address)
}

fn handle_name_setting(
  state: ServerState,
  conn: glisten.Connection(Command),
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
      glisten.continue(ServerState(
        state.subject,
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
  msg: glisten.Message(Command),
  conn: glisten.Connection(Command),
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
          process.send(state.subject, types.SendMessage(username, msg))
          glisten.continue(state)
        }
      }
    }
    User(cmd) -> {
      case cmd {
        types.SendMessage(sender, msg) -> {
          // this is not triggering
          logging.log(
            logging.Info,
            "Forwarding ["
              <> sender
              <> "]'s message to ["
              <> state.remote_address
              <> "]",
          )
          // forward the message to the TCP client
          let formatted_message = "[" <> sender <> "] " <> msg
          let assert Ok(_) =
            glisten.send(conn, bytes_tree.from_string(formatted_message))
          glisten.continue(state)
        }
      }
    }
  }
}
