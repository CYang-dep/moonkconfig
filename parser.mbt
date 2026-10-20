///|
fn suffix(tokens : Array[Token], start : Int32) -> Array[Token] {
  let out = []
  for i in start..<tokens.length() {
    out.push(tokens[i])
  }
  out
}

///|
fn set_prompt(
  d : Definition,
  tokens : Array[Token],
  start : Int32,
) -> Unit raise ConfigError {
  let (p, cond) = conditional(tokens, start)
  if p.length() != 1 || !p[0].quoted || d.prompt != None {
    raise Invalid("expected one unique quoted prompt")
  }
  d.prompt = Some(p[0].text)
  d.prompt_if = cond
}

///|
fn set_kind(d : Definition, kind : Kind) -> Unit raise ConfigError {
  match d.kind {
    Some(k) => if k != kind { raise Invalid("conflicting symbol type") }
    None => d.kind = Some(kind)
  }
}

///|
fn property(d : Definition, ts : Array[Token]) -> Unit raise ConfigError {
  match ts[0].text {
    "bool" | "tristate" | "string" | "int" | "hex" => {
      let kind = match ts[0].text {
        "bool" => Boolean
        "tristate" => Tristate
        "string" => StringType
        "int" => Integer
        _ => Hex
      }
      set_kind(d, kind)
      if ts.length() > 1 {
        set_prompt(d, ts, 1)
      }
    }
    "prompt" => set_prompt(d, ts, 1)
    "default" | "def_bool" | "def_tristate" => {
      if ts[0].text == "def_bool" {
        set_kind(d, Boolean)
      }
      if ts[0].text == "def_tristate" {
        set_kind(d, Tristate)
      }
      let (v, c) = conditional(ts, 1)
      d.defaults.push((parse_expression_tokens(v), c))
    }
    "depends" => {
      if ts.length() < 3 || ts[1].text != "on" {
        raise Invalid("expected depends on expression")
      }
      d.depends = Conjunction(d.depends, parse_expression_tokens(suffix(ts, 2)))
    }
    "select" | "imply" => {
      let (names, cond) = conditional(ts, 1)
      if names.length() != 1 || names[0].quoted || !identifier(names[0].text) {
        raise Invalid("expected one target symbol")
      }
      if ts[0].text == "select" {
        d.selects.push((names[0].text, cond))
      } else {
        d.implies.push((names[0].text, cond))
      }
    }
    "range" => {
      let (bounds, cond) = conditional(ts, 1)
      if bounds.length() != 2 {
        raise Invalid("expected two range bounds")
      }
      d.ranges.push((atom(bounds[0]), atom(bounds[1]), cond))
    }
    _ => raise Invalid("unsupported property: " + ts[0].text)
  }
}

///|
/// Parse the portable core; unsupported directives are errors, not ignored.
pub fn parse_kconfig(text : String) -> Schema raise ConfigError {
  if text.length() > 4194304 {
    raise Invalid("Kconfig input exceeds 4 Mi UTF-16 units")
  }
  let schema = Schema::new()
  let mut current : Int32? = None
  let mut line_no = 0
  for line in text.split("\n") {
    line_no += 1
    let ts = tokenize(line.to_owned())
    if ts.is_empty() {
      continue
    }
    try {
      match ts[0].text {
        "config" | "menuconfig" => {
          if ts.length() != 2 ||
            ts[1].quoted ||
            !identifier(ts[1].text) ||
            ts[1].text == "n" ||
            ts[1].text == "m" ||
            ts[1].text == "y" {
            raise Invalid("invalid config declaration")
          }
          if schema.defs.any(fn(d) { d.name == ts[1].text }) {
            raise Invalid("repeated definitions unsupported")
          }
          if schema.defs.length() >= 4096 {
            raise Invalid("too many symbols")
          }
          let d = definition(ts[1].text, None, "Kconfig:\{line_no}")
          schema.defs.push(d)
          current = Some(schema.defs.length() - 1)
        }
        _ =>
          match current {
            Some(i) => property(schema.defs[i], ts)
            None => raise Invalid("property outside config")
          }
      }
    } catch {
      Invalid(msg) => raise Invalid("line \{line_no}: " + msg)
    }
  }
  schema.validate()
  schema
}
