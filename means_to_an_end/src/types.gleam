pub type TimedPrice {
  TimedPrice(ts: Int, pennies: Int)
}

pub type RequestType {
  Insert
  Query
}

pub type Request {
  Request(request_type: RequestType, n0: Int, n1: Int)
}

pub type ParseFailure {
  NotEnoughBytesFailure(data: BitArray)
  InvalidInputFailure(reason: String)
}

pub type ServerState {
  ServerState(
    remote_address: String,
    left_over_bytes: BitArray,
    app_state: AppState,
  )
}

pub type AppState {
  AppState(prices: List(TimedPrice))
}
