///|
test "UI snapshots expose help origins constraints and feasible request transitions" {
  let s = parse_kconfig(
    "config FORCE\n bool\n default y\n select A\nconfig A\n bool \"A\"\n help\n   User facing help\nconfig NUMBER\n int \"Number\"\n range 1 4\n default 2",
  )
  let result = s.resolve(Fragment::new())
  let rows = s.inspect(result)
  assert_eq(rows[1].help, "User facing help")
  assert_eq(rows[1].dependencies, ["FORCE"])
  rows[1].dependencies.push("MUTATION")
  assert_eq(s.inspect(result)[1].dependencies, ["FORCE"])
  assert_eq(rows[2].numeric_range, Some((1L, 4L)))
  assert_eq(s.request_options(Fragment::new(), "A"), [Logic(Y)])
  assert_eq(s.request_options(Fragment::new(), "FORCE"), [])
}

///|
test "last request and last overlay order govern choice selection" {
  let s = parse_kconfig(
    "choice\n bool \"Pick\"\nconfig A\n bool \"A\"\nconfig B\n bool \"B\"\nendchoice",
  )
  let fragment = s.parse_config("CONFIG_A=y\nCONFIG_B=y")
  s.request(fragment, "A", Logic(Y))
  assert_eq(s.resolve(fragment).value("A"), Logic(Y))
  let overlay = s.parse_config("CONFIG_B=y")
  assert_eq(
    s.resolve(merge_fragments([fragment, overlay])).value("B"),
    Logic(Y),
  )
  assert_eq(s.request_options(fragment, "B"), [Logic(N), Logic(Y)])
}
