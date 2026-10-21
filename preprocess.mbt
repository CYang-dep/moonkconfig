///|
priv struct MacroVariable {
  text : String
  immediate : Bool
}

///|
/// A per-parse macro context. Host effects are explicit callbacks; environment
/// is a snapshot, never the process-global environment. Return stdout from shell.
pub struct Preprocessor {
  priv variables : Map[String, MacroVariable]
  priv environment : Map[String, String]
  priv shell : (String) -> String raise ConfigError
  priv message : (String, String) -> Unit
}

///|
pub fn Preprocessor::new(
  environment~ : Map[String, String] = Map([]),
  shell~ : (String) -> String raise ConfigError = fn(_) raise ConfigError {
    raise Invalid("shell macro requires a host executor")
  },
  message~ : (String, String) -> Unit = fn(_, _) { () },
) -> Preprocessor {
  let snapshot : Map[String, String] = Map([])
  for key, value in environment {
    snapshot[key] = value
  }
  { variables: Map([]), environment: snapshot, shell, message, }
}

///|
fn macro_comment(text : String) -> String {
  let mut quote : UInt16 = 0
  let mut escaped = false
  for i in 0..<text.length() {
    let c = text[i]
    if escaped {
      escaped = false
      continue
    }
    if c == 92 {
      escaped = true
      continue
    }
    if quote != 0 {
      if c == quote {
        quote = 0
      }
    } else if c == 34 || c == 39 {
      quote = c
    } else if c == 35 {
      return text[:i].to_owned()
    }
  }
  text
}

///|
// Split only raw commas outside nested macro references. Expanded commas are
// data and must never become new argument separators.
fn macro_arguments(text : String) -> Array[String] raise ConfigError {
  let out = []
  let mut depth = 0
  let mut start = 0
  for i in 0..<text.length() {
    if text[i] == 40 {
      depth += 1
    }
    if text[i] == 41 {
      depth -= 1
    }
    if text[i] == 44 && depth == 0 {
      out.push(text[start:i].to_owned())
      start = i + 1
    }
  }
  if depth != 0 {
    raise Invalid("unbalanced macro argument")
  }
  out.push(text[start:].to_owned())
  out
}

///|
fn macro_arity(
  name : String,
  args : Array[String],
  size : Int32,
) -> Unit raise ConfigError {
  if args.length() != size {
    raise Invalid("macro " + name + " expects \{size} arguments")
  }
}

///|
fn Preprocessor::expand_at(
  self : Preprocessor,
  text : String,
  file : String,
  line : String,
  parameters : Array[String],
  stack : Array[String],
  depth : Int32,
) -> String raise ConfigError {
  if depth > 64 {
    raise Invalid("macro expansion depth exceeds 64")
  }
  let mut result = ""
  let mut i = 0
  while i < text.length() {
    if text[i] != 36 || i + 1 >= text.length() || text[i + 1] != 40 {
      result += text[i:i + 1].to_owned()
      i += 1
    } else {
      let start = i + 2
      i = start
      let mut nested = 1
      while i < text.length() && nested > 0 {
        if text[i] == 40 {
          nested += 1
        }
        if text[i] == 41 {
          nested -= 1
        }
        if nested != 0 {
          i += 1
        }
      }
      if nested != 0 {
        raise Invalid(file + ":" + line + ": unterminated macro")
      }
      let raw = macro_arguments(text[start:i].to_owned())
      i += 1
      let expanded = raw.map(fn(s) raise ConfigError {
        self.expand_at(s, file, line, parameters, stack, depth + 1)
      })
      let name = expanded[0]
      let args = suffix_strings(expanded, 1)
      let mut positional : String? = None
      for j in 0..<parameters.length() {
        if name == (j + 1).to_string() {
          positional = Some(parameters[j])
        }
      }
      let replacement = match positional {
        Some(value) => value
        None =>
          match name {
            "filename" => {
              macro_arity(name, args, 0)
              file
            }
            "lineno" => {
              macro_arity(name, args, 0)
              line
            }
            "shell" => {
              macro_arity(name, args, 1)
              let stdout = (self.shell)(args[0])
              stdout
              .trim_end(chars="\n")
              .to_owned()
              .split("\n")
              .map(fn(s) { s.to_owned() })
              .join(" ")
            }
            "info" => {
              macro_arity(name, args, 1)
              (self.message)("info", args[0])
              ""
            }
            "warning-if" | "error-if" => {
              macro_arity(name, args, 2)
              if args[0] == "y" {
                let msg = file + ":" + line + ": " + args[1]
                if name == "error-if" {
                  raise Invalid(msg)
                }
                (self.message)("warning", msg)
              }
              ""
            }
            _ =>
              match self.variables.get(name) {
                Some(variable) =>
                  if variable.immediate {
                    variable.text
                  } else {
                    if stack.contains(name) {
                      raise Invalid("recursive macro " + name)
                    }
                    self.expand_at(
                      variable.text,
                      file,
                      line,
                      args,
                      stack + [name],
                      depth + 1,
                    )
                  }
                None => self.environment.get(name).unwrap_or("")
              }
          }
      }
      result += replacement
    }
    if result.length() > 65536 {
      raise Invalid("expanded macro line too long")
    }
  }
  result
}

