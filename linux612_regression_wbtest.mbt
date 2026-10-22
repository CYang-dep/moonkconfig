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

///|
test "native config import and omission follow olddefconfig" {
  let schema = parse_linux612(
    "Kconfig",
    Map([
      (
        "Kconfig", "config A\n int \"A\"\n default 1\nconfig HIDDEN\n bool\nconfig OTHER\n bool\n default y\n select UNDECLARED\n",
      ),
    ]),
  )
  let (fragment, diagnostics) = schema.read_linux_config(
    "CONFIG_UNKNOWN=y\nCONFIG_A=3\nCONFIG_A=4\nCONFIG_A=invalid\n",
  )
  assert_eq(diagnostics.length(), 3)
  let result = schema.resolve(fragment)
  assert_eq(result.value("A").text(), "4")
  assert_eq(schema.export_linux_config(result), "CONFIG_A=4\nCONFIG_OTHER=y\n")
}

///|
test "native comparisons use lexical strings and unsigned hex" {
  let schema = parse_linux612(
    "Kconfig",
    Map([
      (
        "Kconfig", "config A\n string\n default \"abc\"\nconfig B\n bool \"B\"\n default y if A < \"b\"\nconfig H\n hex\n default 0xffffffffffffffff\nconfig C\n bool \"C\"\n default y if H = -1\n",
      ),
    ]),
  )
  let result = schema.resolve(Fragment::new())
  assert_eq(result.value("B"), Logic(Y))
  assert_eq(result.value("C"), Logic(Y))
}

///|
test "native help dedentation returns to properties and duplicate prompts OR" {
  let schema = parse_linux612(
    "Kconfig",
    Map([
      (
        "Kconfig", "config A\n bool \"First\"\n prompt \"Second\" if n\n help\n        Help paragraph\n  default y\n",
      ),
    ]),
  )
  let result = schema.resolve(Fragment::new())
  assert_eq(result.value("A"), Logic(Y))
  assert_eq(schema.help("A"), "Help paragraph")
  assert_eq(result.visibility("A"), Y)
}

///|
test "native range retains endpoint spelling including inverted bounds" {
  let schema = parse_linux612(
    "Kconfig",
    Map([
      (
        "Kconfig", "config A\n int \"A\"\n range 0x01 0x08\n default 20\nconfig B\n int \"B\"\n range 8 1\n default 4\n",
      ),
    ]),
  )
  let result = schema.resolve(Fragment::new())
  assert_eq(result.value("A").text(), "0x08")
  assert_eq(result.value("B").text(), "8")
}
