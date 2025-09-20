import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/time/timestamp
import types.{type AppState, type Request, AppState, Insert, Query, Request}

fn insert(n0, n1, state: AppState) {
  let new_state = {
    let ts = timestamp.from_unix_seconds(n0)
    AppState([types.TimedPrice(ts, n1), ..state.prices])
  }

  #(new_state, None)
}

fn query(min, max, state: AppState) {
  let min_ts = timestamp.from_unix_seconds(min)
  let max_ts = timestamp.from_unix_seconds(max)

  let lookup_result = case max - min {
    range if range <= 0 -> 0
    _ -> {
      let prices_in_range =
        state.prices
        |> list.filter_map(fn(tp) {
          case
            timestamp.compare(min_ts, tp.ts),
            timestamp.compare(max_ts, tp.ts)
          {
            order.Gt, order.Lt
            | order.Eq, order.Eq
            | order.Gt, order.Eq
            | order.Eq, order.Lt
            -> Ok(tp.penies)
            _, _ -> Error(Nil)
          }
        })

      let num_prices = list.length(prices_in_range)
      list.fold(prices_in_range, 0, add) / num_prices
    }
  }

  #(state, Some(lookup_result))
}

fn add(int: Int, int_2: Int) -> Int {
  int + int_2
}

pub fn handle_request(
  request: Request,
  state: AppState,
) -> #(AppState, Option(Int)) {
  let Request(request_type, n0, n1) = request
  case request_type {
    Insert -> insert(n0, n1, state)
    Query -> query(n0, n1, state)
  }
}
