#!/usr/bin/perl

package PartCat::WebApplication;

use strict;
use warnings;

use DBI;
use Dancer2;
use Dancer2::Plugin::REST;
use Config::Tiny;

use User::Account;

# Let the user choose which format it wants the response in.
prepare_serializer_for_format;

# Stuff required to be done before each request.
hook before => sub {
	var config => Config::Tiny->read("config/testing.conf");
	var dbh => DBI->connect("dbi:SQLite:dbname=" . vars->{config}->{database}->{name},
							"", "", { AutoCommit => 1 });

	# TODO: Check for a authentication header.
};

# Root path.
get "/" => sub {
	return "It works!";
};

# List users.
get "/user/list.:format" => sub {
	my @user_refs;

	# Grab a user list and create their references.
	my @users = User::Account->list(dbh => vars->{dbh});
	for my $user (@users) {
		push @user_refs, $user->as_hashref(pass_hidden => 1);
	}

	# Return the data.
	return {
		list => \@user_refs,
		count => scalar @user_refs
	};
};

start;

__END__

=head1 NAME

PartCat::WebApplication - PartCat web application.

=head1 SYNOPSIS

  # Initialize the server.
  $ plackup -r -R lib bin/WebApplication.psgi

=head1 API ENDPOINTS

=over 4

=item C</user/list>

Lists all the users available.

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut
