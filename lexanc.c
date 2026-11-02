/* lex1.c         14 Feb 01; 31 May 12; 11 Jan 18; 20 Jan 24       */

/* This file contains code stubs for the lexical analyzer.
   Rename this file to be lexanc.c and fill in the stubs.    */

/* Copyright (c) 2024 Gordon S. Novak Jr. and
   The University of Texas at Austin. */

/*
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <ctype.h>
#include <limits.h>
#include <math.h>
#include <string.h>
#include "token.h"
#include "lexan.h"

extern int CHARCLASS[];
extern int EOFFLG;

#define NUM_RESERVED_OPERATORS 6   /* and or not div mod in */
#define RESERVED_OP_BIAS      14   /* ANDOP is operator 14 */

char *reservedwords[NUM_RESERVED] = {
    "array", "begin", "case", "const", "do",
    "downto", "else", "end", "file", "for",
    "function", "goto", "if", "label",
    "nil", "of", "packed", "procedure", "program",
    "record", "repeat", "set", "then", "to",
    "type", "until", "var", "while", "with"
};

extern char specchar[];


char *reserveredOperators[NUM_RESERVED_OPERATORS] = {
   "and", "or", "not", "div", "mod", "in"
};

  
/* This file will work as given with an input file consisting only
   of integers separated by blanks:
   make lex1
   lex1
   12345 123    345  357
   */

/* Skip blanks and whitespace.  Expand this function to skip comments too. */
void skipblanks ()
  {
      int c;
      int d;
        while ((c = peekchar()) != EOF &&
           (c == ' ' || c == '\n' || c == '\t' || c == '{' ||
            (c == '(' && peek2char() == '*'))){

            /* case 1 - whitespace */
            while ((c = peekchar()) != EOF
             && (c == ' ' || c == '\n' || c == '\t')){
              getchar();
            }

            /* case 2 - comments in '(**)' */
            while ((c = peekchar()) != EOF && (d = peek2char()) != EOF && (c == '(' && d == '*')){
              getchar();
              getchar();

              while ((c = peekchar()) != EOF && (d = peek2char()) != EOF && !(c == '*' && d == ')'))
                    getchar();
              if (c == '*' && d == ')') { 
                getchar();  /* get the * */
                getchar();  /* get the ) */
                }
            }

            /* case 3 - comments in Pascal style */
            while ((c = peekchar()) != EOF && c == '{'){
              getchar();
              while ((c = peekchar()) != EOF && c != '}')
                    getchar();
              if (c == '}') getchar();  /* get the } */
            }

          }
    }

/* Get identifiers and reserved words */
TOKEN identifier (TOKEN tok)
  {
    int c;
    int len = 0;
    while ( (c = peekchar()) != EOF && (isalnum(c)))
      {
        c = getchar();
        if (len < 15) tok->stringval[len++] = c;
      }
    
    tok->stringval[len] = '\0';  

    int i;
    for ( i = 0; i < NUM_RESERVED; i++) {
        if (strcmp(tok->stringval, reservedwords[i]) == 0) {
            tok->tokentype = RESERVED;
            tok->whichval = i + 1;  
            return tok;
        }
    }

    for (i = 0; i < NUM_RESERVED_OPERATORS; i++) {
        if (strcmp(tok->stringval, reserveredOperators[i]) == 0) {
            tok->tokentype = OPERATOR;
            tok->whichval = i + RESERVED_OP_BIAS;  
            return tok;
        }
    }
    tok->tokentype = IDENTIFIERTOK;
    return (tok);
    }



TOKEN getstring (TOKEN tok)
  {
    getchar();  /* consume the opening quote */
    int c;
    int d;
    int len = 0;
    while ((c = peekchar()) != EOF ) {
        if (c == '\'') {
            d = peek2char();
            if (d != EOF && d == '\'') {
                getchar();  /* consume the first quote */
                c = getchar();
                if (len < 15) tok->stringval[len++] = c;
                continue;  /* continue to the next character */
            } else {
                getchar();
                break;  /* end of string */
            }
        }else{
            c = getchar();
            if (len < 15) tok->stringval[len++] = c;
        }
    }
   

    tok->stringval[len] = '\0';
    tok->tokentype = STRINGTOK;
    return tok;
  }

TOKEN special (TOKEN tok)
  {
    int c = getchar();
    int d = peekchar();
    tok->tokentype = OPERATOR;

    switch (c) {
      case '+': tok->whichval = PLUSOP; return tok;
      case '-': tok->whichval = MINUSOP; return tok;
      case '*': tok->whichval = TIMESOP; return tok;
      case '/': tok->whichval = DIVIDEOP; return tok;
      case ':':
        if (d == '=') {
          getchar();
          tok->whichval = ASSIGNOP;
          return tok;
        }
        tok->tokentype = DELIMITER;
        tok->whichval = 3;
        return tok;
      case '=': tok->whichval = EQOP; return tok;
      case '<':
        if (d == '>') {
          getchar();
          tok->whichval = NEOP;
        } else if (d == '=') {
          getchar();
          tok->whichval = LEOP;
        } else {
          tok->whichval = LTOP;
        }
        return tok;
      case '>':
        if (d == '=') {
          getchar();
          tok->whichval = GEOP;
        } else {
          tok->whichval = GTOP;
        }
        return tok;
      case '^': tok->whichval = POINTEROP; return tok;
      case '.':
        if (d == '.') {
          getchar();
          tok->tokentype = DELIMITER;
          tok->whichval = 8;
        } else {
          tok->whichval = DOTOP;
        }
        return tok;
      case ',': tok->tokentype = DELIMITER; tok->whichval = 1; return tok;
      case ';': tok->tokentype = DELIMITER; tok->whichval = 2; return tok;
      case '(': tok->tokentype = DELIMITER; tok->whichval = 4; return tok;
      case ')': tok->tokentype = DELIMITER; tok->whichval = 5; return tok;
      case '[': tok->tokentype = DELIMITER; tok->whichval = 6; return tok;
      case ']': tok->tokentype = DELIMITER; tok->whichval = 7; return tok;
    }
    printf("Unrecognized character: %c\n", c);
    tok->tokentype = DELIMITER;      /* treat as error; parser will reject */
    tok->whichval = 0;
    return tok;
  }

