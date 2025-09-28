import gleam/erlang/process
import gleam/option
import group_registry
import message_buffer.{type MessageBuffer}

pub type ServerMessaging {
  ServerMessaging(
    registry: group_registry.GroupRegistry(ChatMessage),
    chat_subject: process.Subject(ChatMessage),
    user_query_subject: process.Subject(UserTrackerMessage),
  )
}

pub type AppState {
  AppState(connection_state: ConnectionState)
}

pub type ClientContext {
  ClientContext(
    message_buffer: MessageBuffer(String, String),
    remote_address: String,
  )
}

pub type ServerState {
  ServerState(
    client_ctx: ClientContext,
    messaging: ServerMessaging,
    app_state: AppState,
  )
}

pub type ConnectionState {
  UnregisteredConnection
  RegisteredUserConnection(username: String)
}

pub type ChatMessage {
  UserMessage(sender: String, message: String)
  UserJoined(username: String)
  UserLeft(username: String)
}

pub type HandlerResponse {
  HandlerResponse(new_state: AppState, message_to_send: option.Option(String))
}

pub type UserTrackerMessage {
  UserChatMessage(message: ChatMessage)
  QueryUsers(process.Subject(List(String)))
}
