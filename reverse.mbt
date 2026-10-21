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
          source_value.meet(
            condition.condition(
              values,
              schema.modules_enabled(values),
              linux612=schema.linux612,
            ),
          ),
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
    direct_visibility(schema, d, kind, values) != N
  let mut value = base.logic()
  let mut why = reason
  if !user &&
    d.depends.condition(
      values,
      schema.modules_enabled(values),
      linux612=schema.linux612,
    ) !=
    N &&
    weak.rank() > value.rank() {
    value = if schema.linux612 {
      weak.meet(
        d.depends.condition(
          values,
          schema.modules_enabled(values),
          linux612=true,
        ),
      )
    } else {
      weak
    }
    why = "imply"
  }
  if strong.rank() > value.rank() {
    value = strong
    why = "select"
  }
  if value == M && (kind == Boolean || (!schema.linux612 && weak == Y)) {
    value = Y
  }
  (Logic(value), why)
}
