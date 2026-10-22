///|
fn bound_number(
  expr : Expr,
  kind : Kind,
  values : Map[String, Value],
  linux612~ : Bool = false,
) -> Int64 raise ConfigError {
  if linux612 {
    let value = expr.typed_value(kind, values, linux612=true)
    let actual_kind = match value {
      RawNumber(_, k) => k
      _ => kind
    }
    return linux_range_number(value.text(), actual_kind)
  }
  match expr.typed_value(kind, values) {
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
      .condition(values, modules, linux612=schema.linux612)
      .meet(d.depends.condition(values, modules, linux612=schema.linux612)) !=
      N {
      let lo = bound_number(
        low,
        schema.kind(d.name),
        values,
        linux612=schema.linux612,
      )
      let hi = bound_number(
        high,
        schema.kind(d.name),
        values,
        linux612=schema.linux612,
      )
      if lo > hi && !schema.linux612 {
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
  if schema.linux612 {
    let modules = schema.modules_enabled(values)
    for (low, high, cond) in d.ranges {
      if cond
        .condition(values, modules, linux612=true)
        .meet(d.depends.condition(values, modules, linux612=true)) ==
        N {
        continue
      }
      let lo = bound_number(low, schema.kind(d.name), values, linux612=true)
      let hi = bound_number(high, schema.kind(d.name), values, linux612=true)
      let n = linux_range_number(value.text(), schema.kind(d.name))
      let endpoint = if n < lo {
        Some(low)
      } else if n > hi {
        Some(high)
      } else {
        None
      }
      return match endpoint {
        Some(e) => e.typed_value(schema.kind(d.name), values, linux612=true)
        None => value
      }
    }
    return value
  }
  match active_range(schema, d, values) {
    None => value
    Some((lo, hi)) => {
      let n = match value {
        Number(n) => n
        RawNumber(raw, k) => linux_range_number(raw, k)
        _ => 0L
      }
      if n < lo {
        if schema.linux612 {
          RawNumber(
            if schema.kind(d.name) == Hex {
              hex_text(lo)
            } else {
              lo.to_string()
            },
            schema.kind(d.name),
          )
        } else {
          Number(lo)
        }
      } else if n > hi {
        if schema.linux612 {
          RawNumber(
            if schema.kind(d.name) == Hex {
              hex_text(hi)
            } else {
              hi.to_string()
            },
            schema.kind(d.name),
          )
        } else {
          Number(hi)
        }
      } else {
        value
      }
    }
  }
}
