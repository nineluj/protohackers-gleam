import gleam/float
import gleam/int

fn is_prime_rec(num: Int, i: Int, limit: Int) {
  case i > limit, num % i {
    True, _ -> True
    False, 0 -> False
    _, _ -> is_prime_rec(num, i + 2, limit)
  }
}

pub fn is_prime(num: Int) -> Bool {
  case num {
    n if n < 2 -> False
    n if n == 2 -> True
    n if n % 2 == 0 -> False
    _ -> {
      // only need to check up to sqrt(num)
      let assert Ok(sqrt_val) = float.square_root(int.to_float(num))
      let limit = float.truncate(sqrt_val)
      is_prime_rec(num, 3, limit)
    }
  }
}
