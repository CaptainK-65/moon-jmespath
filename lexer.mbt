///|
enum TokenKind {
  Identifier(String)
  QuotedIdentifier(String)
  RawString(String)
  JsonLiteral(Json)
  Number(Int)
  Dot
  Star
  LBracket
  RBracket
  LBrace
  RBrace
  LParen
  RParen
  Comma
  Colon
  At
  Pipe
  Or
  And
  Not
  Eq
  Ne
  Lt
  Le
  Gt
  Ge
  Question
  Ampersand
  Eof
} derive(Debug, Eq)

///|
struct Token {
  kind : TokenKind
  offset : Int
} derive(Debug, Eq)

///|
fn is_whitespace(c : UInt16) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
fn is_identifier_start(c : UInt16) -> Bool {
  c == '_' || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

///|
fn is_identifier_continue(c : UInt16) -> Bool {
  is_identifier_start(c) || (c >= '0' && c <= '9')
}

///|
fn slice_string(source : String, start : Int, end : Int) -> String {
  source[start:end].to_owned()
}

///|
fn lex_quoted_identifier(
  source : String,
  start : Int,
) -> Result[(Token, Int), JmesError] {
  let length = source.length()
  let mut i = start + 1
  while i < length {
    if source[i] == '\\' {
      i = i + 2
      continue
    }
    if source[i] == '"' {
      let encoded = slice_string(source, start, i + 1)
      if !@json.valid(encoded) {
        return Err(
          JmesError::new(Syntax, "invalid escape in quoted identifier", start),
        )
      }
      match (try! @json.parse(encoded)) {
        Json::String(value) =>
          return Ok(({ kind: QuotedIdentifier(value), offset: start, }, i + 1))
        _ =>
          return Err(
            JmesError::new(Syntax, "quoted identifier must be a string", start),
          )
      }
    }
    i = i + 1
  }
  Err(JmesError::new(Syntax, "unterminated quoted identifier", start))
}

///|
fn lex_raw_string(
  source : String,
  start : Int,
) -> Result[(Token, Int), JmesError] {
  let length = source.length()
  let mut i = start + 1
  while i < length {
    if source[i] == '\'' {
      let raw = slice_string(source, start + 1, i)
      let value = raw.replace_all(old="\\'", new="'")
      return Ok(({ kind: RawString(value), offset: start, }, i + 1))
    }
    if source[i] == '\\' && i + 1 < length && source[i + 1] == '\'' {
      i = i + 2
      continue
    }
    i = i + 1
  }
  Err(JmesError::new(Syntax, "unterminated raw string", start))
}

///|
fn lex_json_literal(
  source : String,
  start : Int,
) -> Result[(Token, Int), JmesError] {
  let length = source.length()
  let mut i = start + 1
  while i < length {
    if source[i] == '`' {
      let encoded = slice_string(source, start + 1, i)
      let text = encoded.replace_all(old="\\`", new="`")
      if !@json.valid(text) {
        return Err(JmesError::new(Syntax, "invalid JSON literal", start))
      }
      let value = try! @json.parse(text)
      return Ok(({ kind: JsonLiteral(value), offset: start, }, i + 1))
    }
    if source[i] == '\\' && i + 1 < length && source[i + 1] == '`' {
      i = i + 2
      continue
    }
    i = i + 1
  }
  Err(JmesError::new(Syntax, "unterminated JSON literal", start))
}

///|
fn parse_index(source : String, start : Int, end : Int) -> Int? {
  let negative = source[start] == '-'
  let digit_start = if negative { start + 1 } else { start }
  let mut value = 0
  for i in digit_start..<end {
    let digit = source[i].to_int() - ('0' : UInt16).to_int()
    if value > 100000000 {
      return None
    }
    value = value * 10 + digit
  }
  Some(if negative { -value } else { value })
}

///|
fn lex(source : String, limits : Limits) -> Result[Array[Token], JmesError] {
  if source.length() > limits.max_expression_length {
    return Err(
      JmesError::new(LimitExceeded, "expression length limit exceeded", 0),
    )
  }
  let tokens : Array[Token] = []
  let length = source.length()
  let mut i = 0
  while i < length {
    let c = source[i]
    if is_whitespace(c) {
      i = i + 1
      continue
    }
    if is_identifier_start(c) {
      let start = i
      i = i + 1
      while i < length && is_identifier_continue(source[i]) {
        i = i + 1
      }
      tokens.push({
        kind: Identifier(slice_string(source, start, i)),
        offset: start,
      })
      continue
    }
    if c == '-' || (c >= '0' && c <= '9') {
      let start = i
      if c == '-' {
        i = i + 1
      }
      let digit_start = i
      while i < length && source[i] >= '0' && source[i] <= '9' {
        i = i + 1
      }
      if i == digit_start {
        return Err(JmesError::new(Syntax, "expected integer index", start))
      }
      match parse_index(source, start, i) {
        Some(value) => tokens.push({ kind: Number(value), offset: start, })
        None =>
          return Err(
            JmesError::new(Syntax, "integer index is too large", start),
          )
      }
      continue
    }
    if c == '"' {
      match lex_quoted_identifier(source, i) {
        Ok((token, next)) => {
          tokens.push(token)
          i = next
          continue
        }
        Err(error) => return Err(error)
      }
    }
    if c == '\'' {
      match lex_raw_string(source, i) {
        Ok((token, next)) => {
          tokens.push(token)
          i = next
          continue
        }
        Err(error) => return Err(error)
      }
    }
    if c == '`' {
      match lex_json_literal(source, i) {
        Ok((token, next)) => {
          tokens.push(token)
          i = next
          continue
        }
        Err(error) => return Err(error)
      }
    }
    let token : TokenKind? = match c {
      '.' => Some(Dot)
      '*' => Some(Star)
      '[' => Some(LBracket)
      ']' => Some(RBracket)
      '{' => Some(LBrace)
      '}' => Some(RBrace)
      '(' => Some(LParen)
      ')' => Some(RParen)
      ',' => Some(Comma)
      ':' => Some(Colon)
      '@' => Some(At)
      '?' => Some(Question)
      _ => None
    }
    match token {
      Some(kind) => {
        tokens.push({ kind, offset: i, })
        i = i + 1
        continue
      }
      None => ()
    }
    let two = if i + 1 < length { Some((c, source[i + 1])) } else { None }
    match two {
      Some(('|', '|')) => {
        tokens.push({ kind: Or, offset: i, })
        i = i + 2
      }
      Some(('&', '&')) => {
        tokens.push({ kind: And, offset: i, })
        i = i + 2
      }
      Some(('=', '=')) => {
        tokens.push({ kind: Eq, offset: i, })
        i = i + 2
      }
      Some(('!', '=')) => {
        tokens.push({ kind: Ne, offset: i, })
        i = i + 2
      }
      Some(('<', '=')) => {
        tokens.push({ kind: Le, offset: i, })
        i = i + 2
      }
      Some(('>', '=')) => {
        tokens.push({ kind: Ge, offset: i, })
        i = i + 2
      }
      _ =>
        match c {
          '|' => {
            tokens.push({ kind: Pipe, offset: i, })
            i = i + 1
          }
          '&' => {
            tokens.push({ kind: Ampersand, offset: i, })
            i = i + 1
          }
          '!' => {
            tokens.push({ kind: Not, offset: i, })
            i = i + 1
          }
          '<' => {
            tokens.push({ kind: Lt, offset: i, })
            i = i + 1
          }
          '>' => {
            tokens.push({ kind: Gt, offset: i, })
            i = i + 1
          }
          _ =>
            return Err(
              JmesError::new(Syntax, "unexpected character at offset \{i}", i),
            )
        }
    }
  }
  tokens.push({ kind: Eof, offset: length, })
  Ok(tokens)
}
