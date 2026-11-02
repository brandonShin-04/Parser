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

program    :  PROGRAM IDENTIFIER LPAREN idlist RPAREN SEMICOLON lblock DOT
                                       { parseresult = makeprogram($2, $4, $7); }
           ;
idlist     :  IDENTIFIER COMMA idlist          { $$ = cons($1, $3); }
           |  IDENTIFIER                       { $$ = cons($1, NULL); }
           ;
lblock     :  LABEL numlist SEMICOLON cblock   { $$ = $4; }
           |  cblock
           ;
numlist    :  NUMBER COMMA numlist             { instlabel($1); }
           |  NUMBER                           { instlabel($1); }
           ;
cblock     :  CONST cdefs tblock               { $$ = $3; }
           |  tblock
           ;
tblock     :  TYPE tdefs vblock                { $$ = $3; }
           |  vblock
           ;
tdefs      :  tdef SEMICOLON tdefs
           |  tdef SEMICOLON
           ;
tdef       :  IDENTIFIER EQ type               { insttype($1, $3); }
           ;
cdefs      :  cdef SEMICOLON cdefs
           |  cdef SEMICOLON
           ;
cdef       :  IDENTIFIER EQ constant           { instconst($1, $3); }
           ;
constant   :  NUMBER
           |  sign NUMBER                      { $$ = unaryop($1, $2); }
           |  STRING
           |  IDENTIFIER                       { $$ = findid($1); }
           |  sign IDENTIFIER                  { $$ = unaryop($1, findid($2)); }
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
           |  ARRAY LBRACKET simplelist RBRACKET OF type
                                               { $$ = instarray($3, $6); }
           |  RECORD fieldlist END             { $$ = instrec($1, $2); }
           |  POINT IDENTIFIER                 { $$ = instpoint($1, $2); }
           ;
simpletype :  IDENTIFIER                       { $$ = findtype($1); }
           |  LPAREN idlist RPAREN             { $$ = instenum($2); }
           |  constant DOTDOT constant         { $$ = instdotdot($1, $2, $3); }
           ;
simplelist :  simpletype COMMA simplelist      { $$ = cons($1, $3); }
           |  simpletype                       { $$ = cons($1, NULL); }
           ;
fieldlist  :  fields SEMICOLON fieldlist       { $$ = nconc($1, $3); }
           |  fields
           ;
fields     :  idlist COLON type                { $$ = instfields($1, $3); }
           ;
block      :  BEGINBEGIN statement endpart
                                       { $$ = makepnb($1, cons($2, $3)); }
           ;
statement  :  block
           |  IF expr THEN statement endif     { $$ = makeif($1, $2, $4, $5); }
           |  assignment
           |  funcall
           |  WHILE expr DO statement   { $$ = makewhile($1, $2, $3, $4); }
           |  GOTO NUMBER                      { $$ = dogoto($1, $2); }
           |  NUMBER COLON statement           { $$ = dolabel($1, $2, $3); }
           |  REPEAT stmtlist UNTIL expr
                                    { $$ = makerepeat($1, $2, $3, $4); }
           |  FOR assignment TO expr DO statement
                                    { $$ = makefor(1, $1, $2, $3, $4, $5, $6); }
           |  FOR assignment DOWNTO expr DO statement
                                    { $$ = makefor(-1, $1, $2, $3, $4, $5, $6); }
           ;
stmtlist   :  statement SEMICOLON stmtlist     { $$ = cons($1, $3); }
           |  statement                        { $$ = cons($1, NULL); }
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
           |  NIL                              { $$ = fillintc($1, 0); }
           |  funcall
           |  NOT factor                       { $$ = unaryop($1, $2); }
           ;
