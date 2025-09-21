import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import types.{type AppState, type Request, AppState, Insert, Query, Request}

fn insert(n0, n1, state: AppState) {
  let new_state = {
    AppState([types.TimedPrice(n0, n1), ..state.prices])
  }

  #(new_state, None)
}

fn query(min, max, state: AppState) {
  let lookup_result = case max - min {
    range if range < 0 -> 0
    _ -> {
      let prices_in_range =
        state.prices
        |> list.filter_map(fn(tp) {
          case tp.ts >= min, tp.ts <= max {
            True, True -> Ok(tp.pennies)
            _, _ -> Error(Nil)
          }
        })

      let num_prices = list.length(prices_in_range)
      int.sum(prices_in_range) / num_prices
    }
  }

  #(state, Some(lookup_result))
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
