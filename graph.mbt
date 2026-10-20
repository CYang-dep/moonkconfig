///|
fn dependency_graph(
  schema : Schema,
) -> Map[String, Array[String]] raise ConfigError {
  let graph : Map[String, Array[String]] = Map([])
  for d in schema.defs {
    graph[d.name] = []
  }
  let count = Ref(0)
  fn edge(from : String, to : String) -> Unit raise ConfigError {
    if !graph.contains(to) {
      return
    }
    let adjacent = graph[from]
    if !adjacent.contains(to) {
      count.val += 1
      if count.val > 65536 {
        raise Invalid("dependency edge budget exceeded")
      }
      adjacent.push(to)
    }
  }
  fn expression(from : String, expr : Expr) -> Unit raise ConfigError {
    for name in expr.references() {
      edge(from, name)
    }
  }
  for d in schema.defs {
    expression(d.name, d.depends)
    expression(d.name, d.prompt_if)
    for (value, cond) in d.defaults {
      expression(d.name, value)
      expression(d.name, cond)
    }
    for (lo, hi, cond) in d.ranges {
      expression(d.name, lo)
      expression(d.name, hi)
      expression(d.name, cond)
    }
    for (target, cond) in d.selects + d.implies {
      edge(target, d.name)
      expression(target, cond)
    }
    if schema.kind(d.name) == Tristate {
      for switch in schema.defs {
        if switch.modules {
          edge(d.name, switch.name)
        }
      }
    }
  }
  graph
}

///|
/// Stable dependency-first ordering. Iterative DFS reports an actual cycle path.
pub fn Schema::dependency_order(
  self : Schema,
) -> Array[String] raise ConfigError {
  self.validate()
  let graph = dependency_graph(self)
  let state : Map[String, Int32] = Map([])
  let result = []
  for root in self.names() {
    if state.get(root).unwrap_or(0) != 0 {
      continue
    }
    let path = [root]
    let cursors = [0]
    state[root] = 1
    while !path.is_empty() {
      let last = path.length() - 1
      let node = path[last]
      let edges = graph[node]
      if cursors[last] == edges.length() {
        ignore(path.pop())
        ignore(cursors.pop())
        state[node] = 2
        result.push(node)
        continue
      }
      let next = edges[cursors[last]]
      cursors[last] += 1
      match state.get(next).unwrap_or(0) {
        0 => {
          state[next] = 1
          path.push(next)
          cursors.push(0)
        }
        1 => {
          let witness : Array[String] = []
          let mut started = false
          for name in path {
            if name == next {
              started = true
            }
            if started {
              witness.push(name)
            }
          }
          witness.push(next)
          raise Invalid("dependency cycle: " + witness.join(" -> "))
        }
        _ => ()
      }
    }
  }
  result
}
