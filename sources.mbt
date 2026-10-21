///|
priv struct SourceLine {
  text : String
  location : String
}

///|
fn logical_lines(
  text : String,
  file : String,
) -> Array[SourceLine] raise ConfigError {
  if text.length() > 4194304 {
    raise Invalid("source too large")
  }
  let out : Array[SourceLine] = []
  let mut pending = ""
  let mut start = 1
  let mut n = 0
  for raw in text.split("\n") {
    n += 1
    let line = raw.trim_end(chars="\r").to_owned()
    if pending.is_empty() {
      start = n
    }
    let continued = line.has_suffix("\\")
    pending += if continued {
      line[0:line.length() - 1].to_owned()
    } else {
      line
    }
    if pending.length() > 65536 {
      raise Invalid("logical source line too long")
    }
    if !continued {
      out.push({ text: pending, location: file + ":\{start}", })
      pending = ""
    }
  }
  if !pending.is_empty() {
    raise Invalid("dangling source continuation")
  }
  out
}

///|
fn safe_source_path(path : String) -> String raise ConfigError {
  if path.is_empty() ||
    path.has_prefix("/") ||
    path.contains("\\") ||
    path.contains(":") {
    raise Invalid("source path must be relative")
  }
  let parts : Array[String] = []
  for part in path.split("/") {
    if part == ".." {
      if parts.is_empty() {
        raise Invalid("source path escapes source tree")
      }
      ignore(parts.pop())
    } else if part != "." && !part.is_empty() {
      parts.push(part.to_owned())
    }
  }
  if parts.is_empty() {
    raise Invalid("empty source path")
  }
  parts.join("/")
}

///|
fn indentation(text : String) -> Int32 {
  let mut n = 0
  while n < text.length() && (text[n] == 32 || text[n] == 9) {
    n += 1
  }
  n
}

///|
fn expand_sources(
  file : String,
  sources : Map[String, String],
  active : Array[String],
  output : Array[SourceLine],
  budget : Ref[Int32],
  preprocessor : Preprocessor,
) -> Unit raise ConfigError {
  if active.length() >= 32 || active.contains(file) {
    raise Invalid("cyclic or overdeep source: " + file)
  }
  let text = match sources.get(file) {
    Some(t) => t
    None => raise Invalid("missing source: " + file)
  }
  active.push(file)
  let mut help_indent : Int32? = None
  for line in logical_lines(text, file) {
    budget.val += line.text.length() + 1
    if budget.val > 16777216 || output.length() >= 65536 {
      raise Invalid("expanded source resource budget exceeded")
    }
    match help_indent {
      Some(level) => {
        if line.text.trim().is_empty() || indentation(line.text) > level {
          output.push(line)
          continue
        }
        help_indent = None
      }
      None => ()
    }
    let expanded = match preprocessor.line(line) {
      Some(text) => text
      None => continue
    }
    let line = { text: expanded, location: line.location, }
    let ts = tokenize(line.text)
    if !ts.is_empty() && (ts[0].text == "help" || ts[0].text == "---help---") {
      help_indent = Some(indentation(line.text))
    }
    if !ts.is_empty() &&
      (
        ts[0].text == "source" ||
        ts[0].text == "rsource" ||
        ts[0].text == "osource" ||
        ts[0].text == "orsource"
      ) {
      if ts.length() != 2 || !ts[1].quoted {
        raise Invalid(line.location + ": source needs quoted path")
      }
      let mut path = ts[1].text
      if ts[0].text == "rsource" || ts[0].text == "orsource" {
        match file.rev_split_once("/") {
          Some((dir, _)) => path = dir.to_owned() + "/" + path
          None => ()
        }
      }
      path = safe_source_path(path)
      let matches = []
      for candidate, _ in sources {
        if source_pattern(path, candidate) {
          matches.push(candidate)
        }
      }
      matches.sort()
      if matches.is_empty() &&
        (ts[0].text == "source" || ts[0].text == "rsource") {
        raise Invalid("missing source: " + path)
      }
      for found in matches {
        expand_sources(found, sources, active, output, budget, preprocessor)
      }
    } else {
      output.push(line)
    }
    if output.length() > 65536 {
      raise Invalid("expanded source exceeds 65536 lines")
    }
  }
  ignore(active.pop())
}

///|
/// Resolve explicit in-memory source files; never reads disk, shell or environment.
pub fn parse_sources(
  entry : String,
  sources : Map[String, String],
  preprocessor~ : Preprocessor = Preprocessor::new(),
) -> Schema raise ConfigError {
  let out = []
  expand_sources(
    safe_source_path(entry),
    sources,
    [],
    out,
    Ref(0),
    preprocessor,
  )
  parse_lines(out)
}
