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

	my $email = "test\@example.com";
	my $password = "P\@ssword123";
	my $permission = 7;

	before all => sub {
		# Load configuration.
		$config = Config::Tiny->read("config/testing.conf");

		# Open the database connection.
		$dbh = DBI->connect("dbi:SQLite:dbname=$config->{database}->{name}",
							"", "", { AutoCommit => 1 });
	};

	describe "created" => sub {
		my $account;

		describe "empty" => sub {
			it "should be created" => sub {
				$account = User::Account->new($dbh);
				is(ref $account, "User::Account");
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

			after all => sub {
				$account = undef;
			};
		};

		describe "nicely" => sub {
			it "should be created" => sub {
				$account = User::Account->create($dbh,
												 $email, $password,
												 $permission);
				is(ref $account, "User::Account");
			};

			it "should have a matching email" => sub {
				is($account->get("email"), $email);
			};

			it "should have a matching password" => sub {
				ok($account->check_password($password));
			};

			it "should have a matching permission" => sub {
				is($account->get("permission"), $permission);
			};

			it "should be dirty now" => sub {
				ok($account->get("dirty"));
			};

			it "shouldn't exist since it hasn't been saved yet" => sub {
				ok(not $account->exists());
			};

			it "should save correctly" => sub {
				ok($account->save());
			};

			it "shouldn't be dirty after the save" => sub {
				ok(not $account->get("dirty"));
			};

			it "should exist" => sub {
				ok($account->exists());
			};

			it "should be able to change the email" => sub {
				$email = "example\@test.com";
				ok($account->set_email($email));
			};

			it "should be able to save changes" => sub {
				ok($account->save());
			};

			after all => sub {
				$account = undef;
			};
		};
	};

	describe "loaded" => sub {
		my $account;

		it "should load nicely" => sub {
			$account = User::Account->load(dbh => $dbh, email => $email);
			is(ref $account, "User::Account");
		};

		it "shouldn't be dirty" => sub {
			ok(not $account->get("dirty"));
		};

		it "should have a matching email" => sub {
			is($account->get("email"), $email);
		};

		it "should have a matching password" => sub {
			ok($account->check_password($password));
		};

		it "should have a matching permission" => sub {
			is($account->get("permission"), $permission);
		};
	};
};

runtests unless caller;
