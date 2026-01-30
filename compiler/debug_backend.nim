import json

proc main() =
  let data = stdin.readAll()
  try:
    let j = parseJson(data)
    echo "JSON parsed successfully"
    echo "Packages count: ", j["Packages"].len
  except:
    echo "Error parsing JSON: ", getCurrentExceptionMsg()

main()
