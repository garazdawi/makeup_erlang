defmodule ErlangLexerTokenizer do
  use ExUnit.Case, async: false
  import Makeup.Lexers.ErlangLexer.Testing, only: [lex: 1]

  test "empty string" do
    assert lex("") == []
  end

  test "whitespace" do
    assert lex(" ") == [{:whitespace, %{}, " "}]
    assert lex("\n") == [{:whitespace, %{}, "\n"}]
    assert lex("\t") == [{:whitespace, %{}, "\t"}]
    assert lex("\f") == [{:whitespace, %{}, "\f"}]
    assert lex("\s") == [{:whitespace, %{}, "\s"}]
  end

  test "character" do
    assert lex("$a") == [{:string_char, %{}, "$a"}]
    assert lex("$\\ ") == [{:string_char, %{}, "$\\ "}]
    assert lex("$🫂") == [{:string_char, %{}, "$🫂"}]
  end

  test "comment" do
    assert lex("%abc") == [{:comment_single, %{}, "%abc"}]
    assert lex("% abc") == [{:comment_single, %{}, "% abc"}]

    assert lex("% abc\n") == [
             {:comment_single, %{}, "% abc"},
             {:whitespace, %{}, "\n"}
           ]

    assert lex("% abc\n123") == [
             {:comment_single, %{}, "% abc"},
             {:whitespace, %{}, "\n"},
             {:number_integer, %{}, "123"}
           ]
  end

  test "namespace" do
    assert lex("mod:") == [
             {:name_class, %{}, "mod"},
             {:punctuation, %{}, ":"}
           ]
  end

  test "variable" do
    assert lex("A") == [{:name, %{}, "A"}]
    assert lex("A1") == [{:name, %{}, "A1"}]
    assert lex("Ab1") == [{:name, %{}, "Ab1"}]
    assert lex("A_b1") == [{:name, %{}, "A_b1"}]
  end

  test "function call" do
    assert lex("f(") == [
             {:name_function, %{}, "f"},
             {:punctuation, %{group_id: "group-1"}, "("}
           ]

    assert lex("f(1)") == [
             {:name_function, %{}, "f"},
             {:punctuation, %{group_id: "group-1"}, "("},
             {:number_integer, %{}, "1"},
             {:punctuation, %{group_id: "group-1"}, ")"}
           ]
  end

  test "qualified function call" do
    assert lex("mod:f(1)") == [
             {:name_class, %{}, "mod"},
             {:punctuation, %{}, ":"},
             {:name_function, %{}, "f"},
             {:punctuation, %{group_id: "group-1"}, "("},
             {:number_integer, %{}, "1"},
             {:punctuation, %{group_id: "group-1"}, ")"}
           ]
  end

  describe "numbers" do
    test "integers in base 10" do
      assert lex("123") == [{:number_integer, %{}, "123"}]
    end

    test "integers in weird bases" do
      assert lex("14#34") == [{:number_integer, %{}, "14#34"}]
    end

    test "floating point numbers (normal)" do
      assert lex("1.0") == [{:number_float, %{}, "1.0"}]
      assert lex("12.45") == [{:number_float, %{}, "12.45"}]
    end

    test "floating point numbers (scientific notation)" do
      assert lex("1.05e6") == [{:number_float, %{}, "1.05e6"}]
      assert lex("1.05e12") == [{:number_float, %{}, "1.05e12"}]
      assert lex("1.05e-6") == [{:number_float, %{}, "1.05e-6"}]
      assert lex("1.05e-12") == [{:number_float, %{}, "1.05e-12"}]
    end
  end

  describe "charlists" do
    test "tokenize charlist as strings" do
      assert lex(~s/"charlist"/) == [{:string, %{}, ~s/"charlist"/}]
      assert lex(~s/"long char list"/) == [{:string, %{}, ~s/"long char list"/}]
      assert lex(~s/"multi \n line charlist"/) == [{:string, %{}, ~s/"multi \n line charlist"/}]
    end

    test "do not tokenize variables inside charlists" do
      refute {:name, %{}, "Variable"} in lex(~s/"char False_variable list"/)
      refute {:name, %{}, "Variable"} in lex(~s/"FalseVariable"/)
    end

    test "do not tokenize operators inside charlists" do
      refute {:operator_word, %{}, "div"} in lex(~s/"div"/)
      refute {:operator_word, %{}, "div"} in lex(~s/"char div list"/)
    end

    test "tokenizes the interpolation inside a charlist" do
      assert {:string_interpol, %{}, "~p"} in lex(~s/"~p"/)
      assert {:string_interpol, %{}, "~p"} in lex(~s/"some text ~p"/)
      assert {:string_interpol, %{}, "~p"} in lex(~s/"multi line \n text ~p"/)
    end

    test "tokenizes escape of double quotes correctly" do
      assert [{:string, %{}, ~s/"escape \\"double quote\\""/}] ==
               lex(~s/"escape \\"double quote\\""/)

      assert [{:string, %{}, ~s/"\\"quote\\""/}] == lex(~s/"\\"quote\\""/)
      assert {:string, %{}, ~s/"invalid string\\"/} not in lex(~s/"invalid string\\"/)
    end

    test "tokenizes literal escaped characters correctly" do
      assert [{:string, %{}, ~s/"\\b"/}] == lex(~s/"\\b"/)
      assert [{:string, %{}, ~s/"\\\\b"/}] == lex(~s/"\\\\b"/)
    end
  end

  describe "binary" do
    test "<<>> syntax" do
      assert lex(~s/<<>>/) == [
               {:punctuation, %{group_id: "group-1"}, "<<"},
               {:punctuation, %{group_id: "group-1"}, ">>"}
             ]
    end

    test "<<\"\">> syntax" do
      assert lex(~s/<<"">>/) == [
               {:punctuation, %{group_id: "group-1"}, "<<"},
               {:string, %{}, ~s/""/},
               {:punctuation, %{group_id: "group-1"}, ">>"}
             ]
    end

    test "<<\"string\">> syntax" do
      assert lex(~s/<<"string">>/) == [
               {:punctuation, %{group_id: "group-1"}, "<<"},
               {:string, %{}, ~s/"string"/},
               {:punctuation, %{group_id: "group-1"}, ">>"}
             ]
    end
  end

  describe "triple quoted strings" do
    test "triple quotes" do
      assert lex(~s/"""\nabc\n"""/) == [{:string, %{}, ~s/"""\nabc\n"""/}]
      assert lex(~s/"""\na""bc\n"""/) == [{:string, %{}, ~s/"""\na""bc\n"""/}]

      assert lex(~s/"""\na\\"""bc\n"""/) == [
               {:string, %{}, ~s/"""\na/},
               {:string_escape, %{}, ~s/\\"/},
               {:string, %{}, ~s/""bc\n"""/}
             ]
    end
  end

  @sigil_delimiters [
    {~s["""\n], ~s[\n"""]},
    {"'''\n", "\n'''"},
    {"\"", "\""},
    {"'", "'"},
    {"/", "/"},
    {"{", "}"},
    {"[", "]"},
    {"(", ")"},
    {"<", ">"},
    {"|", "|"},
    {"#", "#"},
    {"`", "`"}
  ]

  describe "sigils" do
    test "sigils with escape" do
      for b <- ["b", "s", ""] do
        for {llim, rlim} <- @sigil_delimiters do
          assert lex(~s/~#{b}#{llim}abc#{rlim}/) == [{:string, %{}, ~s/~#{b}#{llim}abc#{rlim}/}]

          assert lex(~s/~#{b}#{llim}~p#{rlim}/) == [
                   {:string, %{}, ~s/~#{b}#{llim}/},
                   {:string_interpol, %{}, "~p"},
                   {:string, %{}, ~s/#{rlim}/}
                 ]

          if String.length(llim) == 1 do
            assert lex(~s/~#{b}#{llim}a\\#{rlim}bc#{rlim}/) ==
                     [
                       {:string, %{}, ~s/~#{b}#{llim}a/},
                       {:string_escape, %{}, ~s/\\#{rlim}/},
                       {:string, %{}, ~s/bc#{rlim}/}
                     ]
          end
        end
      end
    end

    test "sigils without escape" do
      for b <- ["B", "S"] do
        for {llim, rlim} <- @sigil_delimiters do
          assert lex(~s/~#{b}#{llim}abc#{rlim}/) == [{:string, %{}, ~s/~#{b}#{llim}abc#{rlim}/}]

          assert lex(~s/~#{b}#{llim}~p#{rlim}/) == [
                   {:string, %{}, ~s/~#{b}#{llim}/},
                   {:string_interpol, %{}, "~p"},
                   {:string, %{}, ~s/#{rlim}/}
                 ]

          if String.length(llim) == 1 do
            match = {:string, %{}, ~s/~#{b}#{llim}a\\#{rlim}/}
            assert [^match | _] = lex(~s/~#{b}#{llim}a\\#{rlim}bc#{rlim}/)
          end
        end
      end
    end
  end

  describe "comprehensions" do
    test "list" do
      assert lex("[A||A<-B]") == [
               {:punctuation, %{group_id: "group-1"}, "["},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<-"},
               {:name, %{}, "B"},
               {:punctuation, %{group_id: "group-1"}, "]"}
             ]

      assert lex("[A||A<-B,true]") ==
               [
                 {:punctuation, %{group_id: "group-1"}, "["},
                 {:name, %{}, "A"},
                 {:punctuation, %{}, "||"},
                 {:name, %{}, "A"},
                 {:operator, %{}, "<-"},
                 {:name, %{}, "B"},
                 {:punctuation, %{}, ","},
                 {:string_symbol, %{}, "true"},
                 {:punctuation, %{group_id: "group-1"}, "]"}
               ]
    end

    test "binary" do
      assert lex("[A||A<=B]") == [
               {:punctuation, %{group_id: "group-1"}, "["},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<="},
               {:name, %{}, "B"},
               {:punctuation, %{group_id: "group-1"}, "]"}
             ]

      assert lex("<<A||A<=B,true>>") == [
               {:punctuation, %{group_id: "group-1"}, "<<"},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<="},
               {:name, %{}, "B"},
               {:punctuation, %{}, ","},
               {:string_symbol, %{}, "true"},
               {:punctuation, %{group_id: "group-1"}, ">>"}
             ]
    end

    test "strict" do
      assert lex("[A||A<:-B]") == [
               {:punctuation, %{group_id: "group-1"}, "["},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<:-"},
               {:name, %{}, "B"},
               {:punctuation, %{group_id: "group-1"}, "]"}
             ]

      assert lex("[A||A<:=B]") == [
               {:punctuation, %{group_id: "group-1"}, "["},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<:="},
               {:name, %{}, "B"},
               {:punctuation, %{group_id: "group-1"}, "]"}
             ]
    end

    test "parallel" do
      assert lex("[A||A<-B&&C<-D]") == [
               {:punctuation, %{group_id: "group-1"}, "["},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<-"},
               {:name, %{}, "B"},
               {:punctuation, %{}, "&&"},
               {:name, %{}, "C"},
               {:operator, %{}, "<-"},
               {:name, %{}, "D"},
               {:punctuation, %{group_id: "group-1"}, "]"}
             ]
    end
  end

  describe "atoms" do
    test "are tokenized as such" do
      assert lex("atom") == [{:string_symbol, %{}, "atom"}]
      assert lex("at_om") == [{:string_symbol, %{}, "at_om"}]
      assert lex("atom@atom") == [{:string_symbol, %{}, "atom@atom"}]
    end

    test "are tokenized as such even when quoted" do
      assert lex("'atom'") == [{:string_symbol, %{}, "'atom'"}]
      assert lex("'atom atom'") == [{:string_symbol, %{}, "'atom atom'"}]
      assert lex("'atom+atom'") == [{:string_symbol, %{}, "'atom+atom'"}]
      assert lex("'atom@atom'") == [{:string_symbol, %{}, "'atom@atom'"}]
      assert lex("'atom123atom'") == [{:string_symbol, %{}, "'atom123atom'"}]
    end

    test "are tokenized when quoted and have escaped characters" do
      assert [{:string_symbol, %{}, ~s/'\\'escaped\\' quoted atom'/}] ==
               lex(~s/'\\'escaped\\' quoted atom'/)

      assert [{:string_symbol, %{}, ~s/'escaped \\b quote'/}] == lex(~s/'escaped \\b quote'/)

      assert {:string_symbol, %{}, ~s/'\\'escaped\\' quoted atom/} not in lex(
               ~s/'\\'invalid\\' quoted atom case/
             )
    end

    test "does not tokenize invalid characters as atom (\\n, ', \\)" do
      assert {:string_symbol, %{}, "atom"} in lex("atom\n")
      assert {:string_symbol, %{}, "atom"} in lex("atom'")
      assert {:string_symbol, %{}, "atom"} in lex("atom\\")
    end
  end

  describe "keywords" do
    test "keyword is tokenized as keyword" do
      assert lex("after") == [{:keyword, %{}, "after"}]
      assert lex("begin") == [{:keyword, %{}, "begin"}]
      assert lex("case") == [{:keyword, %{}, "case"}]
      assert lex("catch") == [{:keyword, %{}, "catch"}]
      assert lex("cond") == [{:keyword, %{}, "cond"}]
      assert lex("end") == [{:keyword, %{}, "end"}]
      assert lex("fun") == [{:keyword, %{}, "fun"}]
      assert lex("if") == [{:keyword, %{}, "if"}]
      assert lex("of") == [{:keyword, %{}, "of"}]
      assert lex("query") == [{:keyword, %{}, "query"}]
      assert lex("receive") == [{:keyword, %{}, "receive"}]
      assert lex("when") == [{:keyword, %{}, "when"}]
      assert lex("maybe") == [{:keyword, %{}, "maybe"}]
      assert lex("else") == [{:keyword, %{}, "else"}]
    end

    test "atoms are not tokenized as keyword" do
      refute lex("literal_atom") == [{:keyword, %{}, "literal_atom"}]
    end

    test "atoms that include a keyword on it is not tokenized as keyword" do
      refute {:keyword, %{}, "fun"} in lex("func")
      refute {:keyword, %{}, "when"} in lex("when_found")
      refute {:keyword, %{}, "when"} in lex("found_when")
    end
  end

  describe "operators" do
    test "syntax operators are tokenized as operator" do
      assert lex("+") == [{:operator, %{}, "+"}]
      assert lex("-") == [{:operator, %{}, "-"}]
      assert lex("*") == [{:operator, %{}, "*"}]
      assert lex("/") == [{:operator, %{}, "/"}]
      assert lex("==") == [{:operator, %{}, "=="}]
      assert lex("/=") == [{:operator, %{}, "/="}]
      assert lex("=:=") == [{:operator, %{}, "=:="}]
      assert lex("=/=") == [{:operator, %{}, "=/="}]
      assert lex("<") == [{:operator, %{}, "<"}]
      assert lex("=<") == [{:operator, %{}, "=<"}]
      assert lex(">") == [{:operator, %{}, ">"}]
      assert lex(">=") == [{:operator, %{}, ">="}]
      assert lex("++") == [{:operator, %{}, "++"}]
      assert lex("--") == [{:operator, %{}, "--"}]
      assert lex("=") == [{:operator, %{}, "="}]
      assert lex("!") == [{:operator, %{}, "!"}]
      assert lex("<-") == [{:operator, %{}, "<-"}]
      assert lex("<:-") == [{:operator, %{}, "<:-"}]
      assert lex("<=") == [{:operator, %{}, "<="}]
      assert lex("<:=") == [{:operator, %{}, "<:="}]
    end

    test "word operators are tokenized as operator" do
      assert lex("div") == [{:operator_word, %{}, "div"}]
      assert lex("rem") == [{:operator_word, %{}, "rem"}]
      assert lex("or") == [{:operator_word, %{}, "or"}]
      assert lex("xor") == [{:operator_word, %{}, "xor"}]
      assert lex("bor") == [{:operator_word, %{}, "bor"}]
      assert lex("bxor") == [{:operator_word, %{}, "bxor"}]
      assert lex("bsl") == [{:operator_word, %{}, "bsl"}]
      assert lex("bsr") == [{:operator_word, %{}, "bsr"}]
      assert lex("and") == [{:operator_word, %{}, "and"}]
      assert lex("band") == [{:operator_word, %{}, "band"}]
      assert lex("not") == [{:operator_word, %{}, "not"}]
      assert lex("bnot") == [{:operator_word, %{}, "bnot"}]
    end

    test "atoms are not tokenized as operator" do
      refute lex("literal_atom") == [{:operator_word, %{}, "literal_atom"}]
    end

    test "atoms that includes operators are not tokenized as operator" do
      refute {:operator_word, %{}, "div"} in lex("divatom")
      refute {:operator_word, %{}, "div"} in lex("div_atom")
      refute {:operator_word, %{}, "div"} in lex("atom_div")
      refute {:operator_word, %{}, "div"} in lex("atomdiv")
      refute {:operator_word, %{}, "div"} in lex("atomdivatom")
      refute {:operator_word, %{}, "div"} in lex("'div'")
      refute {:operator_word, %{}, "+"} in lex("'quoted + atom'")
    end

    test "string that includes operators are not tokenized as operator" do
      refute {:word_operator, %{}, "div"} in lex(~s/"div"/)
    end
  end

  describe "module attributes" do
    test "tokenizes definition of module attributtes" do
      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "module"} | _] =
               lex("-module(module_name).")

      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "export"} | _] =
               lex("-export([func/0]).")

      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "record"} | _] =
               lex(~s/-record(module_name, {name = "", id})./)
    end

    test "tokenizes the value of a module attribute" do
      tokens = lex(~s/-record(module_name, {name = "", id})./)
      assert {:name_attribute, %{}, "record"} in tokens
      assert {:string_symbol, %{}, "module_name"} in tokens
      assert {:string_symbol, %{}, "id"} in tokens
    end

    test "tokenizes module attributes when incomplete" do
      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "module"} | _] =
               lex("-module(module_")

      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "export"} | _] =
               lex("-export([func/")

      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "record"} | _] =
               lex(~s"-record(module_name, {name =")
    end

    test "tokenizes module attributes with whitespace" do
      assert [
               {:punctuation, %{}, "-"},
               {:whitespace, %{}, " "},
               {:name_attribute, %{}, "module"} | _
             ] = lex("- module(module_name).")

      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "module"} | _] =
               lex("-module (module_name).")

      assert [
               {:punctuation, %{}, "-"},
               {:whitespace, %{}, " "},
               {:name_attribute, %{}, "module"},
               {:whitespace, %{}, " "} | _
             ] = lex("- module (module_name).")
    end

    test "matches module attributes that start with a newline" do
      assert [
               {:whitespace, %{}, "\n"},
               {:punctuation, %{}, "-"},
               {:name_attribute, %{}, "module"} | _
             ] = lex("\n-module(module_name).")
    end

    test "does not tokenize function calls as module attributes" do
      assert {:name_function, %{}, "b"} in lex("a(X) - b(Y)")
      assert {:name_attribute, %{}, "b"} not in lex("a(X) - b(Y)")
    end

    test "handles -spec attributes" do
      [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "spec"} | _] =
        lex("-spec function_name(type(), type()) -> type().")
    end
  end

  describe "record" do
    test "tokenizes full record definitions correctly" do
      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "record"},
               {:punctuation, %{}, "{"} | _
             ] = lex("#record{attribute = Value}.")

      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "record"},
               {:punctuation, %{}, "{"} | _
             ] = lex("#record{attribute = Value, other_attribute = OtherValue}.")

      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "record"},
               {:punctuation, %{}, "{"} | _
             ] = lex("#record{}.")
    end

    test "tokenizes record attribute access correctly" do
      assert [
               {_, %{}, "RecordVariable"},
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "record_name"},
               {:punctuation, %{}, "."} | _
             ] = lex("RecordVariable#record_name.attribute")
    end

    test "tokenizes the update of a record correctly" do
      assert [
               {_, %{}, "RecordVariable"},
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "record_name"},
               {:punctuation, %{}, "{"} | _
             ] = lex("RecordVariable#record_name{attribute = Value")
    end

    test "does not tokenize invalid records" do
      tokens = lex("#record(attribute = Value)")
      assert {:operator, %{}, "#"} not in tokens
      assert {:string_symbol, %{}, "record"} not in tokens
    end
  end

  describe "function_arity" do
    test "is tokenized correctly for the syntax function_name/arity" do
      assert [
               {:string_symbol, %{}, "function_name"},
               {:punctuation, %{}, "/"},
               {:number_integer, %{}, "0"}
             ] == lex("function_name/0")
    end

    test "is tokenized correctly when referenced with `fun function_name/arity`" do
      tokens = lex("function_name/0")
      assert {:string_symbol, %{}, "function_name"} in tokens
      assert {:punctuation, %{}, "/"} in tokens
      assert {:number_integer, %{}, "0"} in tokens
    end
  end

  describe "prompt" do
    test "without number" do
      assert lex("> a.") == [
               {:generic_prompt, %{selectable: false}, "> "},
               {:string_symbol, %{}, "a"},
               {:punctuation, %{}, "."}
             ]

      assert lex("(a@b)> a.") == [
               {:generic_prompt, %{selectable: false}, "(a@b)> "},
               {:string_symbol, %{}, "a"},
               {:punctuation, %{}, "."}
             ]
    end

    test "with number" do
      assert lex("1> a.") == [
               {:generic_prompt, %{selectable: false}, "1> "},
               {:string_symbol, %{}, "a"},
               {:punctuation, %{}, "."}
             ]

      assert lex("(a@b)1> a.") == [
               {:generic_prompt, %{selectable: false}, "(a@b)1> "},
               {:string_symbol, %{}, "a"},
               {:punctuation, %{}, "."}
             ]
    end

    test "greater-than still works" do
      assert lex("1>2") == [
               {:number_integer, %{}, "1"},
               {:operator, %{}, ">"},
               {:number_integer, %{}, "2"}
             ]

      assert lex("1 > 2") == [
               {:number_integer, %{}, "1"},
               {:whitespace, %{}, " "},
               {:operator, %{}, ">"},
               {:whitespace, %{}, " "},
               {:number_integer, %{}, "2"}
             ]
    end
  end

  describe "shell error" do
    test "single asterix" do
      assert lex("1> P.\n* 1:1: variable 'P' is unbound") == [
               {:generic_prompt, %{selectable: false}, "1> "},
               {:name, %{}, "P"},
               {:punctuation, %{}, "."},
               {:whitespace, %{}, "\n"},
               {:generic_traceback, %{}, "* 1:1: variable 'P' is unbound"}
             ]
    end

    test "double asterix aka multiline error" do
      assert lex(
               "1> P = Descriptor.\n** exception error: no match of right hand side value {4,abcd}"
             ) == [
               {:generic_prompt, %{selectable: false}, "1> "},
               {:name, %{}, "P"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "="},
               {:whitespace, %{}, " "},
               {:name, %{}, "Descriptor"},
               {:punctuation, %{}, "."},
               {:whitespace, %{}, "\n"},
               {:generic_traceback, %{},
                "** exception error: no match of right hand side value {4,abcd}"}
             ]

      assert lex(~S"""
             1> list_to_binary(<<>>).
             ** exception error: bad argument
                  in function  list_to_binary/1
                     called as list_to_binary(<<>>)
                     *** argument 1: not an iolist term
             """) == [
               {:generic_prompt, %{selectable: false}, "1> "},
               {:name_function, %{}, "list_to_binary"},
               {:punctuation, %{group_id: "group-1"}, "("},
               {:punctuation, %{group_id: "group-2"}, "<<"},
               {:punctuation, %{group_id: "group-2"}, ">>"},
               {:punctuation, %{group_id: "group-1"}, ")"},
               {:punctuation, %{}, "."},
               {:whitespace, %{}, "\n"},
               {
                 :generic_traceback,
                 %{},
                 "** exception error: bad argument\n     in function  list_to_binary/1\n        called as list_to_binary(<<>>)\n        *** argument 1: not an iolist term"
               },
               {:whitespace, %{}, "\n"}
             ]
    end
  end
end
