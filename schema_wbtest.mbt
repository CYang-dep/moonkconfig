///|
test "typed schema builder rejects inconsistent symbols" {
  let s = Schema::new()
  s.add("NET", Boolean, prompt="Network")
  s.add("DRIVER", Tristate)
  s.dependency("DRIVER", SymbolRef("NET"))
  s.default_value("NET", Constant(Logic(Y)))
  s.reverse_dependency("DRIVER", "NET")
  s.validate()
  assert_eq(s.names(), ["NET", "DRIVER"])
  assert_eq(s.kind("DRIVER"), Tristate)
  let failed = try {
    s.add("NET", Integer)
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
