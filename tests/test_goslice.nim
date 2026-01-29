import ../runtime/goslice

proc main() =
  var s: GoSlice[int]
  assert s.isNil()
  assert s.len == 0
  assert s.cap == 0

  s = s.append([1, 2, 3])
  assert s.len == 3
  assert s.cap >= 3
  assert s[0] == 1
  assert s[1] == 2
  assert s[2] == 3

  let s2 = s.slice(1, 3)
  assert s2.len == 2
  assert s2.cap == s.cap - 1
  assert s2[0] == 2
  assert s2[1] == 3

  # Aliasing check
  s[1] = 10
  assert s2[0] == 10

  try:
    discard s[5]
    assert false, "Should have raised IndexDefect"
  except IndexDefect:
    discard

  echo "GoSlice tests passed!"

main()
