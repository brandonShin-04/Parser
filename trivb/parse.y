%{     /* parse.y    Pascal Parser      Brandon Shin
          based on pars1.y by Gordon S. Novak Jr.                       */

/* Copyright (c) 2023 Gordon S. Novak Jr. and
   The University of Texas at Austin. */

/*
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program; if not, see <http://www.gnu.org/licenses/>.
  */

       /* To use:
                     make parser
                     ./parser < tests/trivb.pas
        */

        /* Yacc reports 1 shift/reduce conflict, due to the ELSE part of
           the IF statement, but Yacc's default resolves it in the right way.*/

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <ctype.h>
#include <string.h>
#include "token.h"
#include "lexan.h"
#include "symtab.h"
#include "pprint.h"
#include "parse.h"

        /* define the type of the Yacc stack element to be TOKEN */

#define YYSTYPE TOKEN

TOKEN parseresult;

%}

/* Order of tokens corresponds to tokendefs.c; do not change */

%token IDENTIFIER STRING NUMBER   /* token types */

%token PLUS MINUS TIMES DIVIDE    /* Operators */
%token ASSIGN EQ NE LT LE GE GT POINT DOT AND OR NOT DIV MOD IN

%token COMMA                      /* Delimiters */
%token SEMICOLON COLON LPAREN RPAREN LBRACKET RBRACKET DOTDOT

%token ARRAY BEGINBEGIN           /* Lex uses BEGIN */
%token CASE CONST DO DOWNTO ELSE END FILEFILE FOR FUNCTION GOTO IF LABEL NIL
%token OF PACKED PROCEDURE PROGRAM RECORD REPEAT SET THEN TO TYPE UNTIL
%token VAR WHILE WITH

%right thenthen ELSE // Same precedence, but "shift" wins.

%%

program    :  PROGRAM IDENTIFIER LPAREN idlist RPAREN SEMICOLON vblock DOT
                                       { parseresult = makeprogram($2, $4, $7); }
           ;
idlist     :  IDENTIFIER COMMA idlist          { $$ = cons($1, $3); }
           |  IDENTIFIER                       { $$ = cons($1, NULL); }
           ;
vblock     :  VAR varspecs block               { $$ = $3; }
           |  block
           ;
varspecs   :  vargroup SEMICOLON varspecs
           |  vargroup SEMICOLON
           ;
vargroup   :  idlist COLON type                { instvars($1, $3); }
           ;
type       :  simpletype
           ;
simpletype :  IDENTIFIER                       { $$ = findtype($1); }
           ;
block      :  BEGINBEGIN statement endpart
                                       { $$ = makeprogn($1, cons($2, $3)); }
           ;
statement  :  block
           |  IF expr THEN statement endif     { $$ = makeif($1, $2, $4, $5); }
           |  assignment
           |  funcall
           |  FOR assignment TO expr DO statement
                                    { $$ = makefor(1, $1, $2, $3, $4, $5, $6); }
           |  FOR assignment DOWNTO expr DO statement
                                    { $$ = makefor(-1, $1, $2, $3, $4, $5, $6); }
           ;
endpart    :  SEMICOLON statement endpart      { $$ = cons($2, $3); }
           |  END                              { $$ = NULL; }
           ;
endif      :  ELSE statement                   { $$ = $2; }
           |  /* empty */                      { $$ = NULL; }  %prec thenthen
           ;
assignment :  variable ASSIGN expr             { $$ = binop($2, $1, $3); }
           ;
funcall    :  IDENTIFIER LPAREN exprlist RPAREN
                                       { $$ = makefuncall($2, $1, $3); }
           ;
exprlist   :  expr COMMA exprlist              { $$ = cons($1, $3); }
           |  expr                             { $$ = cons($1, NULL); }
           ;
expr       :  expr compareop simpleexpr        { $$ = binop($2, $1, $3); }
           |  simpleexpr
           ;
simpleexpr :  simpleexpr plusop term           { $$ = binop($2, $1, $3); }
           |  sign term                        { $$ = unaryop($1, $2); }
           |  term
           ;
term       :  term timesop factor              { $$ = binop($2, $1, $3); }
           |  factor
           ;
factor     :  LPAREN expr RPAREN               { $$ = $2; }
           |  variable
           |  NUMBER
           |  STRING
           |  funcall
           ;
variable   :  IDENTIFIER                       { $$ = findid($1); }
           ;
compareop  :  EQ | LT | GT | NE | LE | GE | IN
           ;
plusop     :  PLUS | MINUS | OR
           ;
sign       :  PLUS | MINUS
           ;
timesop    :  TIMES | DIVIDE | DIV | MOD | AND
           ;
%%

