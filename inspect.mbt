///|
pub(all) struct SymbolView {
  name : String
  kind : Kind
  value : Value
  prompt : String?
  help : String
  visibility : Tri
  reason : String
  location : String
  dependencies : Array[String]
  numeric_range : (Int64, Int64)?
} derive(Eq, Debug)

///|
/// UI-facing copies; changing returned arrays cannot mutate the schema.
pub fn Schema::inspect(
  self : Schema,
  result : Resolution,
) -> Array[SymbolView] raise ConfigError {
  self.check_snapshot(result)
  let graph = dependency_graph(self)
  let out = []
  for d in self.defs {
    out.push({
      name: d.name,
      kind: self.kind(d.name),
      value: result.value(d.name),
      prompt: d.prompt,
      help: d.help,
      visibility: result.visibility(d.name),
      reason: result.reason(d.name),
      location: d.location,
      dependencies: graph[d.name].copy(),
      numeric_range: active_range(self, d, result.values),
    })
  }
  out
}

///|
/// Values achievable by making this the last explicit request. This is an
/// executable transition query, not a claim to reproduce menuconfig widgets.
pub fn Schema::request_options(
  self : Schema,
  fragment : Fragment,
  name : String,
) -> Array[Value] raise ConfigError {
  if self.defs.length() > 256 {
    raise Invalid("interactive request probing supports at most 256 symbols")
  }
  let kind = self.kind(name)
  if kind != Boolean && kind != Tristate {
    return []
  }
  let current = self.resolve(fragment)
  if current.visibility(name) == N {
    return []
  }
  let candidates = if kind == Boolean {
    [Logic(N), Logic(Y)]
  } else {
    [Logic(N), Logic(M), Logic(Y)]
  }
  let out = []
  for value in candidates {
    let trial = merge_fragments([fragment])
    self.request(trial, name, value)
    if self.resolve(trial).value(name) == value {
      out.push(value)
    }
  }
  out
}

///|
#deprecated
pub extend SymbolView with @debug.Debug::{to_repr}

///|
#deprecated
pub extend SymbolView with Eq::{equal, not_equal}
