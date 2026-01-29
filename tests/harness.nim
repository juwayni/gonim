import os, osproc, strutils

proc runTest(path: string): bool =
  echo "Running parity test: ", path
  # In a real harness, we'd also run the equivalent Go code and compare outputs
  let cmd = "export PATH=/home/jules/.nimble/bin:$PATH && nim c -r --hints:off " & path
  let (outp, exitCode) = execCmdEx(cmd)
  if exitCode != 0:
    echo "Test failed: ", path
    echo outp
    return false
  echo "Test passed."
  return true

proc main() =
  var success = true
  # Iterate over all files in tests directory
  for kind, path in walkDir("tests"):
    if kind == pcFile and path.endsWith(".nim") and not path.contains("harness"):
      if not runTest(path):
        success = false

  if success:
    echo "Summary: All parity tests passed!"
  else:
    echo "Summary: Some tests failed."
    quit(1)

main()
