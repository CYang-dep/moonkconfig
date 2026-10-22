///|
test "native signed prefix range conversion and radix override" {
  assert_eq(linux_range_number("abc", Integer), 0L)
  assert_eq(linux_range_number("12junk", Integer), 12L)
  assert_eq(linux_range_number("  -12junk", Integer), -12L)
  assert_eq(linux_range_number("0x10", Integer), 0L)
  assert_eq(linux_range_number("0x10", Hex), 16L)
  assert_eq(
    linux_range_number("999999999999999999999", Integer),
    9223372036854775807L,
  )
  assert_eq(expand_indent_tabs(" \tHelp\ttext"), "        Help\ttext")
}

///|
test "native choice tolerates nonmember defaults and repeated prompts" {
  let schema = parse_linux612(
    "Kconfig",
    Map([
      (
        "Kconfig", "choice\n prompt \"C\"\n prompt \"Again\"\n default UNKNOWN\nconfig A\n bool \"A\"\nendchoice\n",
      ),
    ]),
  )
  assert_eq(schema.resolve(Fragment::new()).value("A"), Logic(Y))
}
