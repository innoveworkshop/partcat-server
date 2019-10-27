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
IMAGEPATH = static/images

run:
	$(PLACKUP) -R lib/ -I lib/ bin/WebApplication.psgi

init:
	$(MKDIR) $(IMAGEPATH)

test: $(IMAGEPATH)/test.png
	$(RM) $(TESTDB)
	sqlite3 $(TESTDB) < sql/initialize.sql
	prove -lvcf

critic:
	perlcritic -4 lib/

$(TESTDB):
	sqlite3 $@ < sql/initialize.sql

$(IMAGEPATH)/test.png:
	head -c $$((3*320*320)) /dev/urandom | convert -depth 8 -size "320x320" RGB:- $@

clean:
	$(RM) $(TESTDB)
	$(RM) $(IMAGEPATH)/test.png
