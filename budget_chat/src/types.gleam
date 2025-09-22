import gleam/erlang/process

pub type ServerState {
  ServerState(
    subject: process.Subject(Command),
    remote_address: String,
    connection_state: ConnectionState,
  )
}

pub type ConnectionState {
  UnregisteredConnection
  RegisteredUserConnection(username: String)
}

pub type Command {
  SendMessage(sender: String, message: String)
}
