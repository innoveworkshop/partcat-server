#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Test::Spec;
use Config::Tiny;

use User::Account;

describe "A user" => sub {
	my $dbh;
	my $config;

	before all => sub {
		# Load configuration.
		$config = Config::Tiny->read("config/testing.conf");

		# Open the database connection.
		$dbh = DBI->connect("dbi:SQLite:dbname=../$config->{database}->{name}",
							"", "", { AutoCommit => 1 });
	};

	describe "created" => sub {
		describe "empty" => sub {
			my $account;

			before all => sub {
				$account = User::Account->new($dbh);
			};

			it "should have no email" => sub {
				is($account->get("email"), undef);
			};

			it "should have no password" => sub {
				is($account->get("password"), undef);
			};

			it "should have no permissions" => sub {
				is($account->get("permissions"), undef);
			};

			it "should be dirty" => sub {
				ok($account->get("dirty"));
			};

			it "should not exist" => sub {
				ok(not $account->exists());
			};
		};
	};
};

runtests unless caller;
