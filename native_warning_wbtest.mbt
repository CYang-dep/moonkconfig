///|
test "native warnings preserve input acceptance and scalar values" {
  let schema = parse_linux612(
    "Kconfig",
    Map([
      (
        "Kconfig", "config A\n int \"A\"\n default 5\n select B\nconfig B\n bool \"B\"\nconfig S\n string \"S\"\n range 1 3\n default \"abc\"\n",
      ),
    ]),
  )
  let (fragment, messages) = schema.read_linux_config(
    " CONFIG_A=7\nCONFIG_UNKNOWN=y\nCONFIG_A=6\n",
  )
  assert_eq(messages.length(), 2)
  let result = schema.resolve(fragment)
  assert_eq(result.value("A").text(), "6")
  assert_eq(result.value("S"), Text("abc"))
}

///|
test "native repeated modules directive is rejected before declaration merge" {
  assert_true(
    try {
      ignore(
        parse_linux612(
          "Kconfig",
          Map([
            (
              "Kconfig", "config A\n bool\n modules\nconfig A\n bool\n modules\n",
            ),
          ]),
        ),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
test "native help accepts same indentation as the help keyword and punctuation" {
  let schema = parse_linux612(
    "Kconfig",
    Map([
      (
        "Kconfig", "config A\n\tbool \"A\"\n\thelp\n\tThis driver's punctuation isn't syntax.\n\tMore text.\nconfig B\n bool\n default y\n",
      ),
    ]),
  )
  assert_true(schema.help("A").contains("isn't syntax"))
  assert_eq(schema.resolve(Fragment::new()).value("B"), Logic(Y))
}
