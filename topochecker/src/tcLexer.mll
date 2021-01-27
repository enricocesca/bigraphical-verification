{
  open TcParser
  exception Eof
}
  rule token = parse
    [' ' '\t'] { token lexbuf }
| '\n' { Lexing.new_line lexbuf; token lexbuf }
| "//"[^'\n']* { token lexbuf } 
| '"' { STRING (stringl (Buffer.create 30) lexbuf) }
| "E" {E}
| "A" {A}
| "U" {U}
| "G" {G}
| "F" {F}
| "X" {X}
| "MAXVOL" {MAXVOL}
| "SCMP" {STATCMP}
| "SCMPIMA" {SCMPIMA}
| "ASM" {ASM}
| "EUCL" {EUCL}
| "EDT" {EDT}
| "EDTM" {EDTM}
| "MDDT" {MDDT}
| "IF" {IF}
| "THEN" {THEN}
| "ELSE" {ELSE}
| "FI" {FI}
| "Gr" {GROUP}
| "-<" {SHARE}
| "Let" {LET}
| "," {COMMA}
| ";" {EOL}
| "(" {LPAREN}
| ")" {RPAREN}
| "[" {LBRACKET}
| "]" {RBRACKET}
| "{" {LCURLY}
| "}" {RCURLY}
| ['"'] {QUOTE}
| "TT" {TRUE}
| "FF" {FALSE}
| ('-')?['0'-'9']+'.'['0'-'9']* as lxm {FLOAT (float_of_string lxm)}
| ('-')?['0'-'9']+ as lxm {INT (int_of_string lxm)}
| "&" {AND}
| "|" {OR}
| "!" {NOT}
| "N" {NEAR}
| "I" {INTERIOR}
| "S" {SURROUNDED}
| "->" {ARROW}
| "=" {EQ}
| "^" {HAT}
| "Check" {CHECK}
| "Ask" {ASK}
| "Kripke" {KRIPKE}
| "Space" {SPACE}
| "Model" {MODEL}
| "Eval" {EVAL}
| "Output" {OUTPUT}
| "#" {COUNT}
| (">" | "=" | "<"| "!" | "?" | "+" | "-" | "*" | "/")* as lxm {OP lxm}
| ['A'-'Z' 'a'-'z']['A'-'Z' 'a'-'z' '0'-'9']* as lxm {IDE lxm} 
| eof {EOF} 

and  stringl buffer = parse
 | '"' { Buffer.contents buffer }
 | eof { raise End_of_file }
 | _ as char { Buffer.add_char buffer char; stringl buffer lexbuf }	
