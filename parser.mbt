///|
enum CompareOp {
  Equal
  NotEqual
  Less
  LessOrEqual
  Greater
  GreaterOrEqual
} derive(Debug, Eq)

///|
enum Ast {
  Identity
  Field(String)
  Literal(Json)
  Sequence(Ast, Ast)
  Index(Ast, Int)
  Slice(Ast, Int?, Int?, Int?)
  Flatten(Ast)
  Values(Ast)
  Filter(Ast, Ast)
  Projection(Ast, Ast)
  PipeExpr(Ast, Ast)
  OrExpr(Ast, Ast)
  AndExpr(Ast, Ast)
  NotExpr(Ast)
  Compare(CompareOp, Ast, Ast)
  MultiList(Array[Ast])
  MultiHash(Array[(String, Ast)])
  Function(String, Array[Ast])
  ExpressionRef(Ast)
} derive(Debug, Eq)

///|
priv struct Parser {
  tokens : Array[Token]
  limits : Limits
  mut index : Int
  mut nodes : Int
}

///|
fn Parser::current(self : Parser) -> Token {
  self.tokens[self.index]
}

///|
fn Parser::advance(self : Parser) -> Token {
  let token = self.current()
  if self.index + 1 < self.tokens.length() {
    self.index = self.index + 1
  }
  token
}

///|
fn Parser::add_node(self : Parser, ast : Ast) -> Ast raise JmesError {
  self.nodes = self.nodes + 1
  if self.nodes > self.limits.max_ast_nodes {
    raise JmesError::new(
      LimitExceeded,
      "abstract syntax tree node limit exceeded",
      self.current().offset,
    )
  }
  ast
}

///|
fn Parser::syntax(self : Parser, message : String) -> JmesError {
  JmesError::new(Syntax, message, self.current().offset)
}

///|
fn Parser::expect(self : Parser, expected : TokenKind) -> Unit raise JmesError {
  if self.current().kind == expected {
    ignore(self.advance())
  } else {
    raise self.syntax(
      "expected \{Repr(expected)}, found \{Repr(self.current().kind)}",
    )
  }
}

///|
fn Parser::parse(self : Parser) -> Ast raise JmesError {
  let ast = self.parse_pipe()
  if !(self.current().kind is Eof) {
    raise self.syntax("unexpected token \{Repr(self.current().kind)}")
  }
  ast
}

///|
fn Parser::parse_pipe(self : Parser) -> Ast raise JmesError {
  let mut left = self.parse_or()
  while self.current().kind is Pipe {
    ignore(self.advance())
    left = self.add_node(PipeExpr(left, self.parse_or()))
  }
  left
}

///|
fn Parser::parse_or(self : Parser) -> Ast raise JmesError {
  let mut left = self.parse_and()
  while self.current().kind is Or {
    ignore(self.advance())
    left = self.add_node(OrExpr(left, self.parse_and()))
  }
  left
}

///|
fn Parser::parse_and(self : Parser) -> Ast raise JmesError {
  let mut left = self.parse_comparison()
  while self.current().kind is And {
    ignore(self.advance())
    left = self.add_node(AndExpr(left, self.parse_comparison()))
  }
  left
}

///|
fn Parser::parse_comparison(self : Parser) -> Ast raise JmesError {
  let left = self.parse_unary()
  let operation : CompareOp? = match self.current().kind {
    Eq => Some(Equal)
    Ne => Some(NotEqual)
    Lt => Some(Less)
    Le => Some(LessOrEqual)
    Gt => Some(Greater)
    Ge => Some(GreaterOrEqual)
    _ => None
  }
  match operation {
    None => left
    Some(operation) => {
      ignore(self.advance())
      self.add_node(Compare(operation, left, self.parse_unary()))
    }
  }
}

///|
fn Parser::parse_unary(self : Parser) -> Ast raise JmesError {
  match self.current().kind {
    Not => {
      ignore(self.advance())
      self.add_node(NotExpr(self.parse_unary()))
    }
    Ampersand => {
      ignore(self.advance())
      self.add_node(ExpressionRef(self.parse_unary()))
    }
    _ => self.parse_postfix()
  }
}

///|
fn Parser::attach_projection(
  self : Parser,
  base : Ast,
  suffix : Ast,
) -> Ast raise JmesError {
  match base {
    Projection(source, transform) =>
      self.add_node(
        Projection(source, self.add_node(Sequence(transform, suffix))),
      )
    _ => self.add_node(Sequence(base, suffix))
  }
}

///|
fn Parser::parse_postfix(self : Parser) -> Ast raise JmesError {
  let mut value = self.parse_primary()
  let mut parsing = true
  while parsing {
    match self.current().kind {
      Dot => {
        ignore(self.advance())
        match self.current().kind {
          Identifier(name) | QuotedIdentifier(name) => {
            ignore(self.advance())
            value = self.attach_projection(value, self.add_node(Field(name)))
          }
          Star => {
            ignore(self.advance())
            value = self.add_node(
              Projection(self.add_node(Values(value)), self.add_node(Identity)),
            )
          }
          LBrace => {
            let suffix = self.parse_multi_hash()
            value = self.attach_projection(value, suffix)
          }
          _ =>
            raise self.syntax("expected a field, wildcard, or object after '.'")
        }
      }
      LBracket => value = self.parse_bracket_suffix(value)
      _ => parsing = false
    }
  }
  value
}

