///|
// Component-wise globbing: '*' and '?' never consume a slash. The backtracking
// cursor is iterative and bounded by the source/path resource limits.
fn source_component(pattern : String, text : String) -> Bool {
  let mut p = 0
  let mut t = 0
  let mut star = -1
  let mut retry = 0
  while t < text.length() {
    if p < pattern.length() && (pattern[p] == 63 || pattern[p] == text[t]) {
      p += 1
      t += 1
    } else if p < pattern.length() && pattern[p] == 42 {
      star = p
      p += 1
      retry = t
    } else if star >= 0 {
      retry += 1
      t = retry
      p = star + 1
    } else {
      return false
    }
  }
  while p < pattern.length() && pattern[p] == 42 {
    p += 1
  }
  p == pattern.length()
}

///|
fn source_pattern(pattern : String, file : String) -> Bool {
  let parts = pattern.split("/").to_array()
  let names = file.split("/").to_array()
  if parts.length() != names.length() {
    return false
  }
  for i in 0..<parts.length() {
    if names[i].has_prefix(".") && !parts[i].has_prefix(".") {
      return false
    }
    if !source_component(parts[i].to_owned(), names[i].to_owned()) {
      return false
    }
  }
  true
}
