module bakery.script.ScriptBuilder;

import std.conv;

import bakery.script.ScriptInterpreter;
import bakery.script.Script;
import bakery.utils.BSON : R_BSON=BSON, Document;

import std.stdio;

alias R_BSON!true BSON;

@safe
class ScriptBuilderException : ScriptException {
    this( immutable(char)[] msg ) {
        super( msg );
    }
}

@safe
class ScriptBuilderExceptionIncompte : ScriptException {
    this( immutable(char)[] msg ) {
        super( msg );
    }
}

class ScriptBuilder {
    alias ScriptElement function() opcreate;
    package static opcreate[string] opcreators;
    alias ScriptInterpreter.ScriptType ScriptType;
    alias ScriptInterpreter.Token Token;
    /**
       Build as script from bson data stream
     */
    @safe
    class ScriptTokenError : ScriptElement {
        immutable(Token) token;
        this(immutable(Token) token) {
            super(0);
            this.token=token;
        }
        override ScriptElement opCall(const Script s, ScriptContext sc) const {
            check(s, sc);
            throw new ScriptBuilderException(token.toText);
            return null;
        }
    }

    static BSON Token2BSON(const(Token) token) @safe {
        auto bson=new BSON();
        bson["token"]=token.token;
        bson["type"]=token.type;
        bson["line"]=token.line;
        bson["jump"]=token.jump;
        return bson;
    }
    unittest {
        immutable(Token) opcode={
          token : "opcode",
          type  : ScriptType.WORD
        };
        immutable(Token)[] tokens;
        // ( Forth source code )
        // : Test
        //  opcode if
        //    opcode opcode if
        //       opcode opcode if
        //          opcode opcode
        //        else
        //          opcode opcode
        //        then
        //           opcode opcode
        //    then then
        //  opcode opcode
        //  begin
        //    opcode opcode
        //  while
        //    opcode opcode
        //    do
        //      opcode opcode
        //    loop
        //    opcode opcode
        //    do
        //      opcode opcode
        //    +loop
        //  repeat
        //
        //  begin
        //      opcode opcode
        //      begin
        //        opcode opcode
        //      until
        //  until


        tokens~=token_func("Test");
        tokens~=opcode;
        tokens~=token_if;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_if;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_if;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_else;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_endif;
        tokens~=token_endif;
        tokens~=token_endif;
        //
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_begin;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_while;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_do;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_loop;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_do;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_incloop;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_repeat;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_begin;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_begin;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_until;
        tokens~=opcode;
        tokens~=opcode;
        tokens~=token_until;

        { //
          // Function parse test missing end of function
          //
            BSON[] codes;

            // Build BSON array of the token list
            foreach(t; tokens) {
                codes~=Token2BSON(t);
            }
            // Build the BSON stream
            auto bson_stream=new BSON();
            bson_stream["code"]=codes;
            auto stream=bson_stream.expand;


            //
            // Reconstruct the token array from the BSON stream
            // and verify the reconstructed stream
            auto retokens=ScriptInterpreter.BSON2Tokens(stream);
            assert(retokens.length == tokens.length);
            // Add token types to the token stream
            retokens=ScriptInterpreter.Tokens2Tokens(retokens);
            // writefln("tokens.length=%s", tokens.length);
            // writefln("retokens.length=%s", retokens.length);
            // Reconstructed tokens is one less because
            // : test is converted into one token
            // {
            //   token : "Test",
            //   type  : FUNC
            // }
            assert(retokens.length+1 == tokens.length);

            // Forth tokens
            // : Test
            assert(tokens[0].token==":"); // Function declare symbol
            assert(tokens[1].token=="Test"); // Function name
            assert(tokens[0].type==ScriptType.WORD);
            assert(tokens[1].type==ScriptType.WORD);

            // Reconstructed
            assert(retokens[0].token=="Test");
            assert(retokens[0].type==ScriptType.FUNC); // Type change to FUNC

            // Cut out the function declaration
            immutable tokens_test=tokens[2..$];
            immutable retokens_test=retokens[1..$];
            // The reset of the token should be the same
            foreach(i;0..tokens_test.length) {
                // writefln("%s] retokens[i].type=%s  tokens[i].type=%s",
                //     i,
                //     retokens_test[i].type,
                //     tokens_test[i].type);
                assert(retokens_test[i].type == tokens_test[i].type);
                assert(retokens_test[i].token == tokens_test[i].token);
            }

            //
            // Parse function
            //
            auto builder=new ScriptBuilder;
            immutable(Token)[] base_tokens;
            Script script;
            // parse_function should fail because end of function is missing
            assert(builder.parse_functions(script, retokens, base_tokens));
            assert(script !is null);
            // base_tokens.length is non zero because it contains Error tokens
            assert(base_tokens.length > 0);

            assert(base_tokens[0].type == ScriptType.ERROR);
            // No function has been declared
            assert(script.functions.length == 0);
        }

        //     assert(builder.BSON2Token(stream, retokens));
        // }
//            writefln("3 tokens.length=%s", tokens.length);

        tokens~=token_endfunc;
//            writefln("4 tokens.length=%s", tokens.length);

        {
            //
            // Function builder
            //
            BSON[] codes;

            // Build BSON array of the token list
            foreach(t; tokens) {
                codes~=Token2BSON(t);
            }
            // Build the BSON stream
            auto bson_stream=new BSON();
            bson_stream["code"]=codes;
            auto stream=bson_stream.expand;


            //
            // Reconstruct the token array from the BSON stream
            // and verify the reconstructed stream

            auto retokens=ScriptInterpreter.BSON2Tokens(stream);
            retokens=ScriptInterpreter.Tokens2Tokens(retokens);
            //
            // Parse function
            //
            auto builder=new ScriptBuilder;
            immutable(Token)[] base_tokens;
            Script script;
            // parse_function should NOT fail because end of function is missing
            assert(!builder.parse_functions(script, retokens, base_tokens));
            // base_tokens.length is zero because it should not contain any Error tokens
            // foreach(i,t; base_tokens) {
            //     writefln("base_tokens %s] %s", i, t.toText);
            // }
            assert(base_tokens.length == 0);

//            assert(base_tokens[0].type == ScriptType.ERROR);
            // No function has been declared
            assert(script.functions.length == 1);
            // Check if function named "Test" is declared
            assert("Test" in script.functions);

            auto func=script.functions["Test"];


            // Check that the number of function tokens is correct
            assert(func.tokens.length == 50);

            //
            // Expand all loop to conditinal and unconditional jumps
            //
            auto loop_expanded_tokens = builder.expand_loop(func.tokens);
            // foreach(i,t; loop_expanded_tokens) {
            //      writefln("%s]:%s", i, t.toText);
            // }

            assert(loop_expanded_tokens.length == 89);

            auto condition_jump_tokens=builder.add_jump_label(loop_expanded_tokens);
            assert(builder.error_tokens.length == 0);
            // foreach(i,t; condition_jump_tokens) {
            //      writefln("%s]:%s", i, t.toText);
            // }
            // assert(!builder.parse_functions(retokens));
        }
    }
    unittest { // Simple function test
        string source=
            ": test\n"~
            "  * -\n"~
            ";\n"
            ;
        auto src=new ScriptInterpreter(source);
        // Convert to BSON object
        auto bson=src.toBSON;
        // Expand to BSON stream
        auto data=bson.expand;
        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, data);