variable   :  IDENTIFIER                       { $$ = findid($1); }
           |  variable LBRACKET exprlist RBRACKET
                                         { $$ = arrayref($1, $2, $3, $4); }
           |  variable DOT IDENTIFIER          { $$ = reducedot($1, $2, $3); }
           |  variable POINT                   { $$ = dopoint($1, $2); }
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
  { int ldt = lhs->basicdt, rdt = rhs->basicdt;
    if (op->tokentype == OPERATOR)
      { switch (op->whichval)
          { case ASSIGNOP:                    /* convert rhs to type of lhs */
              if (ldt == INTEGER && rdt == REAL) rhs = makefix(rhs);
              else if (ldt == REAL && rdt == INTEGER) rhs = makefloat(rhs);
              op->basicdt = ldt;
              break;
            case PLUSOP: case MINUSOP: case TIMESOP: case DIVIDEOP:
            case EQOP: case NEOP: case LTOP: case LEOP: case GEOP: case GTOP:
              if (ldt == REAL && rdt == INTEGER) rhs = makefloat(rhs);
              else if (ldt == INTEGER && rdt == REAL) lhs = makefloat(lhs);
              else if (op->whichval == DIVIDEOP && ldt == INTEGER
                       && rdt == INTEGER)
                { lhs = makefloat(lhs); rhs = makefloat(rhs); }
              if (op->whichval >= EQOP) op->basicdt = BOOLETYPE;
              else op->basicdt = (ldt == REAL || rdt == REAL
                                  || op->whichval == DIVIDEOP)
                                   ? REAL : ldt;
              break;
            default:
              op->basicdt = ldt;
              break;
          }
      }
    op->operands = lhs;          /* link operands to operator       */
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
    if (op->whichval == MINUSOP && lhs->tokentype == NUMBERTOK)
      { if (lhs->basicdt == REAL) lhs->realval = -lhs->realval;
        else lhs->intval = -lhs->intval;
        return lhs;                          /* fold negative constant */
      }
    op->basicdt = lhs->basicdt;
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

/* makefloat: float a constant, or wrap tok in (float tok) */
TOKEN makefloat(TOKEN tok)
  { TOKEN op;
    if (tok->tokentype == NUMBERTOK)
      { tok->realval = (double) tok->intval;
        tok->basicdt = REAL;
        return tok;
      }
    op = makeop(FLOATOP);
    op->basicdt = REAL;
    op->operands = tok;
    op->link = NULL;
    tok->link = NULL;
    return op;
  }

/* makefix: truncate a constant, or wrap tok in (fix tok) */
TOKEN makefix(TOKEN tok)
  { TOKEN op;
    if (tok->tokentype == NUMBERTOK)
      { tok->intval = (int) tok->realval;
        tok->basicdt = INTEGER;
        return tok;
      }
    op = makeop(FIXOP);
    op->basicdt = INTEGER;
    op->operands = tok;
    op->link = NULL;
    tok->link = NULL;
    return op;
  }

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

/* makepnb: like makeprogn, but if statements is a single progn,
   just return it. */
TOKEN makepnb(TOKEN tok, TOKEN statements)
  { if (statements != NULL && statements->link == NULL
        && statements->tokentype == OPERATOR
        && statements->whichval == PROGNOP)
      return statements;
    return makeprogn(tok, statements);
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
    /* choose write/writeln variant by argument type */
    if (args != NULL && (strcmp(fn->stringval, "write") == 0
                         || strcmp(fn->stringval, "writeln") == 0))
      { if (args->basicdt == INTEGER && args->tokentype != STRINGTOK)
          strcat(fn->stringval, "i");
        else if (args->basicdt == REAL)
          strcat(fn->stringval, "f");
      }
    if (strcmp(fn->stringval, "new") == 0 && args != NULL)
      { TOKEN var = args;
        SYMBOL ptype = var->symtype;          /* POINTERSYM */
        SYMBOL target = ptype->datatype;      /* type name, e.g. person */
        int size = (target->datatype != NULL) ? target->datatype->size
                                              : target->size;
        tok->basicdt = POINTER;
        fn->link = makeintc(size);
        return binop(makeop(ASSIGNOP), var, tok);
      }
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

/* repeat statements until expr  ==>
   (progn (label L) statements... (if expr (progn) (goto L)))         */
TOKEN makerepeat(TOKEN tok, TOKEN statements, TOKEN tokb, TOKEN expr)
  { TOKEN label = makelabel();
    int lnum = label->operands->intval;
    TOKEN body = NULL, s, next, empty, ifst;
    for (s = statements; s != NULL; s = next)   /* splice nested progns */
      { next = s->link;
        body = nconc(body, unprogn(s));
      }
    empty = makeprogn(talloc(), NULL);
    empty->link = makegoto(lnum);
    ifst = makeop(IFOP);
    ifst->operands = expr;
    expr->link = empty;
    label->link = nconc(body, ifst);
    return makeprogn(tok, label);
  }

/* while expr do statement  ==>
   (progn (label L) (if expr (progn statement (goto L))))             */
TOKEN makewhile(TOKEN tok, TOKEN expr, TOKEN tokb, TOKEN statement)
  { TOKEN label = makelabel();
    int lnum = label->operands->intval;
    TOKEN body = makeprogn(tokb, nconc(unprogn(statement), makegoto(lnum)));
    TOKEN ifst = makeif(makeop(IFOP), expr, body, NULL);
    label->link = ifst;
    ifst->link = NULL;
    return makeprogn(tok, label);
  }

/* ---------------- user labels ---------------- */
#define MAXLABELS 100
int labels[MAXLABELS];   /* labels[internal number] = user label number */

void instlabel(TOKEN num)
  { labels[labelnumber++] = num->intval; }

int findlabel(int userlabel)
  { int i;
    for (i = 0; i < labelnumber; i++)
      if (labels[i] == userlabel) return i;
    fprintf(stderr, "Undeclared label: %d\n", userlabel);
    return -1;
  }

TOKEN dogoto(TOKEN tok, TOKEN labeltok)
  { return makegoto(findlabel(labeltok->intval)); }

/* n: statement  ==>  (progn (label i) statement) */
TOKEN dolabel(TOKEN labeltok, TOKEN tok, TOKEN statement)
  { TOKEN label = makeop(LABELOP);
    label->operands = makeintc(findlabel(labeltok->intval));
    label->link = statement;
    statement->link = NULL;
    return makeprogn(tok, label);
  }

/* ---------------- type declarations ---------------- */

/* settoktype: set symtype (and basicdt where meaningful) of tok */
void settoktype(TOKEN tok, SYMBOL typ, SYMBOL ent)
  { tok->symtype = typ;
    if (ent != NULL) tok->symentry = ent;
    if (typ != NULL && (typ->kind == BASICTYPE || typ->kind == SUBRANGE
                        || typ->kind == POINTERSYM))
      tok->basicdt = typ->basicdt;
  }

void insttype(TOKEN typename, TOKEN typetok)
  { SYMBOL sym = searchins(typename->stringval);
    SYMBOL typ = typetok->symtype;
    sym->kind = TYPESYM;
    sym->datatype = typ;
    sym->size = typ->size;
    sym->basicdt = typ->basicdt;
  }

TOKEN makesubrange(TOKEN tok, int low, int high)
  { SYMBOL sym = symalloc();
    sym->kind = SUBRANGE;
    sym->basicdt = INTEGER;
    sym->lowbound = low;
    sym->highbound = high;
    sym->size = basicsizes[INTEGER];
    tok->symtype = sym;
    return tok;
  }

/* (red, white, blue): install constants 0, 1, 2 and make 0..2 */
TOKEN instenum(TOKEN idlist)
  { int n = 0;
    TOKEN tok;
    for (tok = idlist; tok != NULL; tok = tok->link)
      instconst(tok, makeintc(n++));
    return makesubrange(idlist, 0, n - 1);
  }

TOKEN instdotdot(TOKEN lowtok, TOKEN dottok, TOKEN hightok)
  { return makesubrange(dottok, lowtok->intval, hightok->intval); }

/* ^ typename: the pointer points to the type name, which may not be
   defined yet, so use searchins. */
TOKEN instpoint(TOKEN tok, TOKEN typename)
  { SYMBOL sym = symalloc();
    sym->kind = POINTERSYM;
    sym->basicdt = POINTER;
    sym->datatype = searchins(typename->stringval);
    sym->size = basicsizes[POINTER];
    tok->symtype = sym;
    return tok;
  }

/* put the type into each field name token */
TOKEN instfields(TOKEN idlist, TOKEN typetok)
  { TOKEN tok;
    for (tok = idlist; tok != NULL; tok = tok->link)
      tok->symtype = typetok->symtype;
    return idlist;
  }

/* make a RECORDSYM with a linked list of field symbols */
TOKEN instrec(TOKEN rectok, TOKEN argstok)
  { SYMBOL rec = symalloc(), field, last = NULL;
    int offset = 0;
    TOKEN tok;
    rec->kind = RECORDSYM;
    for (tok = argstok; tok != NULL; tok = tok->link)
      { field = makesym(tok->stringval);
        field->datatype = tok->symtype;
        field->basicdt = tok->symtype->basicdt;
        field->size = tok->symtype->size;
        field->offset = wordaddress(offset, alignsize(tok->symtype));
        offset = field->offset + field->size;
        if (last == NULL) rec->datatype = field;
        else last->link = field;
        last = field;
      }
    rec->size = wordaddress(offset, RECORDALIGN);
    rectok->symtype = rec;
    return rectok;
  }

/* array[b1, b2, ...] of type: an array of arrays, built from the end */
TOKEN instarray(TOKEN bounds, TOKEN typetok)
  { SYMBOL arr, range;
    if (bounds->link != NULL) typetok = instarray(bounds->link, typetok);
    range = bounds->symtype;
    arr = symalloc();
    arr->kind = ARRAYSYM;
    arr->datatype = typetok->symtype;
    arr->lowbound = range->lowbound;
    arr->highbound = range->highbound;
    arr->size = (range->highbound - range->lowbound + 1)
                * typetok->symtype->size;
    bounds->symtype = arr;
    return bounds;
  }

/* ---------------- variable references ---------------- */

int isintconst(TOKEN tok)
  { return tok->tokentype == NUMBERTOK && tok->basicdt == INTEGER; }

/* mulint: (* n exp), folding constants */
TOKEN mulint(TOKEN exp, int n)
  { if (isintconst(exp)) return fillintc(exp, exp->intval * n);
    if (n == 1) return exp;
    return binop(makeop(TIMESOP), makeintc(n), exp);
  }

/* addint: add integer expression off to exp, folding constants.
   Constants are kept as the first operand of +.  */
TOKEN addint(TOKEN exp, TOKEN off, TOKEN tok)
  { TOKEN c;
    if (isintconst(off) && isintconst(exp))
      return fillintc(exp, exp->intval + off->intval);
    if (isintconst(exp)) { c = exp; exp = off; off = c; }  /* off = const */
    if (isintconst(off))
      { if (off->intval == 0) return exp;
        if (exp->tokentype == OPERATOR && exp->whichval == PLUSOP
            && isintconst(exp->operands))
          { exp->operands->intval += off->intval;
            return exp;
          }
        return binop(tok ? tok : makeop(PLUSOP), off, exp);
      }
    return binop(tok ? tok : makeop(PLUSOP), exp, off);
  }

TOKEN makeplus(TOKEN lhs, TOKEN rhs, TOKEN tok)
  { return addint(lhs, rhs, tok); }

/* addoffs adds offset off to an aref expression exp */
TOKEN addoffs(TOKEN exp, TOKEN off)
  { TOKEN base = exp->operands;
    TOKEN newoff = addint(base->link, off, NULL);
    base->link = newoff;
    newoff->link = NULL;
    return exp;
  }

/* makearef: (aref var off); if var is already an aref, add the offset */
TOKEN makearef(TOKEN var, TOKEN off, TOKEN tok)
  { TOKEN aref;
    if (var->tokentype == OPERATOR && var->whichval == AREFOP)
      return addoffs(var, off);
    aref = tok ? tok : talloc();
    aref->tokentype = OPERATOR;
    aref->whichval = AREFOP;
    aref->operands = var;
    var->link = off;
    off->link = NULL;
    aref->link = NULL;
    return aref;
  }

/* var.field  ==>  (aref var offset) */
TOKEN reducedot(TOKEN var, TOKEN dot, TOKEN field)
  { SYMBOL rec = var->symtype, f;
    TOKEN res;
    assert(rec != NULL && rec->kind == RECORDSYM);
    for (f = rec->datatype; f != NULL; f = f->link)
      if (strcmp(f->namestring, field->stringval) == 0) break;
    if (f == NULL)
      { fprintf(stderr, "Unknown field: %s\n", field->stringval);
        return var;
      }
    res = makearef(var, makeintc(f->offset), dot);
    res->basicdt = 0;
    settoktype(res, f->datatype, NULL);
    return res;
  }

/* arr[s1, s2, ...]  ==>  (aref arr offset-expression) */
TOKEN arrayref(TOKEN arr, TOKEN tok, TOKEN subs, TOKEN tokb)
  { SYMBOL typ = arr->symtype;
    int cterm = 0;
    TOKEN vexp = NULL, sub, next, off, res;
    for (sub = subs; sub != NULL; sub = next)
      { next = sub->link;
        sub->link = NULL;
        assert(typ != NULL && typ->kind == ARRAYSYM);
        int esize = typ->datatype->size;
        cterm -= typ->lowbound * esize;
        if (isintconst(sub)) cterm += sub->intval * esize;
        else
          { TOKEN term = mulint(sub, esize);
            vexp = (vexp == NULL) ? term : addint(vexp, term, NULL);
          }
        typ = typ->datatype;
      }
    off = (vexp == NULL) ? makeintc(cterm)
                         : addint(vexp, makeintc(cterm), NULL);
    res = makearef(arr, off, tok);
    res->basicdt = 0;
    settoktype(res, typ, NULL);
    return res;
  }

/* var^  ==>  (^ var), whose type is the record pointed to */
TOKEN dopoint(TOKEN var, TOKEN tok)
  { SYMBOL ptype = var->symtype;
    assert(ptype != NULL && ptype->kind == POINTERSYM);
    tok->operands = var;
    var->link = NULL;
    tok->basicdt = 0;
    settoktype(tok, ptype->datatype->datatype, NULL);
    return tok;
  }

/* instconst installs a constant in the symbol table */
void instconst(TOKEN idtok, TOKEN consttok)
  { SYMBOL sym = insertsym(idtok->stringval);
    sym->kind = CONSTSYM;
    sym->basicdt = consttok->basicdt;
    if (consttok->tokentype == STRINGTOK)
      { sym->basicdt = STRINGTYPE;
        strncpy(sym->constval.stringconst, consttok->stringval, 16);
      }
    else if (sym->basicdt == REAL) sym->constval.realnum = consttok->realval;
    else sym->constval.intnum = consttok->intval;
    sym->size = basicsizes[sym->basicdt];
  }

/* findid looks up an identifier, setting its symentry and symtype. */
TOKEN findid(TOKEN tok)
  { SYMBOL sym, typ;
    sym = searchst(tok->stringval);
    if (sym == NULL)
      { fprintf(stderr, "Undeclared identifier: %s\n", tok->stringval);
        return tok;
      }
    if (sym->kind == CONSTSYM)          /* replace constant by its value */
      { if (sym->basicdt == STRINGTYPE)
          { tok->tokentype = STRINGTOK;
            strncpy(tok->stringval, sym->constval.stringconst, 16);
          }
        else
          { tok->tokentype = NUMBERTOK;
            if (sym->basicdt == REAL) tok->realval = sym->constval.realnum;
            else tok->intval = sym->constval.intnum;
          }
        tok->basicdt = sym->basicdt;
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
