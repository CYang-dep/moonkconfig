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
  if kind != Tristate && value == M {
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
        Unset | Number(_) => value
        _ => Number(parse_number(value.text()))
      }
  }
}

///|
fn direct_visibility(
  schema : Schema,
  d : Definition,
  kind : Kind,
  values : Map[String, Value],
) -> Tri {
  if d.prompt == None {
    N
  } else {
    logical_bound(
      d.depends
      .condition(
        values,
        schema.modules_enabled(values),
        linux612=schema.linux612,
      )
      .meet(
        d.prompt_if.condition(
          values,
          schema.modules_enabled(values),
          linux612=schema.linux612,
        ),
      ),
      kind,
    )
  }
}

///|
fn base_value(
  schema : Schema,
  d : Definition,
  kind : Kind,
  requests : Map[String, Value],
  values : Map[String, Value],
) -> (Value, String) raise ConfigError {
  if schema.linux612 && d.kind == None {
    return (Text(d.name), "undefined-type")
  }
  let visible = direct_visibility(schema, d, kind, values)
  match requests.get(d.name) {
    Some(v) =>
      if visible != N &&
        (schema.linux612 || request_in_range(schema, d, v, values)) {
        let v = if schema.linux612 {
          clamp_default(schema, d, v, values)
        } else {
          v
        }
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
      .condition(
        values,
        schema.modules_enabled(values),
        linux612=schema.linux612,
      )
      .meet(
        d.depends.condition(
          values,
          schema.modules_enabled(values),
          linux612=schema.linux612,
        ),
      )
    if active != N {
      let raw = expr.typed_value(kind, values, linux612=schema.linux612)
      let value = clamp_default(schema, d, raw, values)
      return (
        match value {
          Logic(t) => Logic(logical_bound(t.meet(active), kind))
          _ => value
        },
        "default",
      )
    }
  }
  (
    clamp_default(
      schema,
      d,
      if schema.linux612 {
        linux_initial(kind)
      } else {
        kind.initial()
      },
      values,
    ),
    "initial",
  )
}

///|
/// Resolve to a bounded fixed point; requests never override hidden prompts.
pub fn Schema::resolve(
  self : Schema,
  fragment : Fragment,
) -> Resolution raise ConfigError {
  ignore(self.dependency_order())
  let requests = fragment.values()
  for name, value in requests {
    if !self.kind(name).accepts(value) {
      raise Invalid("request/schema type mismatch: " + name)
    }
  }
  let mut values : Map[String, Value] = Map([])
  for d in self.defs {
    values[d.name] = if self.linux612 && d.kind == None {
      Text(d.name)
    } else if self.linux612 {
      linux_initial(self.kind(d.name))
    } else {
      self.kind(d.name).initial()
    }
  }
  let reasons : Map[String, String] = Map([])
  for _ in 0..<(self.defs.length() * 4 + 32) {
    let next : Map[String, Value] = Map([])
    for d in self.defs {
      let kind = self.effective_kind(d.name, values)
      let (base, why) = base_value(self, d, kind, requests, values)
      let (value, reason) = apply_reverse(
        self, d, kind, base, why, requests, values,
      )
      next[d.name] = value
      reasons[d.name] = reason
    }
    apply_choices(self, fragment, values, next, reasons)
    let changed = self.defs.any(fn(d) { values.get(d.name) != next.get(d.name) })
    values = next
    if !changed {
      let visibility : Map[String, Tri] = Map([])
      let messages = []
      for d in self.defs {
        let strong = reverse_strength(self, d.name, values, false)
        if strong.rank() >
          d.depends
          .condition(
            values,
            self.modules_enabled(values),
            linux612=self.linux612,
          )
          .rank() {
          messages.push("select bypasses dependencies: " + d.name)
        }
        visibility[d.name] = direct_visibility(
          self,
          d,
          self.effective_kind(d.name, values),
          values,
        )
        match requests.get(d.name) {
          Some(wanted) =>
            if values.get(d.name) != Some(wanted) {
              messages.push("request constrained: " + d.name)
            }
          None => ()
        }
      }
      for c in self.choices {
        let mode = !c.optional ||
          fragment.entries.any(fn(e) {
            c.members.contains(e.0) && e.1 == Logic(Y)
          })
        if !mode {
          for name in c.members {
            visibility[name] = N
          }
        }
      }
      return { values, visibility, reasons, messages, }
    }
  }
  raise Invalid(
    "configuration did not converge; inspect recursive dependencies",
  )
}
