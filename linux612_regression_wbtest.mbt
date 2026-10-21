///|
test "choice help and comment dependencies keep sibling declarations" {
  let schema = parse_kconfig(
    "choice\n prompt \"Mode\"\n help\n   Select one.\nconfig MODE-A\n bool \"A\"\nconfig MODE_B\n bool \"B\"\nendchoice\ncomment \"Hidden caption\"\n depends on n\nconfig AFTER\n bool \"After\"\n default y\n",
  )
  let result = schema.resolve(Fragment::new())
  assert_eq(result.value("MODE-A"), Logic(Y))
  assert_eq(result.value("AFTER"), Logic(Y))
}

///|
test "dollar variable name is accepted by the preprocessor" {
  let schema = parse_kconfig(
    "$ :=1\nconfig VALUE\n string\n default \"$($)\"\n",
  )
  assert_eq(schema.resolve(Fragment::new()).value("VALUE"), Text("1"))
}

///|
test "Linux v6.12 preserves numeric spelling and clamps requested ranges" {
  let schema = parse_linux612(
    "Kconfig",
    Map([
      (
        "Kconfig", "config N\n int \"N\"\n range 1 8\n default 20\nconfig H\n hex \"H\"\n default 0X000F\nconfig BIG\n int\n default 99999999999999999999999999999\n",
      ),
    ]),
  )
  let result = schema.resolve(
    schema.parse_config("CONFIG_N=-10\nCONFIG_H=0X00Ab\n"),
  )
  assert_eq(result.value("N").text(), "1")
  assert_eq(result.value("H").text(), "0X00Ab")
  assert_eq(result.value("BIG").text(), "99999999999999999999999999999")
  assert_true(schema.export_config(result).contains("CONFIG_H=0X00Ab"))
}

///|
test "Linux v6.12 imply respects the target dependency" {
  let schema = parse_linux612(
    "Kconfig",
    Map([
      (
        "Kconfig", "config MODULES\n bool\n modules\n default y\nconfig A\n tristate\n default y\n imply B\nconfig B\n tristate\n depends on m\n",
      ),
    ]),
  )
  assert_eq(schema.resolve(Fragment::new()).value("B"), Logic(M))
}
