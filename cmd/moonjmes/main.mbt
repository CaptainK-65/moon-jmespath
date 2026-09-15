///|
fn usage() -> String {
  "Usage: moon run cmd/moonjmes -- '<expression>' '<json>'"
}

///|
fn execute(expression : String, source : String) -> String raise {
  let input = @json.parse(source)
  @jmespath.search(expression, input).stringify()
}

///|
fn main raise {
  let arguments = @env.args()
  if arguments.length() != 3 {
    println(usage())
    return
  }
  println(execute(arguments[1], arguments[2]))
}