/* You should add your own debugging flags below, and add debugging
   printouts to your programs.

   To add more flags, use the next power of 2.
   To turn on all flags, set DEBUG to the next power of 2, minus 1.
  */

#define DEBUG         0             /* set bits here for debugging, 0 = off  */
#define DB_CONS       1             /* bit to trace cons */
#define DB_BINOP      2             /* bit to trace binop */
#define DB_MAKEIF     4             /* bit to trace makeif */
#define DB_MAKEPROGN  8             /* bit to trace makeprogn */
#define DB_PARSERES  16             /* bit to trace parseresult */
#define DB_FINDID    32             /* bit to trace findid / findtype */
#define DB_MAKEFOR   64             /* bit to trace makefor */

 int labelnumber = 0;  /* sequential counter for internal label numbers */

TOKEN cons(TOKEN item, TOKEN list)           /* add item to front of list */
  { item->link = list;
    if (DEBUG & DB_CONS)
       { printf("cons\n");
         dbugprinttok(item);
         dbugprinttok(list);
       };
    return item;
  }

TOKEN binop(TOKEN op, TOKEN lhs, TOKEN rhs)        /* reduce binary operator */
  { op->operands = lhs;          /* link operands to operator       */
    lhs->link = rhs;             /* link second operand to first    */
    rhs->link = NULL;            /* terminate operand list          */
    if (DEBUG & DB_BINOP)
       { printf("binop\n");
         dbugprinttok(op);
         dbugprinttok(lhs);
         dbugprinttok(rhs);
       };
    return op;
  }

/* unary operator: a leading + is dropped; - becomes (- x) */
TOKEN unaryop(TOKEN op, TOKEN lhs)
  { if (op->whichval == PLUSOP) return lhs;
    op->operands = lhs;
    lhs->link = NULL;
    return op;
  }

TOKEN makeop(int opnum)
  { TOKEN tok = talloc();
    tok->tokentype = OPERATOR;
    tok->whichval = opnum;
    return tok;
  }

TOKEN copytok(TOKEN origtok)
  { TOKEN tok = talloc();
    *tok = *origtok;
    tok->link = NULL;
    return tok;
  }

TOKEN fillintc(TOKEN tok, int num)
  { tok->tokentype = NUMBERTOK;
    tok->basicdt = INTEGER;
    tok->intval = num;
    return tok;
  }

TOKEN makeintc(int num)
  { return fillintc(talloc(), num); }

TOKEN makeif(TOKEN tok, TOKEN exp, TOKEN thenpart, TOKEN elsepart)
  {  tok->tokentype = OPERATOR;  /* Make it look like an operator   */
     tok->whichval = IFOP;
     if (elsepart != NULL) elsepart->link = NULL;
     thenpart->link = elsepart;
     exp->link = thenpart;
     tok->operands = exp;
     if (DEBUG & DB_MAKEIF)
        { printf("makeif\n");
          dbugprinttok(tok);
          dbugprinttok(exp);
          dbugprinttok(thenpart);
          dbugprinttok(elsepart);
        };
     return tok;
   }

TOKEN makeprogn(TOKEN tok, TOKEN statements)
  {  tok->tokentype = OPERATOR;
     tok->whichval = PROGNOP;
     tok->operands = statements;
     if (DEBUG & DB_MAKEPROGN)
       { printf("makeprogn\n");
         dbugprinttok(tok);
         dbugprinttok(statements);
       };
     return tok;
   }

/* If stmt is a progn, return its list of statements; else stmt itself.
   Used to avoid needless nested progn's in loop bodies. */
TOKEN unprogn(TOKEN stmt)
  { if (stmt != NULL && stmt->tokentype == OPERATOR
        && stmt->whichval == PROGNOP)
      return stmt->operands;
    if (stmt != NULL) stmt->link = NULL;
    return stmt;
  }

/* nconc: destructively append listb to the end of lista */
TOKEN nconc(TOKEN lista, TOKEN listb)
  { TOKEN tok;
    if (lista == NULL) return listb;
    tok = lista;
    while (tok->link != NULL) tok = tok->link;
    tok->link = listb;
    return lista;
  }

TOKEN makelabel()
  { TOKEN tok = makeop(LABELOP);
    tok->operands = makeintc(labelnumber++);
    return tok;
  }

TOKEN makegoto(int label)
  { TOKEN tok = makeop(GOTOOP);
    tok->operands = makeintc(label);
    return tok;
  }

