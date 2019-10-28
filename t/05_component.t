#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Test::Spec;
use Config::Tiny;

use Library::Component;

describe "A component" => sub {
	my $dbh;
	my $config;

	my $component;
	my $quantity = 123;
	my $mpn = "BC234";
	my $description = "This component is a test";
	my $cat_id = 1;
	my $image_id = 1;

	before all => sub {
		# Load configuration.
		$config = Config::Tiny->read("config/testing.conf");

		# Open the database connection.
		$dbh = DBI->connect("dbi:SQLite:dbname=$config->{database}->{name}",
							"", "", { AutoCommit => 1, RaiseError => 1 });
	};

	describe "created" => sub {
		describe "empty" => sub {
			it "should be created" => sub {
				$component = Library::Component->new($dbh);
				is(ref $component, "Library::Component");
			};

			it "should have no ID" => sub {
				is($component->get("id"), undef);
			};

			it "should have no quantity" => sub {
				is($component->get("quantity"), undef);
			};

			it "should have no part number" => sub {
				is($component->get("mpn"), undef);
			};

			it "should fail a save" => sub {
				ok(not $component->save());
			};

			it "should be dirty" => sub {
				ok($component->get("dirty"));
			};

			it "should not exist" => sub {
				ok(not $component->exists());
			};

			after all => sub {
				$component = undef;
			};
		};

		describe "nicely" => sub {
			it "should be created" => sub {
				$component = Library::Component->create($dbh, $quantity, $mpn);
				is(ref $component, "Library::Component");
			};

			it "should have no ID" => sub {
				is($component->get("id"), undef);
			};

			it "should have a matching quantity" => sub {
				is($component->get("quantity"), $quantity);
			};

			it "should have a matching part number" => sub {
				is($component->get("mpn"), $mpn);
			};

			it "should be dirty now" => sub {
				ok($component->get("dirty"));
			};

			it "shouldn't exist since it hasn't been saved yet" => sub {
				ok(not $component->exists());
			};

			it "should save correctly" => sub {
				ok($component->save());
			};

			it "should have an ID" => sub {
				is($component->get("id"), 1);
			};

			it "shouldn't be dirty after the save" => sub {
				ok(not $component->get("dirty"));
			};

			it "should exist" => sub {
				ok($component->exists());
			};

			it "should be able to change the part number" => sub {
				$mpn = "AC123";
				ok($component->set_mpn($mpn));
			};

			it "should be able to set a description" => sub {
				ok($component->set_description($description));
			};

			it "should be able to set a category" => sub {
				ok($component->set_category(id => $cat_id));
			};

			it "should be able to set a image" => sub {
				ok($component->set_image($image_id));
			};

			it "should be able to save changes" => sub {
				ok($component->save());
			};

			after all => sub {
				$component = undef;
			};
		};
	};

	describe "loaded" => sub {
		it "should load nicely" => sub {
			$component = Library::Component->load(dbh => $dbh, mpn => $mpn);
			is(ref $component, "Library::Component");
		};

		it "should have an ID" => sub {
			is($component->get("id"), 1);
		};

		it "shouldn't be dirty" => sub {
			ok(not $component->get("dirty"));
		};

		it "should have a matching quantity" => sub {
			is($component->get("quantity"), $quantity);
		};

		it "should have a matching part number" => sub {
			is($component->get("mpn"), $mpn);
		};

		it "should have a matching description" => sub {
			is($component->get("description"), $description);
		};

		it "should have a matching category" => sub {
			is($component->get("category")->get("id"), $cat_id);
		};

		it "should have a matching image" => sub {
			is($component->get("image")->get("id"), $image_id);
		};

		after all => sub {
			$component = undef;
		};
	};
};

runtests unless caller;
