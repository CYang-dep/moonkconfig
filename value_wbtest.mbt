///|
test "three valued lattice is ordered and involutive" {
  let ts = [N, M, Y]
  for a in ts {
    assert_eq(a.negate().negate(), a)
    for b in ts {
      assert_eq(a.meet(b), b.meet(a))
      assert_eq(a.join(b), b.join(a))
      assert_eq(a.meet(b).negate(), a.negate().join(b.negate()))
    }
  }
  assert_eq(parse_tri("m"), M)
  assert_eq(Boolean.accepts(Logic(M)), false)
  assert_eq(Hex.accepts(Number(10L)), true)
}
