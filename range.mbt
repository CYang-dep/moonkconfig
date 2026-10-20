///|
fn bound_number(
  expr : Expr,
  values : Map[String, Value],
) -> Int64 raise ConfigError {
  match expr.evaluate(values) {
    Number(n) => n
    Unset => 0L
    Text(s) => if s.is_empty() { 0L } else { parse_number(s) }
    _ => raise Invalid("numeric range bound has logical type")
  }
}

///|
fn active_range(
  schema : Schema,
  d : Definition,
  values : Map[String, Value],
) -> (Int64, Int64)? raise ConfigError {
  let modules = schema.modules_enabled(values)
  for (low, high, cond) in d.ranges {
    if cond
      .condition(values, modules)
      .meet(d.depends.condition(values, modules)) !=
      N {
      let lo = bound_number(low, values)
      let hi = bound_number(high, values)
      if lo > hi {
        raise Invalid("inverted active range: " + d.name)
      }
      return Some((lo, hi))
    }
  }
  None
}

///|
fn request_in_range(
  schema : Schema,
  d : Definition,
  value : Value,
  values : Map[String, Value],
) -> Bool raise ConfigError {
  match (value, active_range(schema, d, values)) {
    (Number(n), Some((lo, hi))) => n >= lo && n <= hi
    _ => true
  }
}

///|
fn clamp_default(
  schema : Schema,
  d : Definition,
  value : Value,
  values : Map[String, Value],
) -> Value raise ConfigError {
  match active_range(schema, d, values) {
    None => value
    Some((lo, hi)) => {
      let n = match value {
        Number(n) => n
        _ => 0L
      }
      if n < lo {
        Number(lo)
      } else if n > hi {
        Number(hi)
      } else {
        value
      }
    }
  }
}