TOKEN makefuncall(TOKEN tok, TOKEN fn, TOKEN args)
  { SYMBOL sym;
    tok->tokentype = OPERATOR;
    tok->whichval = FUNCALLOP;
    tok->operands = fn;
    fn->link = args;
    sym = searchst(fn->stringval);
    if (sym != NULL && sym->kind == FUNCTIONSYM && sym->datatype != NULL
        && sym->datatype->datatype != NULL)
      { tok->symtype = sym->datatype->datatype;   /* result type */
        tok->basicdt = sym->datatype->basicdt;
      }
    return tok;
  }

TOKEN makeprogram(TOKEN name, TOKEN args, TOKEN statements)
  { TOKEN tok = makeop(PROGRAMOP);
    TOKEN argprogn = makeprogn(talloc(), args);
    tok->operands = name;
    name->link = argprogn;
    argprogn->link = statements;
    statements->link = NULL;
    return tok;
  }

/* for i := start to/downto endexpr do statement  ==>
   (progn (:= i start)
          (label L)
          (if (<= i endexpr)
              (progn statement
                     (:= i (+ i 1))
                     (goto L))))                                       */
TOKEN makefor(int sign, TOKEN tok, TOKEN asg, TOKEN tokb, TOKEN endexpr,
              TOKEN tokc, TOKEN statement)
  { TOKEN var = asg->operands;              /* loop variable i */
    TOKEN label = makelabel();
    int lnum = label->operands->intval;
    TOKEN test, incr, body, gotol;

    /* test: (<= i endexpr) or (>= i endexpr) */
    test = makeop(sign > 0 ? LEOP : GEOP);
    binop(test, copytok(var), endexpr);

    /* increment: (:= i (+ i 1)) or (- i 1) */
    incr = makeop(ASSIGNOP);
    binop(incr, copytok(var),
          binop(makeop(sign > 0 ? PLUSOP : MINUSOP), copytok(var),
                makeintc(1)));

    gotol = makegoto(lnum);
    incr->link = gotol;
    body = makeprogn(tokc, nconc(unprogn(statement), incr));

    makeif(tokb, test, body, NULL);
    asg->link = label;
    label->link = tokb;
    tokb->link = NULL;
    if (DEBUG & DB_MAKEFOR)
       { printf("makefor\n");
         dbugprinttok(tok);
       };
    return makeprogn(tok, asg);
  }

/* findid looks up an identifier, setting its symentry and symtype. */
TOKEN findid(TOKEN tok)
  { SYMBOL sym, typ;
    sym = searchst(tok->stringval);
    if (sym == NULL)
      { fprintf(stderr, "Undeclared identifier: %s\n", tok->stringval);
        return tok;
      }
    tok->symentry = sym;
    typ = sym->datatype;
    tok->symtype = typ;
    if (typ != NULL && (typ->kind == BASICTYPE || typ->kind == POINTERSYM))
      tok->basicdt = typ->basicdt;
    if (DEBUG & DB_FINDID)
       { printf("findid\n");
         dbugprinttok(tok);
       };
    return tok;
  }

/* findtype looks up a type name and puts its type into tok->symtype. */
TOKEN findtype(TOKEN tok)
  { SYMBOL sym = searchst(tok->stringval);
    if (sym == NULL)
      { fprintf(stderr, "Undeclared type: %s\n", tok->stringval);
        return tok;
      }
    if (sym->kind == BASICTYPE)
      { tok->symtype = sym;
        tok->basicdt = sym->basicdt;
      }
    else tok->symtype = sym->datatype;     /* TYPESYM: point to the type */
    if (DEBUG & DB_FINDID)
       { printf("findtype\n");
         dbugprinttok(tok);
       };
    return tok;
  }

/* install variables in the symbol table */
void instvars(TOKEN idlist, TOKEN typetok)
  { SYMBOL sym, typesym; int align;
    typesym = typetok->symtype;
    align = alignsize(typesym);
    while (idlist != NULL)
      { sym = insertsym(idlist->stringval);
        sym->kind = VARSYM;
        sym->offset = wordaddress(blockoffs[blocknumber], align);
        sym->size = typesym->size;
        blockoffs[blocknumber] = sym->offset + sym->size;
        sym->datatype = typesym;
        sym->basicdt = typesym->basicdt;
        idlist = idlist->link;
      }
  }

int wordaddress(int n, int wordsize)
  { return ((n + wordsize - 1) / wordsize) * wordsize; }

void yyerror (char const *s)
{
  fprintf (stderr, "%s\n", s);
}

int main(void)
  { int res;
    initscanner();
    init_charclass();
    initsyms();
    res = yyparse();
    printf("yyparse result = %8d\n", res);
    printstlevel(1);    /* to see level 0 too, change to:   printst();  */
    if (DEBUG & DB_PARSERES) dbugprinttok(parseresult);
    ppexpr(parseresult);           /* Pretty-print the result tree */
    return 0;
  }
