///|
test "lexer recognizes identifiers, operators and literals" {
  let tokens = lex("people[?age >= `18`].name || 'unknown'", Limits::default())
  match tokens {
    Ok(tokens) => {
      assert_eq(tokens.length(), 12)
      assert_true(tokens[0].kind is Identifier("people"))
      assert_true(tokens[3].kind is Identifier("age"))
      assert_true(tokens[4].kind is Ge)
      assert_true(tokens[5].kind is JsonLiteral(Json::Number(18.0, ..)))
      assert_true(tokens[9].kind is Or)
      assert_true(tokens[10].kind is RawString("unknown"))
      assert_true(tokens[11].kind is Eof)
    }
    Err(error) => fail("unexpected lexer error: \{error.message}")
  }
}

///|
test "lexer decodes quoted identifiers" {
  match lex("\"first\\nname\"", Limits::default()) {
    Ok(tokens) => assert_true(tokens[0].kind is QuotedIdentifier("first\nname"))
    Err(error) => fail("unexpected lexer error: \{error.message}")
  }
}

///|
test "lexer reports malformed input with an offset" {
  match lex("foo.$", Limits::default()) {
    Err(error) => {
      assert_eq(error.kind, Syntax)
      assert_eq(error.offset, 4)
    }
    Ok(_) => fail("expected lexer error")
  }
}