///|
fn suffix_strings(items : Array[String], start : Int32) -> Array[String] {
  let out = []
  for i in start..<items.length() {
    out.push(items[i])
  }
  out
}

///|
fn Preprocessor::line(
  self : Preprocessor,
  line : SourceLine,
) -> String? raise ConfigError {
  let text = macro_comment(line.text)
  let (file, number) = match line.location.rev_split_once(":") {
    Some((f, n)) => (f.to_owned(), n.to_owned())
    None => (line.location, "1")
  }
  let mut equal = -1
  let mut nesting = 0
  let mut quoted : UInt16 = 0
  for i in 0..<text.length() {
    if text[i] == 34 || text[i] == 39 {
      if quoted == 0 {
        quoted = text[i]
      } else if quoted == text[i] {
        quoted = 0
      }
    }
    if text[i] == 40 {
      nesting += 1
    }
    if text[i] == 41 {
      nesting -= 1
    }
    if text[i] == 61 && nesting == 0 && quoted == 0 {
      equal = i
      break
    }
  }
  if equal >= 0 {
    let before = text[:equal].trim().to_owned()
    let immediate = before.has_suffix(":")
    let append = before.has_suffix("+")
    let lhs = if immediate || append {
      before[:before.length() - 1].trim().to_owned()
    } else {
      before
    }
    let name = self.expand_at(lhs, file, number, [], [], 0)
    if !name.is_empty() &&
      name
      .to_array()
      .all(fn(c) {
        c == '-' ||
        c == '_' ||
        (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9')
      }) {
      let old = self.variables.get(name)
      let simple = if append {
        match old {
          Some(v) => v.immediate
          None => false
        }
      } else {
        immediate
      }
      let raw = text[equal + 1:].trim_start().to_owned()
      let value = if simple {
        self.expand_at(raw, file, number, [], [], 0)
      } else {
        raw
      }
      let joined = if append {
        match old {
          Some(v) => v.text + " " + value
          None => value
        }
      } else {
        value
      }
      self.variables[name] = { text: joined, immediate: simple, }
      return None
    }
  }
  Some(self.expand_tokens(text, file, number))
}

///|
// Expand within the original lexical token. A replacement inside a quote is
// data, not new Kconfig syntax; quote/backslash bytes must remain literal.
fn Preprocessor::expand_tokens(
  self : Preprocessor,
  text : String,
  file : String,
  number : String,
) -> String raise ConfigError {
  let mut out = ""
  let mut quote : UInt16 = 0
  let mut i = 0
  while i < text.length() {
    if text[i] == 92 && i + 1 < text.length() {
      out += text[i:i + 2].to_owned()
      i += 2
      continue
    }
    if text[i] == 36 && i + 1 < text.length() && text[i + 1] == 40 {
      let start = i
      i += 2
      let mut depth = 1
      while i < text.length() && depth > 0 {
        if text[i] == 40 {
          depth += 1
        }
        if text[i] == 41 {
          depth -= 1
        }
        i += 1
      }
      if depth != 0 {
        raise Invalid(file + ":" + number + ": unterminated macro")
      }
      let replacement = self.expand_at(
        text[start:i].to_owned(),
        file,
        number,
        [],
        [],
        0,
      )
      if quote != 0 {
        for j in 0..<replacement.length() {
          if replacement[j] == quote || replacement[j] == 92 {
            out += "\\"
          }
          out += replacement[j:j + 1].to_owned()
        }
      } else {
        if replacement
          .to_array()
          .any(fn(c) { c == ' ' || c == '\t' || c == '\n' }) {
          raise Invalid("macro expansion cannot span unquoted tokens")
        }
        if out.trim().is_empty() && !replacement.is_empty() {
          raise Invalid("macro expansion cannot produce a Kconfig keyword")
        }
        out += replacement
      }
    } else {
      if text[i] == 34 || text[i] == 39 {
        if quote == 0 {
          quote = text[i]
        } else if quote == text[i] {
          quote = 0
        }
      }
      out += text[i:i + 1].to_owned()
      i += 1
    }
    if out.length() > 65536 {
      raise Invalid("expanded macro line too long")
    }
  }
  out
}
