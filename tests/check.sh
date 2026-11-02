#!/bin/bash
# Run the parser on each test program and diff against the sample output.
# Memory addresses in symbol-table lines are normalized before comparing.
cd "$(dirname "$0")/.."
norm() { sed 's/^ [0-9]\+ /ADDR /; s/typ [0-9]\{6,\}/typ PTR/; s/ *<--.*//'; }
status=0
check() {   # name  sample-extraction-command
  ./parser < tests/$1.pas | norm > tests/$1.out
  if diff tests/$1.out <(eval "$2" | norm) > tests/$1.diff; then
    echo "$1: PASS"; rm -f tests/$1.diff
  else
    echo "$1: FAIL (see tests/$1.diff)"; status=1
  fi
}
check trivb  "sed -n '/^yyparse/,\$p' tests/trivb.sample"
check graph1 "sed -n '/^yyparse/,/goto 1)))))/p' tests/graph1.sample"
check pasrec "cat tests/pasrec.sample"
exit $status
