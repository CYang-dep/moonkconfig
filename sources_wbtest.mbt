///|
test "in memory includes resolve paths preserve provenance and continuations" {
  let files : Map[String, String] = {
    "Kconfig": "source \"sub/Kconfig\"\nosource \"absent\"\n",
    "sub/Kconfig": "rsource \"opts\"",
    "sub/opts": "config A\n def_bool y && \\\n y",
  }
  let s = parse_sources("Kconfig", files)
  assert_eq(s.names(), ["A"])
  assert_eq(s.source_location("A"), "sub/opts:1")
}

///|
test "cyclic missing traversal and macro includes fail" {
  for path in ["../outside", "/etc/x", "$(VAR)", "*.cfg"] {
    let failed = try {
      ignore(parse_sources(path, {}))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  let cyclic : Map[String, String] = { "Kconfig": "source \"Kconfig\"" }
  let failed = try {
    ignore(parse_sources("Kconfig", cyclic))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
