pub type ServerState {
  ServerState(remote_address: String, connection_state: ConnectionState)
}

pub type ConnectionState {
  UnregisteredConnection
  RegisteredUserConnection(username: String)
}
