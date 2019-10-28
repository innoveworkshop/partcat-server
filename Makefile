# Makefile
# Helps manage everything in a automated manner.
#
# Author: Nathan Campos <nathan@innoveworkshop.com>

# Programs.
RM = rm -f
MKDIR = mkdir -p
PLACKUP = plackup -r

# Paths.
TESTDB = testing.db
IMAGEPATH = public/images/components

run:
	$(PLACKUP) -R lib/ -I lib/ WebApplication.psgi

test: $(IMAGEPATH)/test.png
	$(RM) $(TESTDB)
	sqlite3 $(TESTDB) < sql/initialize.sql
	prove -lvcf

critic:
	perlcritic -4 lib/

$(TESTDB):
	sqlite3 $@ < sql/initialize.sql

$(IMAGEPATH)/test.png:
	$(MKDIR) $(IMAGEPATH)
	head -c $$((3*320*320)) /dev/urandom | convert -depth 8 -size "320x320" RGB:- $@

clean:
	$(RM) $(TESTDB)
	$(RM) $(IMAGEPATH)/test.png
