#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Test::Spec;
use Config::Tiny;

use Library::Category;

describe "A category" => sub {
	my $dbh;
	my $config;

	my $category;
	my $name = "Transistors";

	before all => sub {
		# Load configuration.
		$config = Config::Tiny->read("config/testing.conf");

		# Open the database connection.
		$dbh = DBI->connect("dbi:SQLite:dbname=$config->{database}->{name}",
							"", "", { AutoCommit => 1 });
	};

	describe "created" => sub {
		describe "empty" => sub {
			it "should be created" => sub {
				$category = Library::Category->new($dbh);
				is(ref $category, "Library::Category");
			};

			it "shouldn't have an ID" => sub {
				is($category->get("id"), undef);
			};

			it "should have no name" => sub {
				is($category->get("name"), undef);
			};

			it "should exist" => sub {
				ok($category->exists());
			};

			after all => sub {
				$category = undef;
			};
		};

		describe "nicely" => sub {
			it "should be created" => sub {
				$category = Library::Category->create($dbh, $name);
				is(ref $category, "Library::Category");
			};

			it "shouldn't have an ID" => sub {
				is($category->get("id"), undef);
			};

			it "should have a matching name" => sub {
				is($category->get("name"), $name);
			};

			it "should exist" => sub {
				ok($category->exists());
			};

			it "should save correctly" => sub {
				ok($category->save());
			};

			it "should have an ID" => sub {
				is($category->get("id"), 1);
			};

			it "should be able to change the name" => sub {
				$name = "Integrated Circuits";
				ok($category->set_name($name));
			};

			it "should be able to save changes" => sub {
				ok($category->save());
			};

			after all => sub {
				$category = undef;
			};
		};
	};

	describe "loaded" => sub {
		it "should load nicely" => sub {
			$category = Library::Category->load(dbh => $dbh, name => $name);
			is(ref $category, "Library::Category");
		};

		it "should have an ID" => sub {
			is($category->get("id"), 1);
		};

		it "should have a matching name" => sub {
			is($category->get("name"), $name);
		};
	};
};

runtests unless caller;
