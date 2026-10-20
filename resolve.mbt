///|
/// Immutable-by-interface resolution snapshot detached from user input.
pub struct Resolution {
  priv values : Map[String, Value]
  priv visibility : Map[String, Tri]
  priv reasons : Map[String, String]
  priv messages : Array[String]
}

///|
pub fn Resolution::value(
  self : Resolution,
  name : String,
) -> Value raise ConfigError {
  match self.values.get(name) {
    Some(v) => v
    None => raise Invalid("unknown resolved symbol " + name)
  }
}

///|
pub fn Resolution::values(self : Resolution) -> Map[String, Value] {
  let out = Map([])
  for key, value in self.values {
    out[key] = value
  }
  out
}

///|
pub fn Resolution::visibility(
  self : Resolution,
  name : String,
) -> Tri raise ConfigError {
  match self.visibility.get(name) {
    Some(v) => v
    None => raise Invalid("unknown visibility " + name)
  }
}

///|
pub fn Resolution::reason(
  self : Resolution,
  name : String,
) -> String raise ConfigError {
  match self.reasons.get(name) {
    Some(v) => v
    None => raise Invalid("unknown reason " + name)
  }
}

///|
pub fn Resolution::diagnostics(self : Resolution) -> Array[String] {
  self.messages.copy()
}

///|
fn logical_bound(value : Tri, kind : Kind) -> Tri {
  if kind == Boolean && value == M {
    Y
  } else {
    value
  }
}

///|
fn typed_default(value : Value, kind : Kind) -> Value raise ConfigError {
  match kind {
    Boolean | Tristate => Logic(value.logic())
    StringType => Text(value.text())
    Integer | Hex =>
      match value {
        Number(_) => value
        _ => Number(parse_number(value.text()))
      }
  }
}

///|
fn direct_visibility(
  d : Definition,
  kind : Kind,
  values : Map[String, Value],
) -> Tri {
  if d.prompt == None {
    N
  } else {
    logical_bound(
      d.depends
      .evaluate(values)
      .logic()
      .meet(d.prompt_if.evaluate(values).logic()),
      kind,
    )
  }
}

///|
fn base_value(
  d : Definition,
  kind : Kind,
  requests : Map[String, Value],
  values : Map[String, Value],
) -> (Value, String) raise ConfigError {
  let visible = direct_visibility(d, kind, values)
  match requests.get(d.name) {
    Some(v) =>
      if visible != N {
        return (
          match v {
            Logic(t) => Logic(logical_bound(t.meet(visible), kind))
            _ => v
          },
          "user",
        )
      }
    None => ()
  }
  for (expr, condition) in d.defaults {
    let active = condition
      .evaluate(values)
      .logic()
      .meet(d.depends.evaluate(values).logic())
    if active != N {
      let value = typed_default(expr.evaluate(values), kind)
      return (
        match value {
          Logic(t) => Logic(logical_bound(t.meet(active), kind))
          _ => value
        },
        "default",
      )
    }
  }
  (kind.initial(), "initial")
}

///|
/// Resolve to a bounded fixed point; requests never override hidden prompts.
pub fn Schema::resolve(
  self : Schema,
  fragment : Fragment,
) -> Resolution raise ConfigError {
  self.validate()
  let requests = fragment.values()
  for name, value in requests {
    if !self.kind(name).accepts(value) {
      raise Invalid("request/schema type mismatch: " + name)
    }
  }
  let mut values : Map[String, Value] = Map([])
  for d in self.defs {
    values[d.name] = self.kind(d.name).initial()
  }
  let reasons : Map[String, String] = Map([])
  for _ in 0..<(self.defs.length() * 4 + 32) {
    let next : Map[String, Value] = Map([])
    let mut changed = false
    for d in self.defs {
      let (value, reason) = base_value(d, self.kind(d.name), requests, values)
      next[d.name] = value
      reasons[d.name] = reason
      if values.get(d.name) != Some(value) {
        changed = true
      }
    }
    values = next
    if !changed {
      let visibility : Map[String, Tri] = Map([])
      let messages = []
      for d in self.defs {
        visibility[d.name] = direct_visibility(d, self.kind(d.name), values)
        match requests.get(d.name) {
          Some(wanted) =>
            if values.get(d.name) != Some(wanted) {
              messages.push("request constrained: " + d.name)
            }
          None => ()
        }
      }
      return { values, visibility, reasons, messages, }
    }
  }
  raise Invalid(
    "configuration did not converge; inspect recursive dependencies",
  )
}
