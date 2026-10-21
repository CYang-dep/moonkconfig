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
