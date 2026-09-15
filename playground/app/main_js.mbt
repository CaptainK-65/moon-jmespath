///|
extern "js" fn install_playground(run : (String, String) -> String) -> Unit =
  #|function(run) {
  #|  globalThis.MoonJMES = Object.freeze({ run });
  #|  if (typeof globalThis.dispatchEvent === "function" && typeof globalThis.CustomEvent === "function") {
  #|    globalThis.dispatchEvent(new CustomEvent("moonjmes:ready"));
  #|  }
  #|}

///|
fn main {
  install_playground(@model.run)
}
