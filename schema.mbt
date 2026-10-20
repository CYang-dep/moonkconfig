///|
priv struct Definition {
  name : String
  mut kind : Kind?
  mut prompt : String?
  mut prompt_if : Expr
  mut depends : Expr
  defaults : Array[(Expr, Expr)]
  selects : Array[(String, Expr)]
  implies : Array[(String, Expr)]
  ranges : Array[(Expr, Expr, Expr)]
  mut help : String
  location : String
}

///|
fn definition(name : String, kind : Kind?, location : String) -> Definition {
  {
    name,
    kind,
    prompt: None,
    prompt_if: truth(),
    depends: truth(),
    defaults: [],
    selects: [],
    implies: [],
    ranges: [],
    help: "",
    location,
  }
}

///|
/// Opaque schema; callers cannot mutate internal dependency structures.
pub struct Schema {
  priv defs : Array[Definition]
}

///|
pub fn Schema::new() -> Schema {
  { defs: [], }
}

///|
fn Schema::index(self : Schema, name : String) -> Int32 raise ConfigError {
  for i, d in self.defs {
    if d.name == name {
      return i
    }
  }
  raise Invalid("undefined configuration symbol " + name)
}

///|
pub fn Schema::names(self : Schema) -> Array[String] {
  self.defs.map(fn(d) { d.name })
}

///|
pub fn Schema::kind(self : Schema, name : String) -> Kind raise ConfigError {
  let d = self.defs[self.index(name)]
  match d.kind {
    Some(k) => k
    None => raise Invalid("missing type: " + name)
  }
}

///|
pub fn Schema::add(
  self : Schema,
  name : String,
  kind : Kind,
  prompt? : String,
) -> Unit raise ConfigError {
  if !identifier(name) || name == "n" || name == "m" || name == "y" {
    raise Invalid("invalid symbol name " + name)
  }
  if self.defs.any(fn(d) { d.name == name }) {
    raise Invalid("duplicate builder symbol " + name)
  }
  if self.defs.length() >= 4096 {
    raise Invalid("too many symbols")
  }
  let d = definition(name, Some(kind), "builder")
  d.prompt = prompt
  self.defs.push(d)
}

///|
pub fn Schema::dependency(
  self : Schema,
  name : String,
  expr : Expr,
) -> Unit raise ConfigError {
  let d = self.defs[self.index(name)]
  d.depends = Conjunction(d.depends, expr)
}

///|
pub fn Schema::default_value(
  self : Schema,
  name : String,
  value : Expr,
  condition~ : Expr = truth(),
) -> Unit raise ConfigError {
  self.defs[self.index(name)].defaults.push((value, condition))
}

///|
pub fn Schema::reverse_dependency(
  self : Schema,
  source : String,
  target : String,
  weak~ : Bool = false,
  condition~ : Expr = truth(),
) -> Unit raise ConfigError {
  let d = self.defs[self.index(source)]
  if !identifier(target) {
    raise Invalid("invalid reverse dependency target")
  }
  if weak {
    d.implies.push((target, condition))
  } else {
    d.selects.push((target, condition))
  }
}

///|
pub fn Schema::validate(self : Schema) -> Unit raise ConfigError {
  for d in self.defs {
    let kind = self.kind(d.name)
    if (kind == StringType || kind == Integer || kind == Hex) &&
      (!d.selects.is_empty() || !d.implies.is_empty()) {
      raise Invalid("select/imply source must be logical: " + d.name)
    }
    for edge in d.selects + d.implies {
      let target_kind = self.kind(edge.0)
      if target_kind != Boolean && target_kind != Tristate {
        raise Invalid("select/imply target must be logical: " + edge.0)
      }
    }
    if !d.ranges.is_empty() && kind != Integer && kind != Hex {
      raise Invalid("range needs numeric type")
    }
  }
}

///|
pub fn Schema::prompt(
  self : Schema,
  name : String,
) -> (String?, Expr) raise ConfigError {
  let d = self.defs[self.index(name)]
  (d.prompt, d.prompt_if)
}

///|
pub fn Schema::source_location(
  self : Schema,
  name : String,
) -> String raise ConfigError {
  self.defs[self.index(name)].location
}

///|
pub fn Schema::help(self : Schema, name : String) -> String raise ConfigError {
  self.defs[self.index(name)].help
}
