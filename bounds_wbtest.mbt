///|
test "untrusted controls macros oversized expressions and quoted directives fail" {
  for
    text in [
      "config A\n string\n default \"$(shell,echo bad)\"", "\"config\" A\n bool",
      "config A\n string\n default \"bad\u0000text\"",
    ] {
    let failed = try {
      ignore(parse_kconfig(text))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  let expression = Array::make(130, "A").join(" && ")
  let failed = try {
    ignore(parse_expression(expression))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  let schema = Schema::new()
  schema.add("A", Boolean)
  let mut deep = truth()
  for _ in 0..<130 {
    deep = Negation(deep)
  }
  schema.dependency("A", deep)
  let failed = try {
    ignore(schema.resolve(Fragment::new()))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "export rejects line injection through builder string requests" {
  let schema = Schema::new()
  schema.add("TEXT", StringType, prompt="Text")
  let failed = try {
    schema.request(Fragment::new(), "TEXT", Text("hello\nCONFIG_EVIL=y"))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  let sources = {
    "Kconfig": "config A\n bool\n ---help---\n   source \"must not be loaded\"",
  }
  assert_true(parse_sources("Kconfig", sources).help("A").contains("source"))
}