///|
fn Parser::parse_primary(self : Parser) -> Ast raise JmesError {
  let token = self.advance()
  match token.kind {
    Identifier(name) =>
      if self.current().kind is LParen {
        self.parse_function(name)
      } else {
        self.add_node(Field(name))
      }
    QuotedIdentifier(name) => self.add_node(Field(name))
    RawString(value) => self.add_node(Literal(Json::string(value)))
    JsonLiteral(value) => self.add_node(Literal(value))
    At => self.add_node(Identity)
    Star =>
      self.add_node(
        Projection(
          self.add_node(Values(self.add_node(Identity))),
          self.add_node(Identity),
        ),
      )
    Not => self.add_node(NotExpr(self.parse_unary()))
    LParen => {
      let value = self.parse_pipe()
      self.expect(RParen)
      value
    }
    LBracket =>
      match self.current().kind {
        Number(_) | Colon | Star | RBracket | Question => {
          self.index = self.index - 1
          self.parse_bracket_suffix(self.add_node(Identity))
        }
        _ => self.parse_multi_list_after_open()
      }
    LBrace => self.parse_multi_hash_after_open()
    _ => raise JmesError::new(Syntax, "expected expression", token.offset)
  }
}

///|
fn Parser::parse_function(self : Parser, name : String) -> Ast raise JmesError {
  self.expect(LParen)
  let arguments : Array[Ast] = []
  if self.current().kind is RParen {
    ignore(self.advance())
    return self.add_node(Function(name, arguments))
  }
  arguments.push(self.parse_pipe())
  while self.current().kind is Comma {
    ignore(self.advance())
    arguments.push(self.parse_pipe())
  }
  self.expect(RParen)
  self.add_node(Function(name, arguments))
}

///|
fn Parser::parse_multi_list_after_open(self : Parser) -> Ast raise JmesError {
  let items : Array[Ast] = []
  if self.current().kind is RBracket {
    raise self.syntax("an empty multi-select list is not allowed")
  }
  items.push(self.parse_pipe())
  while self.current().kind is Comma {
    ignore(self.advance())
    items.push(self.parse_pipe())
  }
  self.expect(RBracket)
  self.add_node(MultiList(items))
}

///|
fn Parser::parse_multi_hash(self : Parser) -> Ast raise JmesError {
  self.expect(LBrace)
  self.parse_multi_hash_after_open()
}

///|
fn Parser::parse_multi_hash_after_open(self : Parser) -> Ast raise JmesError {
  let entries : Array[(String, Ast)] = []
  if self.current().kind is RBrace {
    raise self.syntax("an empty multi-select object is not allowed")
  }
  let mut parsing = true
  while parsing {
    let key = match self.advance().kind {
      Identifier(key) | QuotedIdentifier(key) => key
      _ => raise self.syntax("expected an object key")
    }
    self.expect(Colon)
    entries.push((key, self.parse_pipe()))
    if self.current().kind is Comma {
      ignore(self.advance())
    } else {
      parsing = false
    }
  }
  self.expect(RBrace)
  self.add_node(MultiHash(entries))
}

///|
fn Parser::parse_optional_number(self : Parser) -> Int? {
  match self.current().kind {
    Number(value) => {
      ignore(self.advance())
      Some(value)
    }
    _ => None
  }
}

///|
fn Parser::parse_bracket_suffix(
  self : Parser,
  base : Ast,
) -> Ast raise JmesError {
  self.expect(LBracket)
  match self.current().kind {
    RBracket => {
      ignore(self.advance())
      self.add_node(
        Projection(self.add_node(Flatten(base)), self.add_node(Identity)),
      )
    }
    Star => {
      ignore(self.advance())
      self.expect(RBracket)
      self.add_node(Projection(base, self.add_node(Identity)))
    }
    Question => {
      ignore(self.advance())
      let predicate = self.parse_pipe()
      self.expect(RBracket)
      self.add_node(
        Projection(
          self.add_node(Filter(base, predicate)),
          self.add_node(Identity),
        ),
      )
    }
    Number(index) => {
      ignore(self.advance())
      if self.current().kind is Colon {
        self.parse_slice(base, Some(index))
      } else {
        self.expect(RBracket)
        self.attach_projection(
          base,
          self.add_node(Index(self.add_node(Identity), index)),
        )
      }
    }
    Colon => self.parse_slice(base, None)
    _ =>
      raise self.syntax("expected index, slice, wildcard, flatten, or filter")
  }
}

///|
fn Parser::parse_slice(
  self : Parser,
  base : Ast,
  start : Int?,
) -> Ast raise JmesError {
  self.expect(Colon)
  let stop = self.parse_optional_number()
  let step = if self.current().kind is Colon {
    ignore(self.advance())
    self.parse_optional_number()
  } else {
    None
  }
  self.expect(RBracket)
  self.add_node(
    Projection(
      self.add_node(Slice(base, start, stop, step)),
      self.add_node(Identity),
    ),
  )
}
