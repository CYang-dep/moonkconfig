///|
// Keep declaration nodes separate until scope inheritance has been applied.
// Properties carry their declaration's dependency; the symbol dependency and
// prompt visibility are the disjunction of all declaration-local alternatives.
fn merge_declarations(parsed : Schema) -> Schema raise ConfigError {
  let out = Schema::new()
  for node in parsed.defs {
    if parsed.defs.filter(fn(d) { d.name == node.name }).length() == 1 {
      for i, edge in node.selects {
        node.selects[i] = (edge.0, Conjunction(node.depends, edge.1))
      }
      for i, edge in node.implies {
        node.implies[i] = (edge.0, Conjunction(node.depends, edge.1))
      }
      out.defs.push(node)
      continue
    }
    let existing = out.defs.search_by(fn(d) { d.name == node.name })
    let d = match existing {
      Some(i) => out.defs[i]
      None => {
        let fresh = definition(node.name, None, node.location)
        fresh.depends = Constant(Logic(N))
        fresh.prompt_if = Constant(Logic(N))
        out.defs.push(fresh)
        fresh
      }
    }
    match node.kind {
      Some(kind) => set_kind(d, kind)
      None => ()
    }
    d.depends = Disjunction(d.depends, node.depends)
    if node.prompt != None {
      if d.prompt == None {
        d.prompt = node.prompt
      }
      d.prompt_if = Disjunction(
        d.prompt_if,
        Conjunction(node.depends, node.prompt_if),
      )
    }
    for (value, condition) in node.defaults {
      d.defaults.push((value, Conjunction(node.depends, condition)))
    }
    for (target, condition) in node.selects {
      d.selects.push((target, Conjunction(node.depends, condition)))
    }
    for (target, condition) in node.implies {
      d.implies.push((target, Conjunction(node.depends, condition)))
    }
    for (lo, hi, condition) in node.ranges {
      d.ranges.push((lo, hi, Conjunction(node.depends, condition)))
    }
    d.modules = d.modules || node.modules
    if d.help.is_empty() {
      d.help = node.help
    }
  }
  for node in parsed.defs {
    out.nodes.push(node)
  }
  for choice in parsed.choices {
    out.choices.push(choice)
  }
  out
}

///|
/// All declaration locations, in source traversal order. Builder symbols have
/// the single location "builder"; callers receive a fresh array.
pub fn Schema::source_locations(
  self : Schema,
  name : String,
) -> Array[String] raise ConfigError {
  ignore(self.index(name))
  let nodes = self.nodes.filter(fn(d) { d.name == name })
  if nodes.is_empty() {
    [self.defs[self.index(name)].location]
  } else {
    nodes.map(fn(d) { d.location })
  }
}
