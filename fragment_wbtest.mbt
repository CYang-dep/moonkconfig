///|
test "strict typed config fragments merge without aliasing" {
  let s = parse_kconfig(
    "config B\n bool \"B\"\nconfig T\n tristate \"T\"\nconfig S\n string \"S\"\nconfig I\n int \"I\"\nconfig H\n hex \"H\"",
  )
  let base = s.parse_config(
    "CONFIG_B=y\nCONFIG_T=m\nCONFIG_S=\"a=b#c\"\nCONFIG_I=-12\nCONFIG_H=0xff\n",
  )
  assert_eq(base.values().get("S"), Some(Text("a=b#c")))
  let overlay = s.parse_config("# CONFIG_B is not set\n")
  let merged = merge_fragments([base, overlay])
  assert_eq(merged.values().get("B"), Some(Logic(N)))
  assert_eq(base.values().get("B"), Some(Logic(Y)))
  let copy = merged.values()
  copy["B"] = Logic(Y)
  assert_eq(merged.values().get("B"), Some(Logic(N)))
}

///|
test "unknown duplicate and ill typed config values are rejected" {
  let s = parse_kconfig("config B\n bool\nconfig S\n string")
  for
    text in [
      "CONFIG_X=y", "CONFIG_B=m", "CONFIG_B=y\nCONFIG_B=n", "CONFIG_S=bare", "# CONFIG_S is not set",
    ] {
    let failed = try {
      ignore(s.parse_config(text))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}
