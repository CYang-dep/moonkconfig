///|
fn Schema::modules_enabled(self : Schema, values : Map[String, Value]) -> Bool {
  for d in self.defs {
    if d.modules {
      return values.get(d.name) == Some(Logic(Y))
    }
  }
  false
}

///|
fn Schema::effective_kind(
  self : Schema,
  name : String,
  values : Map[String, Value],
) -> Kind raise ConfigError {
  let kind = self.kind(name)
  if kind == Tristate && !self.modules_enabled(values) {
    Boolean
  } else {
    kind
  }
}

///|
/// Bare m in dependency contexts means m && MODULES; comparisons retain m.
fn Expr::condition(
  self : Expr,
  values : Map[String, Value],
  modules : Bool,
  linux612~ : Bool = false,
) -> Tri {
  match self {
    Constant(Logic(M)) => if modules { M } else { N }
    Negation(a) => a.condition(values, modules, linux612~).negate()
    Conjunction(a, b) =>
      a
      .condition(values, modules, linux612~)
      .meet(b.condition(values, modules, linux612~))
    Disjunction(a, b) =>
      a
      .condition(values, modules, linux612~)
      .join(b.condition(values, modules, linux612~))
    _ => self.evaluate(values, linux612~).logic()
  }
}
