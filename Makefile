# Makefile
# Helps manage everything in a automated manner.
#
# Author: Nathan Campos <nathan@innoveworkshop.com>

# Programs.
RM = rm -f

# Paths.
TESTDB = testing.db

test:
	$(RM) $(TESTDB)
	sqlite3 $(TESTDB) < sql/initialize.sql
	prove -lvcf

critic:
	perlcritic -4 lib/

$(TESTDB):
	sqlite3 $(TESTDB) < sql/initialize.sql

clean:
	$(RM) $(TESTDB)