        auto sc=new ScriptContext(10, 10, 10);
        sc.data_push(3);
        sc.data_push(2);
        sc.data_push(5);

        script.run("test", sc, true);
        assert( sc.data_pop_number == -7 );

    }
    unittest { // Simple if test
        string source=
            ": test\n"~
            "  if  \n"~
            "  111  \n"~
            "  then  \n"~
            ";\n"
            ;
        auto src=new ScriptInterpreter(source);
        // Convert to BSON object
        auto bson=src.toBSON;
        // Expand to BSON stream
        auto data=bson.expand;
        Script script;
        auto builder=new ScriptBuilder;
        auto tokens=builder.build(script, data);

        auto sc=new ScriptContext(10, 10, 10);
        sc.data_push(10);
        sc.data_push(0);

        script.run("test", sc);
        assert(sc.data_pop_number == 10);

        sc.data_push(10);

        script.run("test", sc);
        assert(sc.data_pop_number == 111);

    }

private:
    uint var_count;
    uint[string] var_indices;
    uint allocate_var(string var_name) {
        if ( var_name !in var_indices ) {
            var_indices[var_name]=var_count;
            var_count++;
        }
        return var_indices[var_name];
    }
    bool is_var(string var_name) pure const nothrow {
        return (var_name in var_indices) !is null;
    }
    uint get_var(string var_name) const {
        return var_indices[var_name];
    }
    immutable(Token)[] error_tokens;
    // Test aid function
    static immutable(Token)[] token_func(string name) {
        immutable(Token)[] result;
        immutable(Token) func_declare={
          token : ":",
          type  : ScriptType.WORD
        };
        immutable(Token) func_name={
          token : name,
          type  : ScriptType.WORD
        };
        result~=func_declare;
        result~=func_name;
        return result;
    };
    static immutable(Token) token_endfunc={
      token : ";",
      type : ScriptType.WORD
    };

    //
    static immutable(Token) token_put={
      token : "!",
      type : ScriptType.PUT
    };
    static immutable(Token) token_get= {
      token : "@",
      type : ScriptType.GET
    };
    static immutable(Token) token_inc= {
        // Increas by one
      token : "1+",
      type : ScriptType.WORD
    };
    static immutable(Token) token_dup= {
        // duplicate
      token : "dup",
      type : ScriptType.WORD
    };
    static immutable(Token) token_to_r= {
        // duplicate
      token : ">r",
      type : ScriptType.WORD
    };
    static immutable(Token) token_from_r= {
        // duplicate
      token : "<r",
      type : ScriptType.WORD
    };
    static immutable(Token) token_gte= {
        // duplicate
      token : ">=",
      type : ScriptType.WORD
    };
    static immutable(Token) token_invert= {
        // invert
      token : "invert",
      type : ScriptType.WORD
    };
    static immutable(Token) token_repeat= {
        // repeat
      token : "repeat",
      type : ScriptType.REPEAT
    };
    static immutable(Token) token_until= {
        // until
      token : "until",
      type : ScriptType.UNTIL
    };
    static immutable(Token) token_if= {
        // if
      token : "if",
      type : ScriptType.IF
    };
    static immutable(Token) token_else= {
        // else
      token : "else",
      type : ScriptType.ELSE
    };
    static immutable(Token) token_begin= {
        // begin
      token : "begin",
      type : ScriptType.BEGIN
    };
    static immutable(Token) token_endif= {
        // then
      token : "then",
      type : ScriptType.ENDIF
    };
    static immutable(Token) token_leave= {
        // leave
      token : "leave",
      type : ScriptType.LEAVE
    };
    static immutable(Token) token_while= {
        // while
      token : "while",
      type : ScriptType.WHILE
    };
    static immutable(Token) token_do= {
        // do
      token : "do",
      type : ScriptType.DO
    };
    static immutable(Token) token_loop= {
        // loop
      token : "loop",
      type : ScriptType.LOOP
    };
    static immutable(Token) token_incloop= {
        // +loop
      token : "+loop",
      type : ScriptType.INCLOOP
    };

    static immutable(Token) var_I(uint i) @safe pure nothrow {
        immutable(Token) result = {
          token : "I_"~to!string(i),
          type : ScriptType.VAR
        };
        return result;
    };
    static immutable(Token) var_to_I(uint i) @safe pure nothrow {
        immutable(Token) result = {
          token : "I_TO_"~to!string(i),
          type : ScriptType.VAR
        };
        return result;
    };
    @safe
    bool parse_functions(
        ref Script script,
        immutable(Token[]) tokens,
        out immutable(Token)[] base_tokens) {
        immutable(Token)[] function_tokens;
        string function_name;
        bool fail=false;
        bool inside_function;
        if ( script is null ) {
            script=new Script;
        }
        foreach(t; tokens) {
            // writefln("parse_function %s",t.toText);
            if ( (t.token==":") || (t.type == ScriptType.FUNC) ) {

                if ( inside_function || (function_name !is null) ) {
                    immutable(Token) error = {
                      token : "Function declaration inside functions not allowed",
                      line : t.line,
                      type : ScriptType.FUNC
                    };
                    function_tokens~=t;
                    function_tokens~=error;
                    base_tokens~=error;
                    fail=true;

                }
                if ( t.token !in script.functions ) {
//                    writefln("%s",t.token);
                    function_tokens = null;
                    function_name = t.token;
                }
                else {
                    immutable(Token) error = {
                      token : "Function "~t.token~" redefined!",

                      line : t.line,
                      type : ScriptType.ERROR
                    };
                    function_tokens~=t;
                    function_tokens~=error;
                    base_tokens~=error;
                    fail=true;
                }
                inside_function=true;
            }
            else if ( t.token==";" ) {
//                writefln("%s",function_name);
                if (inside_function) {
                    immutable(Token) exit = {
                      token : "$exit",
                      line : t.line,
                      type : ScriptType.EXIT
                    };
                    function_tokens~=exit;
                    Script.Function func={
                      name : function_name,
                      tokens : function_tokens
                    };
                    script.functions[function_name]=func;
                    inside_function=false;
                }
                else {
                    immutable(Token) error = {
                      token : "Function end with out a function begin declaration",
                      line : t.line,
                      type : ScriptType.ERROR
                    };
                    base_tokens~=t;
                    base_tokens~=error;
                    fail=true;
                }
                function_tokens = null;
                function_name = null;


            }
            else if ( function_name.length > 0 ) { // Inside function scope
                function_tokens~=t;
            }
            else { //
                base_tokens~=t;
            }
        }
        if (inside_function) {
//            writeln("Inside function");
            immutable(Token) error = {
              token : "No function end found",
              type : ScriptType.ERROR
            };
            base_tokens~=error;
            fail=true;
        }
        return fail;
    }

    immutable(Token)[] expand_loop(immutable(Token)[] tokens) @safe {
        uint loop_index;
        immutable(ScriptType)[] begin_loops;
        //immutable
        immutable(Token)[] scope_tokens;
        foreach(t; tokens) {
            with(ScriptType) switch (t.type) {
                case DO:
                    // Insert forth opcode
                    // I_FROM_ ! I_ !
                    scope_tokens~=var_to_I(loop_index);
                    scope_tokens~=token_put;
                    scope_tokens~=var_I(loop_index);
                    scope_tokens~=token_put;
                    begin_loops ~= t.type;
                    goto case BEGIN;
                case BEGIN:
                    scope_tokens~=token_begin;
                    loop_index++;
                    begin_loops ~= t.type;
                    break;
                case LOOP:
                case INCLOOP:
                    // loop
                    // I_ dup @ 1 + dup ! I_TO @ >= if goto-begin then
                    // +loop
                    // >r I_ dup @ <r + dup ! I_TO @ >=
                    if ( begin_loops.length == 0 ) {
                        immutable(Token) error = {
                          token : "DO expect before "~to!string(t.type),
                          line : t.line,
                          type : ScriptType.ERROR
                        };

                        scope_tokens~=error;
                        error_tokens~=error;
                    }
                    else {
                        if ( begin_loops[$-1] == DO ) {
                            if (t.type == INCLOOP) {
                                scope_tokens~=token_to_r;
                            }
                            scope_tokens~=var_I(loop_index);
                            scope_tokens~=token_dup;
                            scope_tokens~=token_get;
                            if (t.type == INCLOOP) {
                                scope_tokens~=token_from_r;
                            }
                            else {
                                scope_tokens~=token_inc;
                            }
                            scope_tokens~=token_dup;
                            scope_tokens~=token_put;
                            scope_tokens~=var_to_I(loop_index);
                            scope_tokens~=token_get;
                            scope_tokens~=token_gte;
                            scope_tokens~=token_if;
                            scope_tokens~=token_repeat;
                            scope_tokens~=token_endif;

                        }
                        else {
                            immutable(Token) error = {
                              token : "DO begub loop expect not "~to!string(t.type),
                              line : t.line,
                              type : ScriptType.ERROR
                            };
                            scope_tokens~=error;
                            error_tokens~=error;
                        }
                        begin_loops.length--;
                        loop_index--;
                    }
                    break;
                case WHILE:
                    if ( begin_loops.length == 0 ) {
                        immutable(Token) error = {
                          token : "BEGIN expect before "~to!string(t.type),
                          line : t.line,
                          type : ScriptType.ERROR
                        };
                        scope_tokens~=error;
                        error_tokens~=error;

                    }
                    else {
                        if ( begin_loops[$-1] == BEGIN ) {
                            scope_tokens~=token_if;
                            scope_tokens~=token_leave;
                            scope_tokens~=token_endif;
                        }
                        else {
                            immutable(Token) error = {
                              token : "BEGIN expect before "~to!string(t.type),
                              line : t.line,
                              type : ScriptType.ERROR
                            };
                            scope_tokens~=error;
                            error_tokens~=error;
                        }
                    }
                    break;
                case UNTIL:
                    if ( begin_loops.length == 0 ) {
                        immutable(Token) error = {
                          token : "BEGIN expect before "~to!string(t.type),
                          line : t.line,
                          type : ScriptType.ERROR
                        };
                        scope_tokens~=error;
                        error_tokens~=error;

                    }
                    else {
                        if ( begin_loops[$-1] == BEGIN ) {
                            scope_tokens~=token_invert;
                            scope_tokens~=token_if;
                            scope_tokens~=token_repeat;
                            scope_tokens~=token_endif;
                            loop_index--;
                        }
                        else {
                            immutable(Token) error = {
                              token : "BEGIN expect before "~to!string(t.type),
                              line : t.line,
                              type : ScriptType.ERROR
                            };
                            scope_tokens~=error;
                            error_tokens~=error;
                        }
                    }
                    break;
                case LEAVE:
                    scope_tokens~=t;
                    break;
                default:
                    scope_tokens~=t;
                }
        }
        return scope_tokens;
    }
    @safe
    immutable(Token)[] add_jump_label(immutable(Token[]) tokens) {
        uint jump_index;
        immutable(uint)[] conditional_index_stack;
        immutable(uint)[] loop_index_stack;
        immutable(Token)[] scope_tokens;
        foreach(t; tokens) {
            with(ScriptType) switch (t.type) {
                case IF:
                    jump_index++;
                    conditional_index_stack~=jump_index;
                    immutable(Token) token={
                      token : t.token,
                      line : t.line,
                      type : t.type,
                      jump : conditional_index_stack[$-1]
                    };
                    scope_tokens~=token;
                    break;
                case ELSE:
                    immutable(Token) token_else={
                      token : t.token,
                      line : t.line,
                      type : LABEL,
                      jump : conditional_index_stack[$-1]
                    };
                    conditional_index_stack.length--;
                    jump_index++;
                    conditional_index_stack~=jump_index;
                    immutable(Token) token_goto={
                      token : "$if_label", // THEN is us a jump traget of the IF
                      line : t.line,
                      type : GOTO,
                      jump : conditional_index_stack[$-1]
                    };
                    scope_tokens~=token_goto;
                    scope_tokens~=token_else;
                    break;
                case ENDIF:
                    immutable(Token) token_endif={
                      token : t.token,
                      line : t.line,
                      type : LABEL,
                      jump : conditional_index_stack[$-1]
                    };
                    conditional_index_stack.length--;
                    scope_tokens~=token_endif;
                    break;
                case BEGIN:
                    jump_index++;
                    loop_index_stack~=jump_index;
                    immutable(Token) token_begin={
                      token : t.token,
                      line : t.line,
                      type : LABEL,
                      jump : loop_index_stack[$-1]
                    };
                    jump_index++;
                    loop_index_stack~=jump_index;
                    scope_tokens~=token_begin;
                    break;
                case REPEAT:
                    if ( loop_index_stack.length > 1 ) {
                        immutable(Token) token_repeat={
                          token : t.token,
                          line : t.line,
                          type : GOTO,
                          jump : loop_index_stack[$-2]
                        };
                        immutable(Token) token_end={
                          token : t.token,
                          line : t.line,
                          type : LABEL,
                          jump : loop_index_stack[$-1]
                        };
                        loop_index_stack.length-=2;
                        scope_tokens~=token_begin;
                        scope_tokens~=token_end;
                    }
                    else {
                        immutable(Token) error={
                          token : "Repeat unexpected",
                          line : t.line,
                          type : ERROR
                        };
                        error_tokens~=error;
                        scope_tokens~=error;
                    }
                    break;
                case LEAVE:
                    if ( loop_index_stack.length > 1 ) {
                        immutable(Token) token_leave={
                          token : t.token,
                          line : t.line,
                          type : GOTO,
                          jump : loop_index_stack[$-1]
                        };
                        scope_tokens~=token_leave;
                    }
                    else {
                        immutable(Token) error={
                          token : "Leave unexpected",
                          line : t.line,
                          type : ERROR
                        };
                        error_tokens~=error;
                        scope_tokens~=error;
                    }
                    break;
                case DO:
                case WHILE:
                case LOOP:
                case INCLOOP:
                    immutable(Token) error={
                      token : "The opcode "~to!string(t.type)~
                      " should be eliminated by loop_expand function",
                      line : t.line,
                      type : ERROR
                    };
                    scope_tokens~=error;
                    error_tokens~=error;
                    break;
                default:
                    scope_tokens~=t;
                    break;
                }
        }
        return scope_tokens;
    }
    static this() {
        enum binaryOp=["+", "-", "*", "/", "%", "|", "&", "^", "<<" ];
        enum compareOp=["<", "<=", "==", "!=", ">=", ">"];
        enum stackOp=[
            "dup", "swap", "drop", "over",
            "rot", "-rot", "-rot", "-rot",
            "tuck",
            "2dup", "2drop", "2swap", "2over",
            "2nip", "2tuck",
            ">r", "r>", "r@"
            ];
        enum unitaryOp=["1-", "1+"];
        void build_opcreators(string opname) {
            void createBinaryOp(alias oplist)(string opname) {
                static ScriptElement create(string op)() {
                    return new ScriptBinaryOp!(op);
                }
                static if ( oplist.length !=0 ) {
                    if ( opname == oplist[0] ) {
                        enum op=oplist[0];
                        opcreators[op]=&(create!op);
                    }
                    else {
                        createBinaryOp!(oplist[1..$])(opname);
                    }
                }
            }
            void createCompareOp(alias oplist)(string opname) {
                static ScriptElement create(string op)() {
                    return new ScriptCompareOp!(op);
                }
                static if ( oplist.length !=0 ) {
                    if ( opname == oplist[0] ) {
                        enum op=oplist[0];
                        opcreators[op]=&(create!op);
                    }
                    else {
                        createCompareOp!(oplist[1..$])(opname);
                    }
                }
            }
            void createStackOp(alias oplist)(string opname) {
                static ScriptElement create(string op)() {
                    return new ScriptStackOp!(op);
                }
                static if ( oplist.length !=0 ) {
                    if ( opname == oplist[0] ) {
                        enum op=oplist[0];
                        opcreators[op]=&(create!op);
                    }
                    else {
                        createStackOp!(oplist[1..$])(opname);
                    }
                }
            }
            void createUnitaryOp(alias oplist)(string opname) {
                static ScriptElement create(string op)() {
                    return null;
//                    return new ScriptUnitaryOp!(op);
                }
                static if ( oplist.length !=0 ) {
                    if ( opname == oplist[0] ) {
                        enum op=oplist[0];
                        opcreators[op]=&(create!op);
                    }
                    else {
                        createUnitaryOp!(oplist[1..$])(opname);
                    }
                }
            }

            createBinaryOp!(binaryOp)(opname);
            createCompareOp!(compareOp)(opname);
            createStackOp!(stackOp)(opname);
            createUnitaryOp!(unitaryOp)(opname);
        }
        foreach(opname; binaryOp~compareOp~stackOp~unitaryOp) {
            build_opcreators(opname);
        }

    }
    ScriptElement createElement(string op) {
        if ( op in opcreators ) {
            return opcreators[op]();
        }
        return null;
    }
    immutable(Token)[] build(ref Script script, immutable(Token)[] tokens) {
        immutable(Token)[] results;
        if ( parse_functions(script, tokens, results) ) {
            return results;
        }
        foreach(ref f; script.functions) {
            auto loop_tokens=expand_loop(f.tokens);
            f.tokens=add_jump_label(loop_tokens);
        }
        build_functions(script);
        return null;
    }
    immutable(Token)[] build(ref Script script, immutable ubyte[] data) {
        auto tokens=ScriptInterpreter.BSON2Tokens(data);
        // Add token types
        tokens=ScriptInterpreter.Tokens2Tokens(tokens);
        return build(script, tokens);
    }
    void build_functions(ref Script script) {
        struct ScriptLabel {
            ScriptElement target; // Script element to jump to
            ScriptElement[] jumps; // Script element to jump from
        }
        scope ScriptElement[] function_scripts;
        foreach(name,ref f; script.functions) {
            scope ScriptLabel*[uint] script_labels;
            ScriptElement forward(immutable uint i=0) {
                ScriptElement result;
                if ( i < f.tokens.length ) {
                    auto t=f.tokens[i];
                    with(ScriptType) final switch (t.type) {
                        case LABEL:
                            result=forward(i+1);
                            assert(( (t.jump in script_labels) !is null) && (script_labels[t.jump].target is null) );
                            if ( t.jump !in script_labels) {
                                script_labels[t.jump]=new ScriptLabel;
                            }
                            script_labels[t.jump].target=result;
                        break;
                        case GOTO:
                            result=new ScriptJump;
                            if ( t.jump !in script_labels) {
                                script_labels[t.jump]=new ScriptLabel;
                            }
                            script_labels[t.jump].jumps~=result;
                            break;
                        case IF:
                            result=new ScriptConditionalJump;
                            if ( t.jump !in script_labels) {
                                script_labels[t.jump]=new ScriptLabel;
                            }
                            script_labels[t.jump].jumps~=result;
                            break;
                        case NUMBER:
                        case HEX:
                            result=new ScriptNumber(t.token);
                            break;
                        case TEXT:
                            result=new ScriptText(t.token);
                            break;
                        case EXIT:
                            result=new ScriptExit();
                            break;
                        case ERROR:
                            result=new ScriptTokenError(t);
                            break;
                        case WORD:
                            result=createElement(t.token);
                            if ( result is null ) {
                                // Possible function call
                                result=new ScriptCall(t.token);
                            }
                            break;
                        case PUT:
                            if ( is_var(t.token) ) {
                                result=new ScriptPutVar(t.token, get_var(t.token));
                            }
                            else {
                                result=new ScriptTokenError(t);
                            }
                            break;
                        case GET:
                            if ( is_var(t.token) ) {
                                result=new ScriptGetVar(t.token, get_var(t.token));
                            }
                            else {
                                result=new ScriptTokenError(t);
                            }
                            break;
                        case VAR:
                            allocate_var(t.token);
                            result=forward(i+1);
                            break;
                        case FUNC:
                        case ELSE:
                        case ENDIF:
                        case DO:
                        case LOOP:
                        case INCLOOP:
                        case BEGIN:
                        case UNTIL:
                        case WHILE:
                        case REPEAT:
                        case LEAVE:
//                        case THEN:
                        case INDEX:
                            //
                        case UNKNOWN:
                        case COMMENT:
                            assert(0, "This "~to!string(t.type)~" pseudo script tokens '"~t.token~"' should have been replace by an executing instructions at this point");
                        case EOF:
                            assert(0, "EOF instructions should have been removed at this point");
                        }
                    result.next=forward(i+1);
                    result.set_location(t.token, t.line, t.pos);
                }
                return result;
            }
            auto func_script=forward;
            function_scripts~=func_script;
            f.opcode=func_script;
            // Connect all the jump labels
            foreach(label; script_labels) {
                foreach(jump; label.jumps) {
                    auto s=cast(ScriptJump)jump;
                    s.set_jump(label.target);
                }
            }
        }
        foreach(fs; function_scripts) {
            for(auto s=fs; s !is null; s=s.next) {
                auto call_script = cast(ScriptCall)s;
                if ( call_script !is null ) {
                    if ( call_script.name in script.functions) {
                        // The function is defined in the function tabel
                        auto func=script.functions[call_script.name];
                        if ( func.opcode !is null ) {
                            // Insert the script element to call Script Element
                            call_script.set_jump( func.opcode );
                        }
                        else {
                            call_script.set_jump(
                                new ScriptError("The function "~call_script.name~
                                    " does not contain any opcodes", call_script)
                                );
                        }
                    }
                    else {
                        call_script.set_jump(
                            new ScriptError("The function named "~call_script.name~
                                " is not defined ",call_script)
                            );
                    }
                }
            }
        }
    }
}
