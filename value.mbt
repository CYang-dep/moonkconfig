///|
pub suberror ConfigError {
  Invalid(String)
} derive(Debug)

///|
/// The ordered Kconfig lattice: n < m < y.
pub(all) enum Tri {
  N
  M
  Y
} derive(Eq, Debug)

///|
pub fn Tri::rank(self : Tri) -> Int32 {
  match self {
    N => 0
    M => 1
    Y => 2
  }
}

///|
pub fn Tri::negate(self : Tri) -> Tri {
  match self {
    N => Y
    M => M
    Y => N
  }
}

///|
pub fn Tri::meet(self : Tri, other : Tri) -> Tri {
  if self.rank() < other.rank() {
    self
  } else {
    other
  }
}

///|
pub fn Tri::join(self : Tri, other : Tri) -> Tri {
  if self.rank() > other.rank() {
    self
  } else {
    other
  }
}

///|
pub fn Tri::text(self : Tri) -> String {
  match self {
    N => "n"
    M => "m"
    Y => "y"
  }
}

///|
pub fn parse_tri(text : String) -> Tri raise ConfigError {
  match text {
    "n" => N
    "m" => M
    "y" => Y
    _ => raise Invalid("expected n, m or y: " + text)
  }
}

///|
pub(all) enum Value {
  Unset
  Logic(Tri)
  Text(String)
  Number(Int64)
  /// Source spelling and declared numeric type in the Linux v6.12 profile.
  RawNumber(String, Kind)
} derive(Eq, Debug)

///|
pub fn Value::text(self : Value) -> String {
  match self {
    Unset => ""
    Logic(t) => t.text()
    Text(s) => s
    Number(n) => n.to_string()
    RawNumber(raw, _) => raw
  }
}

///|
pub fn Value::logic(self : Value) -> Tri {
  match self {
    Logic(t) => t
    _ => N
  }
}

///|
pub(all) enum Kind {
  Boolean
  Tristate
  StringType
  Integer
  Hex
} derive(Eq, Debug)

///|
pub fn Kind::initial(self : Kind) -> Value {
  match self {
    Boolean | Tristate => Logic(N)
    StringType => Text("")
    Integer | Hex => Unset
  }
}

///|
pub fn Kind::accepts(self : Kind, value : Value) -> Bool {
  match (self, value) {
    (Boolean, Logic(M)) => false
    (Boolean | Tristate, Logic(_)) => true
    (StringType, Text(_)) => true
    (Integer | Hex, Number(_)) => true
    (Integer, RawNumber(raw, Integer)) => valid_linux_number(raw, Integer)
    (Hex, RawNumber(raw, Hex)) => valid_linux_number(raw, Hex)
    _ => false
  }
}

///|
#deprecated
pub extend ConfigError with @debug.Debug::{to_repr}

///|
#deprecated
pub extend Tri with @debug.Debug::{to_repr}

///|
#deprecated
pub extend Tri with Eq::{equal, not_equal}

///|
#deprecated
pub extend Value with @debug.Debug::{to_repr}

///|
#deprecated
pub extend Value with Eq::{equal, not_equal}

///|
#deprecated
pub extend Kind with @debug.Debug::{to_repr}

///|
#deprecated
pub extend Kind with Eq::{equal, not_equal}
