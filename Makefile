# Makefile
# Helps manage everything in a automated manner.
#
# Author: Nathan Campos <nathan@innoveworkshop.com>

# Programs.
CP = cp
RM = rm -f
SED = sed -i
MKDIR = mkdir -p
PLACKUP = plackup -r
SQLITE = sqlite3

# Paths.
CONFPATH = config
IMAGEPATH = public/images/components
TESTDB = testing.db
MAINDB = partcat.db
TESTCONF = testing.conf
MAINCONF = main.conf

run:
	$(PLACKUP) -R lib/ -I lib/ WebApplication.psgi

init: $(CONFPATH)/$(MAINCONF) $(MAINDB)

test: $(IMAGEPATH)/test.png
	$(RM) $(TESTDB)
	$(SQLITE) $(TESTDB) < sql/initialize.sql
	prove -lvcf

critic:
	perlcritic -4 lib/

$(MAINDB):
	$(SQLITE) $@ < sql/initialize.sql

$(CONFPATH)/$(MAINCONF):
	$(CP) $(CONFPATH)/$(TESTCONF) $@
	$(SED) "s/$(TESTDB)/$(MAINDB)/g" $@

$(IMAGEPATH)/test.png:
	$(MKDIR) $(IMAGEPATH)
	head -c $$((3*320*320)) /dev/urandom | convert -depth 8 -size "320x320" RGB:- $@

clean:
	$(RM) $(TESTDB)
	$(RM) $(IMAGEPATH)/test.png

purge: clean
	$(RM) $(MAINDB)
	$(RM) $(CONFPATH)/$(MAINCONF)
