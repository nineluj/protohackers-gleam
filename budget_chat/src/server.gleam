import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process.{type Selector}
import gleam/list
import gleam/option.{type Option, Some}
import gleam/string
import glisten.{Packet, User}
import group_registry
import logging
import message_buffer.{Split}
import protocol
import protolib.{get_client_source_string}
import types.{
  type ChatMessage, type ServerState, ServerState, UnregisteredConnection,
}

const greeting_message = "Welcome to budgetchat! What can I call you? Enter name: "

fn send_username_prompt_message(conn: glisten.Connection(a)) {
  glisten.send(conn, bytes_tree.from_string(greeting_message))
}

fn splitter(data: BitArray) -> Result(message_buffer.Split(String), String) {
  case bit_array.to_string(data) {
    Error(_) ->
      Error("Unable to convert BitArray to string, invalid UTF-8 data")
    Ok(str) -> {
      case string.split_once(str, "\n") {
        // errors when it's unable to split
        Error(_) -> {
          logging.log(
            logging.Info,
            "Didn't get all the data, waiting for more...",
          )
          Ok(Split(message: option.None, remaining: data))
        }
        Ok(#(captured, rest)) ->
          Ok(Split(
            message: option.Some(captured),
            remaining: bit_array.from_string(rest),
          ))
      }
    }
  }
}

pub fn create_on_init(
  registry: group_registry.GroupRegistry(ChatMessage),
  user_query_subject: process.Subject(types.UserTrackerMessage),
) {
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
        user_query_subject,
        message_buffer.new(splitter),
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
  logging.log(
    logging.Info,
    "Connection terminated for " <> state.remote_address,
  )
  group_registry.leave(state.registry, protocol.chat_room, [process.self()])
  protocol.on_close(state)
}

pub fn process_handler_response(state: ServerState, conn, handler_response) {
  case handler_response {
    Error(error_msg) -> {
      let assert Ok(_) = glisten.send(conn, bytes_tree.from_string(error_msg))
      // todo: this logs here and in on_close, which makes for some not very intuitive logs
      logging.log(
        logging.Info,
        "Ending connection with " <> state.remote_address,
      )
      on_close(state)
      Error(error_msg)
    }
    Ok(types.HandlerResponse(new_state, message_to_send)) -> {
      let _ = case message_to_send {
        Some(v) -> {
          let assert Ok(_) = glisten.send(conn, bytes_tree.from_string(v))
          Nil
        }
        option.None -> Nil
      }
      Ok(new_state)
    }
  }
}

fn handle_final_state(state) {
  case state {
    Ok(new_state) -> glisten.continue(new_state)
    Error(_) -> glisten.stop()
  }
}

pub fn handler(
  state: ServerState,
  msg: glisten.Message(ChatMessage),
  conn: glisten.Connection(ChatMessage),
) -> glisten.Next(ServerState, glisten.Message(a)) {
  logging.log(logging.Debug, "Handler received " <> string.inspect(msg))
  case msg {
    User(cmd) -> {
      protocol.handle_chat_message(state, cmd)
      |> process_handler_response(state, conn, _)
      |> handle_final_state
    }

    Packet(data) -> {
      case message_buffer.do_split(state.message_buffer, data) {
        Error(e) -> Error(e) |> handle_final_state

        Ok(#(new_mb, msg_list)) -> {
          list.fold(
            msg_list,
            // add the new message_buffer to the ServerState
            Ok(ServerState(
              state.registry,
              state.chat_subject,
              state.user_query_subject,
              new_mb,
              state.remote_address,
              state.connection_state,
            )),
            fn(state: Result(ServerState, String), msg: String) {
              case state {
                Error(_) -> state
                Ok(state) -> {
                  protocol.handle_packet_message(state, msg)
                  |> process_handler_response(state, conn, _)
                }
              }
            },
          )
          |> handle_final_state
        }
      }
    }
  }
}
