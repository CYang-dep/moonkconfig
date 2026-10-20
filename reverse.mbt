///|
fn reverse_strength(
  schema : Schema,
  target : String,
  values : Map[String, Value],
  weak : Bool,
) -> Tri {
  let mut strength = N
  for source in schema.defs {
    let source_value = values.get(source.name).unwrap_or(Logic(N)).logic()
    let edges = if weak { source.implies } else { source.selects }
    for (name, condition) in edges {
      if name == target {
        strength = strength.join(
          source_value.meet(condition.evaluate(values).logic()),
        )
      }
    }
  }
  strength
}

///|
fn apply_reverse(
  schema : Schema,
  d : Definition,
  kind : Kind,
  base : Value,
  reason : String,
  requests : Map[String, Value],
  values : Map[String, Value],
) -> (Value, String) {
  if kind != Boolean && kind != Tristate {
    return (base, reason)
  }
  let strong = reverse_strength(schema, d.name, values, false)
  let weak = reverse_strength(schema, d.name, values, true)
  let user = requests.contains(d.name) &&
    direct_visibility(d, kind, values) != N
  let mut value = base.logic()
  let mut why = reason
  if !user &&
    d.depends.evaluate(values).logic() != N &&
    weak.rank() > value.rank() {
    value = weak
    why = "imply"
  }
  if strong.rank() > value.rank() {
    value = strong
    why = "select"
  }
  if value == M && (kind == Boolean || weak == Y) {
    value = Y
  }
  (Logic(value), why)
}
