#!/bin/sh

test_description='test handling of deltas by dumpfile importer'

. ./test-lib.sh

test_expect_success 'setup' '
	>empty &&
	printf foo >preimage
'

test_expect_success 'reject empty delta' '
	test_must_fail test-svn-fe -d preimage empty 0
'

test_expect_success 'delta can empty file' '
	printf "SVNQ" | q_to_nul >clear.delta &&
	test-svn-fe -d preimage clear.delta 4 >actual &&
	test_cmp empty actual
'

test_expect_success 'one-window empty delta' '
	printf "SVNQ%s" "QQQQQ" | q_to_nul >clear.onewindow &&
	test-svn-fe -d preimage clear.onewindow 9 >actual &&
	test_cmp empty actual
'

test_expect_success 'incomplete window header' '
	printf "SVNQ%s" "QQQQQ" | q_to_nul >clear.onewindow &&
	printf "SVNQ%s" "QQ" | q_to_nul >clear.partialwindow &&
	test_must_fail test-svn-fe -d preimage clear.onewindow 6 &&
	test_must_fail test-svn-fe -d preimage clear.partialwindow 6
'

test_expect_success 'declared delta longer than actual delta' '
	printf "SVNQ%s" "QQQQQ" | q_to_nul >clear.onewindow &&
	printf "SVNQ%s" "QQ" | q_to_nul >clear.partialwindow &&
	test_must_fail test-svn-fe -d preimage clear.onewindow 14 &&
	test_must_fail test-svn-fe -d preimage clear.partialwindow 9
'

test_expect_success 'two-window empty delta' '
	printf "SVNQ%s%s" "QQQQQ" "QQQQQ" | q_to_nul >clear.twowindow &&
	test-svn-fe -d preimage clear.twowindow 14 >actual &&
	test_must_fail test-svn-fe -d preimage clear.twowindow 13 &&
	test_cmp empty actual
'

test_expect_success 'noisy zeroes' '
	printf "SVNQ%s" \
		"RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRQQQQQ" |
		tr R "\200" |
		q_to_nul >clear.noisy &&
	len=$(wc -c <clear.noisy) &&
	test-svn-fe -d preimage clear.noisy $len &&
	test_cmp empty actual
'

test_expect_success 'reject variable-length int in magic' '
	printf "SVNRQ" | tr R "\200" | q_to_nul >clear.badmagic &&
	test_must_fail test-svn-fe -d preimage clear.badmagic 5
'

test_expect_success 'truncated integer' '
	printf "SVNQ%s%s" "QQQQQ" "QQQQRRQ" |
		tr R "\200" |
		q_to_nul >clear.fullint &&
	printf "SVNQ%s%s" "QQQQQ" "QQQQRR" |
		tr RT "\201" |
		q_to_nul >clear.partialint &&
	test_must_fail test-svn-fe -d preimage clear.fullint 15 &&
	test-svn-fe -d preimage clear.fullint 16 &&
	test_must_fail test-svn-fe -d preimage clear.partialint 15
'

test_expect_success 'nonempty (but unused) preimage view' '
	printf "SVNQ%b" "Q\003QQQ" | q_to_nul >clear.readpreimage &&
	test-svn-fe -d preimage clear.readpreimage 9 >actual &&
	test_cmp empty actual
'

test_expect_success 'preimage view: right endpoint cannot backtrack' '
	printf "SVNQ%b%b" "Q\003QQQ" "Q\002QQQ" |
		q_to_nul >clear.backtrack &&
	test_must_fail test-svn-fe -d preimage clear.backtrack 14
'

test_expect_success 'preimage view: left endpoint can advance' '
	printf "SVNQ%b%b" "Q\003QQQ" "\001\002QQQ" |
		q_to_nul >clear.preshrink &&
	printf "SVNQ%b%b" "Q\003QQQ" "\001\001QQQ" |
		q_to_nul >clear.shrinkbacktrack &&
	test-svn-fe -d preimage clear.preshrink 14 >actual &&
	test_must_fail test-svn-fe -d preimage clear.shrinkbacktrack 14 &&
	test_cmp empty actual
'

test_expect_success 'preimage view: offsets compared by value' '
	printf "SVNQ%b%b" "\001\001QQQ" "\0200Q\003QQQ" |
		q_to_nul >clear.noisybacktrack &&
	printf "SVNQ%b%b" "\001\001QQQ" "\0200\001\002QQQ" |
		q_to_nul >clear.noisyadvance &&
	test_must_fail test-svn-fe -d preimage clear.noisybacktrack 15
	test-svn-fe -d preimage clear.noisyadvance 15 &&
	test_cmp empty actual
'

test_expect_success 'preimage view: accept truncated preimage' '
	printf "SVNQ%b" "\010QQQQ" | q_to_nul >clear.lateemptyread &&
	printf "SVNQ%b" "\010\001QQQ" | q_to_nul >clear.latenonemptyread &&
	printf "SVNQ%b" "\001\010QQQ" | q_to_nul >clear.longread &&
	test-svn-fe -d preimage clear.lateemptyread 9 >actual.emptyread &&
	test-svn-fe -d preimage clear.latenonemptyread 9 >actual.nonemptyread &&
	test-svn-fe -d preimage clear.longread 9 >actual.longread &&
	test_cmp empty actual.emptyread &&
	test_cmp empty actual.nonemptyread &&
	test_cmp empty actual.longread
'

test_expect_success 'inline data' '
	printf "SVNQ%b%s%b%s" "QQQQ\003" "bar" "QQQQ\001" "x" |
		q_to_nul >inline.clear &&
	test-svn-fe -d preimage inline.clear 18 >actual &&
	test_cmp empty actual
'

test_expect_success 'truncated inline data' '
	printf "SVNQ%b%s" "QQQQ\003" "b" | q_to_nul >inline.trunc &&
	test_must_fail test-svn-fe -d preimage inline.trunc 10
'

test_expect_success 'truncated inline data (after instruction section)' '
	printf "SVNQ%b%b%s" "QQ\001\001\003" "\0201" "b" | q_to_nul >insn.trunc &&
	test_must_fail test-svn-fe -d preimage insn.trunc 11
'

test_done
