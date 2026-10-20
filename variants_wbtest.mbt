///|
test "variant deltas include transitive changes and minimized requests reproduce target" {
  let s = parse_kconfig(
    "config A\n bool \"A\"\n default n\nconfig B\n bool \"B\"\n depends on A\n default y\nconfig C\n string \"C\"\n default \"same\"",
  )
  let base = s.resolve(Fragment::new())
  let target = s.resolve(
    s.parse_config("CONFIG_A=y\nCONFIG_B=y\nCONFIG_C=\"same\""),
  )
  assert_eq(s.changes(base, target).map(fn(c) { c.name }), ["A", "B"])
  let reduced = s.minimal_fragment(target)
  assert_eq(s.export_fragment(reduced), "CONFIG_A=y\n")
  assert_true(same_values(s, s.resolve(reduced), target))
}

///|
test "overlay audit reports changed requests not identical reassignment" {
  let s = parse_kconfig("config A\n bool \"A\"")
  let a = s.parse_config("CONFIG_A=y")
  let b = s.parse_config("# CONFIG_A is not set")
  let conflicts = overlay_conflicts([a, a, b])
  assert_eq(conflicts.length(), 1)
  assert_eq(conflicts[0].fragment_index, 2)
  assert_eq(conflicts[0].previous, Logic(Y))
  assert_eq(conflicts[0].replacement, Logic(N))
}
