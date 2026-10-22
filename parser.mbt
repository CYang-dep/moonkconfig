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
  linux612~ : Bool = false,
) -> Unit raise ConfigError {
  let (p, cond) = conditional(tokens, start)
  if p.length() != 1 || !p[0].quoted || (!linux612 && d.prompt != None) {
    raise Invalid("expected one unique quoted prompt")
  }
  let had_prompt = d.prompt != None
  d.prompt = Some(
    if linux612 {
      p[0].text.trim_start().to_owned()
    } else {
      p[0].text
    },
  )
  d.prompt_if = if linux612 {
    if had_prompt {
      Disjunction(d.prompt_if, cond)
    } else {
      cond
    }
  } else {
    Conjunction(d.prompt_if, cond)
  }
}

///|
fn set_kind(
  d : Definition,
  kind : Kind,
  linux612~ : Bool = false,
) -> Unit raise ConfigError {
  match d.kind {
    Some(k) =>
      if k != kind && !linux612 {
        raise Invalid("conflicting symbol type")
      }
    None => d.kind = Some(kind)
  }
}

///|
fn property(
  d : Definition,
  ts : Array[Token],
  linux612~ : Bool = false,
) -> Unit raise ConfigError {
  match ts[0].text {
    "bool" | "tristate" | "string" | "int" | "hex" => {
      let kind = match ts[0].text {
        "bool" => Boolean
        "tristate" => Tristate
        "string" => StringType
        "int" => Integer
        _ => Hex
      }
      set_kind(d, kind, linux612~)
      if ts.length() > 1 {
        set_prompt(d, ts, 1, linux612~)
      }
    }
    "prompt" => set_prompt(d, ts, 1, linux612~)
    "default" | "def_bool" | "def_tristate" => {
      if ts[0].text == "def_bool" {
        set_kind(d, Boolean, linux612~)
      }
      if ts[0].text == "def_tristate" {
        set_kind(d, Tristate, linux612~)
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
    "option" | "modules" => {
      if (
          ts[0].text == "option" &&
          (ts.length() != 2 || ts[1].text != "modules")
        ) ||
        (ts[0].text == "modules" && ts.length() != 1) {
        raise Invalid("only option modules is supported")
      }
      d.modules = true
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
pub fn parse_kconfig(
  text : String,
  preprocessor~ : Preprocessor = Preprocessor::new(),
) -> Schema raise ConfigError {
  if text.length() > 4194304 {
    raise Invalid("Kconfig input exceeds 4 Mi UTF-16 units")
  }
  parse_sources("Kconfig", Map([("Kconfig", text)]), preprocessor~)
}

///|
priv struct Scope {
  tag : String
  choice_start : Int32
  start : Int32
  mut depends : Expr
  mut visible : Expr
}

///|
fn close_scope(
  schema : Schema,
  scopes : Array[Scope],
  expected : String,
) -> Unit raise ConfigError {
  let scope = match scopes.pop() {
    Some(s) => s
    None => raise Invalid("unmatched " + expected)
  }
  if scope.tag != expected {
    raise Invalid("mismatched scope terminator " + expected)
  }
  for i in scope.choice_start..<schema.choices.length() {
    let c = schema.choices[i]
    c.depends = Conjunction(c.depends, scope.depends)
    c.prompt_if = Conjunction(c.prompt_if, scope.visible)
  }
  for i in scope.start..<schema.defs.length() {
    let d = schema.defs[i]
    d.depends = Conjunction(d.depends, scope.depends)
    d.prompt_if = Conjunction(d.prompt_if, scope.visible)
  }
}

///|
fn parse_lines(
  lines : Array[SourceLine],
  linux612~ : Bool = false,
) -> Schema raise ConfigError {
  let schema = Schema::new(linux612~)
  let scopes : Array[Scope] = []
  let mut active_choice : Int32? = None
  let mut current : Int32? = None
  let mut comment_header = false
  let mut seen_statement = false
  let mut seen_modules = false
  let mut pos = 0
  while pos < lines.length() {
    let line = lines[pos]
    pos += 1
    let ts = tokenize(line.text)
    if ts.is_empty() {
      continue
    }
    try {
      if ts[0].quoted {
        raise Invalid("quoted directive is invalid")
      }
      if [
          "config", "menuconfig", "choice", "endchoice", "if", "endif", "menu", "endmenu",
          "mainmenu", "comment",
        ].contains(ts[0].text) {
        comment_header = false
      }
      if linux612 {
        validate_linux_tokens(ts)
        if ts[0].text == "modules" {
          if seen_modules {
            raise Invalid("modules directive repeated")
          }
          seen_modules = true
        }
        if ts[0].text == "mainmenu" && seen_statement {
          raise Invalid("mainmenu must be the first statement")
        }
        if active_choice != None && ["menu", "menuconfig"].contains(ts[0].text) {
          raise Invalid("statement not allowed inside choice")
        }
        if ts[0].text == "bool" &&
          current == None &&
          active_choice != None &&
          ts.length() == 1 {
          raise Invalid("choice bool requires a prompt")
        }
      }
      seen_statement = true
      match ts[0].text {
        "config" | "menuconfig" => {
          if ts.length() != 2 ||
            ts[1].quoted ||
            !identifier(ts[1].text) ||
            (!linux612 && ["n", "m", "y"].contains(ts[1].text)) {
            raise Invalid("invalid config declaration")
          }
          if schema.defs.length() >= 4096 {
            raise Invalid("too many symbols")
          }
          match active_choice {
            Some(i) => schema.choices[i].members.push(ts[1].text)
            None => ()
          }
          let node = definition(ts[1].text, None, line.location)
          node.choice_owner = match active_choice {
            Some(i) => Some(schema.choices[i].name)
            None => None
          }
          schema.defs.push(node)
          current = Some(schema.defs.length() - 1)
        }
        "choice" => {
          if linux612 && ts.length() != 1 {
            raise Invalid("Linux v6.12 requires anonymous boolean choices")
          }
          if active_choice != None {
            raise Invalid("nested choices unsupported")
          }
          if ts.length() > 2 ||
            (ts.length() == 2 && (ts[1].quoted || !identifier(ts[1].text))) {
            raise Invalid("invalid choice declaration")
          }
          let name = if ts.length() == 2 {
            ts[1].text
          } else {
            "choice_" + schema.choices.length().to_string()
          }
          if schema.choices.any(fn(c) { c.name == name }) {
            raise Invalid("duplicate choice name")
          }
          schema.choices.push({
            name,
            prompt: None,
            prompt_if: truth(),
            depends: truth(),
            optional: false,
            help: "",
            defaults: [],
            members: [],
          })
          active_choice = Some(schema.choices.length() - 1)
          scopes.push({
            tag: "endchoice",
            start: schema.defs.length(),
            choice_start: schema.choices.length(),
            depends: truth(),
            visible: truth(),
          })
          current = None
        }
        "endchoice" => {
          if ts.length() != 1 {
            raise Invalid("unexpected endchoice arguments")
          }
          let i = match active_choice {
            Some(i) => i
            None => raise Invalid("unmatched endchoice")
          }
          let c = schema.choices[i]
          for
            d in schema.defs.filter(fn(node) {
              node.choice_owner == Some(c.name)
            }) {
            d.depends = Conjunction(d.depends, c.depends)
            d.prompt_if = Conjunction(d.prompt_if, c.prompt_if)
            if c.prompt == None {
              d.prompt_if = Constant(Logic(N))
            }
          }
          close_scope(schema, scopes, "endchoice")
          active_choice = None
          current = None
        }
        "if" | "menu" => {
          if scopes.length() >= 64 {
            raise Invalid("scope nesting exceeds 64")
          }
          let dep = if ts[0].text == "if" {
            parse_expression_tokens(suffix(ts, 1))
          } else {
            if ts.length() != 2 || !ts[1].quoted {
              raise Invalid("menu needs quoted title")
            }
            truth()
          }
          scopes.push({
            tag: if ts[0].text == "if" {
              "endif"
            } else {
              "endmenu"
            },
            choice_start: schema.choices.length(),
            start: schema.defs.length(),
            depends: dep,
            visible: truth(),
          })
          current = None
        }
        "endif" | "endmenu" => {
          if ts.length() != 1 {
            raise Invalid("unexpected terminator arguments")
          }
          close_scope(schema, scopes, ts[0].text)
          current = None
        }
        "mainmenu" | "comment" => {
          comment_header = ts[0].text == "comment"
          if ts.length() != 2 || !ts[1].quoted {
            raise Invalid("expected quoted title")
          }
          current = None
        }
        "help" | "---help---" => {
          if ts.length() != 1 {
            raise Invalid("unexpected help arguments")
          }
          if current == None && active_choice == None {
            raise Invalid("help outside symbol/choice")
          }
          let base = indentation(line.text)
          let parts : Array[String] = []
          let mut margin = -1
          while pos < lines.length() {
            let next = lines[pos].text
            if !next.trim().is_empty() &&
              (if linux612 {
                indentation(next) < (if margin >= 0 { margin } else { 1 })
              } else {
                indentation(next) <= base
              }) {
              break
            }
            if !next.trim().is_empty() && margin < 0 {
              margin = indentation(next)
            }
            if next.trim().is_empty() {
              parts.push("")
            } else {
              let begin = if indentation(next) < margin {
                indentation(next)
              } else {
                margin
              }
              parts.push(next[begin:].to_owned())
            }
            pos += 1
          }
          let help = parts.join("\n").trim().to_owned()
          match current {
            Some(i) => schema.defs[i].help = help
            None =>
              match active_choice {
                Some(i) => schema.choices[i].help = help
                None => ()
              }
          }
        }
        _ => {
          if comment_header {
            if ts[0].text != "depends" || ts.length() < 3 || ts[1].text != "on" {
              raise Invalid("unsupported comment property")
            }
            ignore(parse_expression_tokens(suffix(ts, 2)))
            continue
          }
          match current {
            Some(i) => {
              if linux612 && ts[0].text == "option" {
                raise Invalid("option is not a Linux v6.12 directive")
              }
              property(schema.defs[i], ts, linux612~)
            }
            None => {
              if active_choice is Some(i) &&
                !scopes.is_empty() &&
                scopes[scopes.length() - 1].tag == "endchoice" {
                if linux612 && ts[0].text == "optional" {
                  raise Invalid("optional is not a Linux v6.12 directive")
                }
                choice_property(schema.choices[i], ts, linux612~)
                continue
              }
              if scopes.is_empty() {
                raise Invalid("property outside config/menu")
              }
              let scope = scopes[scopes.length() - 1]
              if scope.tag != "endmenu" || scope.start != schema.defs.length() {
                raise Invalid("property outside menu header")
              }
              if ts[0].text == "depends" &&
                ts.length() > 2 &&
                ts[1].text == "on" {
                scope.depends = Conjunction(
                  scope.depends,
                  parse_expression_tokens(suffix(ts, 2)),
                )
              } else if ts[0].text == "visible" &&
                ts.length() > 2 &&
                ts[1].text == "if" {
                scope.visible = Conjunction(
                  scope.visible,
                  parse_expression_tokens(suffix(ts, 2)),
                )
              } else {
                raise Invalid("unsupported menu property")
              }
            }
          }
        }
      }
    } catch {
      Invalid(msg) => raise Invalid(line.location + ": " + msg)
    }
  }
  if !scopes.is_empty() {
    raise Invalid("unterminated Kconfig scope")
  }
  let merged = merge_declarations(schema)
  merged.validate()
  merged
}
