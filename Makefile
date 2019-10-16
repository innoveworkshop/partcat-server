# Makefile
# Helps manage everything in a automated manner.
#
# Author: Nathan Campos <nathan@innoveworkshop.com>

TESTDB = testing.db

test: $(TESTDB)
	prove -lvcf

critic:
	-perlcritic -4 bin/ lib/

$(TESTDB):
	sqlite3 $(TESTDB) < sql/initialize.sql
