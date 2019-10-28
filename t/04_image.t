#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Test::Spec;
use Config::Tiny;

use Library::Component::Image;

describe "A image" => sub {
	my $dbh;
	my $config;

	my $image;
	my $image_id;
	my $name = "TO-92";
	my $path = "test.png";

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
				$image = Library::Component::Image->new($dbh, $config);
				is(ref $image, "Library::Component::Image");
			};

			it "should have no ID" => sub {
				is($image->get("id"), undef);
			};

			it "should have no name" => sub {
				is($image->get("name"), undef);
			};

			it "should have no path" => sub {
				is($image->get("path"), undef);
			};

			it "should fail a save" => sub {
				ok(not $image->save());
			};

			it "should be dirty" => sub {
				ok($image->{dirty});
			};

			after all => sub {
				$image = undef;
			};
		};

		describe "nicely" => sub {
			it "should be created" => sub {
				$image = Library::Component::Image->create($dbh, $config, $name,
														   $path);
				is(ref $image, "Library::Component::Image");
			};

			it "should have a matching name" => sub {
				is($image->get("name"), $name);
			};

			it "should have a matching path" => sub {
				is($image->get("path"), $path);
			};

			it "should be dirty" => sub {
				ok($image->{dirty});
			};

			it "should save correctly" => sub {
				ok($image->save());
			};

			it "should not be dirty anymore" => sub {
				ok(not $image->{dirty});
			};

			it "should have an ID" => sub {
				$image_id = $image->get("id");
				is($image_id, 1);
			};

			after all => sub {
				$image = undef;
			};
		};
	};

	describe "loaded" => sub {
		it "should load" => sub {
			$image = Library::Component::Image->load(dbh => $dbh,
													 config => $config,
													 id => $image_id);
			is(ref $image, "Library::Component::Image");
		};

		it "should have a matching name" => sub {
			is($image->get("name"), $name);
		};

		it "should have a matching path" => sub {
			is($image->get("path"), $path);
		};

		it "should not be dirty" => sub {
			ok(not $image->{dirty});
		};

		after all => sub {
			$image = undef;
		};
	};
};

runtests unless caller;
