///|
priv struct Choice {
  name : String
  mut prompt : String?
  mut prompt_if : Expr
  mut depends : Expr
  mut help : String
  mut optional : Bool
  defaults : Array[(String, Expr)]
  members : Array[String]
}

///|
fn choice_property(c : Choice, ts : Array[Token]) -> Unit raise ConfigError {
  match ts[0].text {
    "bool" | "prompt" => {
      if ts.length() == 1 && ts[0].text == "bool" {
        return
      }
      let (tokens, cond) = conditional(ts, 1)
      if tokens.length() != 1 || !tokens[0].quoted || c.prompt != None {
        raise Invalid("choice needs one quoted prompt")
      }
      c.prompt = Some(tokens[0].text)
      c.prompt_if = cond
    }
    "default" => {
      let (tokens, cond) = conditional(ts, 1)
      if tokens.length() != 1 || tokens[0].quoted || !identifier(tokens[0].text) {
        raise Invalid("choice default must name member")
      }
      c.defaults.push((tokens[0].text, cond))
    }
    "depends" => {
      if ts.length() < 3 || ts[1].text != "on" {
        raise Invalid("expected choice depends on")
      }
      c.depends = Conjunction(c.depends, parse_expression_tokens(suffix(ts, 2)))
    }
    "optional" => {
      if ts.length() != 1 {
        raise Invalid("optional takes no arguments")
      }
      c.optional = true
    }
    _ =>
      raise Invalid(
        "unsupported choice property (only boolean choices supported): " +
        ts[0].text,
      )
  }
}

///|
fn apply_choices(
  schema : Schema,
  requests : Fragment,
  previous : Map[String, Value],
  next : Map[String, Value],
  reasons : Map[String, String],
) -> Unit raise ConfigError {
  let modules = schema.modules_enabled(previous)
  for c in schema.choices {
    let visibility = if c.prompt == None {
      N
    } else {
      c.depends
      .condition(previous, modules)
      .meet(c.prompt_if.condition(previous, modules))
    }
    let visible_members = c.members.filter(fn(name) raise ConfigError {
      let d = schema.defs[schema.index(name)]
      direct_visibility(schema, d, Boolean, previous) != N
    })
    let mut selected : String? = None
    let enabled = visibility != N &&
      (
        !c.optional ||
        requests.entries.any(fn(e) {
          c.members.contains(e.0) && e.1 == Logic(Y)
        })
      )
    if enabled {
      for (name, value) in requests.entries {
        if c.members.contains(name) &&
          visible_members.contains(name) &&
          value == Logic(Y) {
          selected = Some(name)
        }
      }
      if selected == None {
        for (name, cond) in c.defaults {
          if cond.condition(previous, modules) != N &&
            visible_members.contains(name) {
            selected = Some(name)
            break
          }
        }
        if selected == None && !visible_members.is_empty() {
          selected = Some(visible_members[0])
        }
      }
    }
    for name in c.members {
      next[name] = Logic(if selected == Some(name) { Y } else { N })
      reasons[name] = if selected == Some(name) {
        "choice-selected"
      } else {
        "choice-excluded"
      }
    }
  }
}

///|
pub fn Schema::choice_names(self : Schema) -> Array[String] {
  self.choices.map(fn(c) { c.name })
}

///|
pub fn Schema::choice_members(
  self : Schema,
  name : String,
) -> Array[String] raise ConfigError {
  for c in self.choices {
    if c.name == name {
      return c.members.copy()
    }
  }
  raise Invalid("unknown choice " + name)
}

///|
/// Help attached to a choice, addressed by its name or generated choice_N name.
pub fn Schema::choice_help(
  self : Schema,
  name : String,
) -> String raise ConfigError {
  for c in self.choices {
    if c.name == name {
      return c.help
    }
  }
  raise Invalid("unknown choice " + name)
}
