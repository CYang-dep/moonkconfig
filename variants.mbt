///|
pub(all) struct ConfigChange {
  name : String
  before : Value
  after : Value
} derive(Eq, Debug)

///|
pub(all) struct OverlayConflict {
  name : String
  previous : Value
  replacement : Value
  fragment_index : Int32
} derive(Eq, Debug)

///|
/// Report only value-changing overrides, preserving input order.
pub fn overlay_conflicts(fragments : Array[Fragment]) -> Array[OverlayConflict] {
  let seen : Map[String, Value] = Map([])
  let out = []
  for index, fragment in fragments {
    for (name, value) in fragment.entries {
      match seen.get(name) {
        Some(previous) =>
          if previous != value {
            out.push({
              name,
              previous,
              replacement: value,
              fragment_index: index,
            })
          }
        None => ()
      }
      seen[name] = value
    }
  }
  out
}

///|
pub fn Schema::changes(
  self : Schema,
  before : Resolution,
  after : Resolution,
) -> Array[ConfigChange] raise ConfigError {
  self.check_snapshot(before)
  self.check_snapshot(after)
  let out = []
  for name in self.names() {
    let a = before.value(name)
    let b = after.value(name)
    if a != b {
      out.push({ name, before: a, after: b, })
    }
  }
  out
}

///|
fn same_values(
  schema : Schema,
  a : Resolution,
  b : Resolution,
) -> Bool raise ConfigError {
  for name in schema.names() {
    if a.value(name) != b.value(name) {
      return false
    }
  }
  true
}

///|
/// Greedy irredundant fragment, not a globally minimum cardinality solution.
/// Limited to 256 symbols because each candidate requires a full resolution.
pub fn Schema::minimal_fragment(
  self : Schema,
  target : Resolution,
) -> Fragment raise ConfigError {
  self.check_snapshot(target)
  if self.defs.length() > 256 {
    raise Invalid("fragment minimization supports at most 256 symbols")
  }
  let mut candidate = Fragment::new()
  for name in self.names() {
    let value = target.value(name)
    if target.visibility(name) != N && value != Unset {
      self.request(candidate, name, value)
    }
  }
  if !same_values(self, self.resolve(candidate), target) {
    raise Invalid("target cannot be reproduced by visible requests")
  }
  let mut cursor = 0
  while cursor < candidate.entries.length() {
    let reduced = Fragment::new()
    for index, entry in candidate.entries {
      if index != cursor {
        reduced.entries.push(entry)
      }
    }
    if same_values(self, self.resolve(reduced), target) {
      candidate = reduced
    } else {
      cursor += 1
    }
  }
  candidate
}

///|
pub fn Schema::export_fragment(
  self : Schema,
  fragment : Fragment,
) -> String raise ConfigError {
  let out = []
  for (name, value) in fragment.entries {
    let kind = self.kind(name)
    if !kind.accepts(value) {
      raise Invalid("fragment/schema type mismatch")
    }
    out.push(config_line(name, kind, value))
  }
  out.join("")
}

///|
#deprecated
pub extend ConfigChange with @debug.Debug::{to_repr}

///|
#deprecated
pub extend ConfigChange with Eq::{equal, not_equal}

///|
#deprecated
pub extend OverlayConflict with @debug.Debug::{to_repr}

///|
#deprecated
pub extend OverlayConflict with Eq::{equal, not_equal}
