///|
/// Linux olddefconfig import: unknown, malformed and invalid assignments are
/// ignored; later valid assignments override earlier ones. Diagnostics are
/// returned separately so applications can choose to treat them as errors.
pub fn Schema::read_linux_config(
  self : Schema,
  text : String,
) -> (Fragment, Array[String]) raise ConfigError {
  if !self.linux612 {
    raise Invalid("read_linux_config requires Linux v6.12 profile")
  }
  let out = Fragment::new()
  let messages : Array[String] = []
  for index, raw in text.split("\n").to_array() {
    let line = raw.trim_end(chars="\r").to_owned()
    if line.is_empty() ||
      (line.has_prefix("#") && !line.has_prefix("# CONFIG_")) {
      continue
    }
    try {
      let parsed = self.parse_config(line)
      for (name, value) in parsed.entries {
        if out.entries.any(fn(e) { e.0 == name }) {
          messages.push("override: " + name)
        }
        self.request(out, name, value)
      }
    } catch {
      Invalid(msg) =>
        messages.push("line " + (index + 1).to_string() + ": " + msg)
    }
  }
  (out, messages)
}

///|
// Native .config writes visible symbols, active nonzero defaults, reverse
// dependencies and scalar defaults; hidden inactive entries are omitted.
fn linux_should_write(
  schema : Schema,
  d : Definition,
  result : Resolution,
) -> Bool raise ConfigError {
  let kind = schema.effective_kind(d.name, result.values)
  if direct_visibility(schema, d, kind, result.values) != N {
    return true
  }
  if schema.choices.any(fn(c) { c.members.contains(d.name) }) {
    return false
  }
  let modules = schema.modules_enabled(result.values)
  if reverse_strength(schema, d.name, result.values, false) != N {
    return true
  }
  if reverse_strength(schema, d.name, result.values, true) != N {
    return true
  }
  for (_, cond) in d.defaults {
    if cond
      .condition(result.values, modules, linux612=true)
      .meet(d.depends.condition(result.values, modules, linux612=true)) !=
      N {
      return if kind == Boolean || kind == Tristate {
        result.value(d.name).logic() != N
      } else {
        true
      }
    }
  }
  false
}

///|
/// Linux v6.12 .config assignments, with native omission rules. Menu captions
/// and generated-file comments are intentionally presentation of the host UI.
pub fn Schema::export_linux_config(
  self : Schema,
  result : Resolution,
) -> String raise ConfigError {
  if !self.linux612 {
    raise Invalid("export_linux_config requires Linux v6.12 profile")
  }
  self.check_snapshot(result)
  let lines : Array[String] = []
  for d in self.defs {
    if linux_should_write(self, d, result) {
      lines.push(config_line(d.name, self.kind(d.name), result.value(d.name)))
    }
  }
  lines.join("")
}