/* Get and convert unsigned numbers of all types. */
TOKEN number (TOKEN tok)
  {
    int c, digit;
    int integer_digits = 0;
    int first_nonzero = -1;
    int total_digits = 0;
    int significant_digits = 0;
    int rounding_digit = -1;
    int decimal_seen = 0;
    int exponent = 0;
    int exponent_sign = 1;
    int integer_overflow = 0;
    int prefix_digits = 0;
    int prefix_value = 0;
    long integer_value = 0;
    long long mantissa = 0;
    long double real_value;

    while ((c = peekchar()) != EOF && CHARCLASS[c] == NUMERIC) {
      digit = getchar() - '0';
      integer_digits++;
      total_digits++;

      if (prefix_digits < 9) {
        prefix_value = prefix_value * 10 + digit;
        prefix_digits++;
      }
      if (!integer_overflow) {
        if (integer_value > (INT_MAX - digit) / 10)
          integer_overflow = 1;
        else
          integer_value = integer_value * 10 + digit;
      }

      if (digit != 0 || first_nonzero >= 0) {
        if (first_nonzero < 0)
          first_nonzero = total_digits - 1;
        if (significant_digits < 8)
          mantissa = mantissa * 10 + digit;
        else if (significant_digits == 8)
          rounding_digit = digit;
        significant_digits++;
      }
    }

    if (peekchar() == '.' && peek2char() != '.') {
      decimal_seen = 1;
      getchar();
      while ((c = peekchar()) != EOF && CHARCLASS[c] == NUMERIC) {
        digit = getchar() - '0';
        total_digits++;
        if (digit != 0 || first_nonzero >= 0) {
          if (first_nonzero < 0)
            first_nonzero = total_digits - 1;
          if (significant_digits < 8)
            mantissa = mantissa * 10 + digit;
          else if (significant_digits == 8)
            rounding_digit = digit;
          significant_digits++;
        }
      }
    }

    if (peekchar() == 'e' || peekchar() == 'E') {
      decimal_seen = 1;
      getchar();
      if (peekchar() == '+' || peekchar() == '-') {
        if (getchar() == '-') exponent_sign = -1;
      }
      while ((c = peekchar()) != EOF && CHARCLASS[c] == NUMERIC) {
        digit = getchar() - '0';
        if (exponent < 1000000)
          exponent = exponent * 10 + digit;
      }
      exponent *= exponent_sign;
    }

    tok->tokentype = NUMBERTOK;
    if (!decimal_seen) {
      tok->basicdt = INTEGER;
      if (integer_overflow) {
        printf("Integer number out of range\n");
        tok->intval = prefix_value;
      } else {
        tok->intval = integer_value;
      }
      return tok;
    }

    tok->basicdt = REAL;
    if (first_nonzero < 0) {
      tok->realval = 0.0;
      return tok;
    }

    while (significant_digits < 8) {
      mantissa *= 10;
      significant_digits++;
    }
    int scale = integer_digits - first_nonzero - 1 + exponent;
    if (rounding_digit >= 5) mantissa++;
    if (mantissa >= 100000000) {
      mantissa /= 10;
      scale++;
    }

    if (scale > 400 || scale < -400) {
      printf("Floating number out of range\n");
      tok->realval = 0.0;
      return tok;
    }
    real_value = (long double) mantissa * powl(10.0L, scale - 7);
    if (real_value < 1.175495e-38L || real_value > 3.402823e38L) {
      printf("Floating number out of range\n");
      tok->realval = 0.0;
    } else {
      tok->realval = (double) real_value;
    }
    return tok;
  }



/* ---------------------------------------------------------------------
   Interface to Yacc.  yylex() gets the next token from gettoken(),
   stores it in yylval, and returns the Yacc token number.
   --------------------------------------------------------------------- */
extern TOKEN yylval;

int yylex()
  { TOKEN tok = gettoken();
    yylval = tok;
    if (EOFFLG) return 0;
    switch (tok->tokentype)
      { case OPERATOR:      return tok->whichval + OPERATOR_BIAS;
        case DELIMITER:     return tok->whichval + DELIMITER_BIAS;
        case RESERVED:      return tok->whichval + RESERVED_BIAS;
        case IDENTIFIERTOK: return IDENTIFIER;
        case STRINGTOK:     return STRING;
        case NUMBERTOK:     return NUMBER;
      }
    return 0;
  }
