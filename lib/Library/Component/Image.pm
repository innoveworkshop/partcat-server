#!/usr/bin/perl

package Library::Component::Image;

use strict;
use warnings;

use Carp;
use DBI;

# Constructor.
sub new {
	my ($class, $dbh, $id) = @_;
	my $self = {
		_dbh => $dbh,
		id   => undef,
		name => undef,
		path => undef
	};

	bless $self, $class;

	# Check if the loading worked.
	if (defined($id) && (not $self->load($id))) {
		return;
	}

	return $self;
}

# Populates the object with data from the database.
sub load {
	my ($self, $id) = @_;

	if (defined $id) {
		# TODO: Implement this.
		$self->{id} = $id;
		return 1;
	}

	return 0;
}

1;

__END__

=head1 NAME

Library::Component::Image - Abstraction layer to interact with component images.

=head1 SYNOPSIS

  # Create a database handler.
  my $dbh = DBI->connect(...);

  # Create an empty image object.
  my $image = Library::Component::Image->new($dbh);

  # Load a image.
  my $id = 123;
  $image = Library::Component::Image->new($dbh, $id);

=head1 METHODS

=over 4

=item I<$image> = C<Library::Component::Image>->C<new>(I<$dbh>[, I<$id>])

Initializes an empty image object or a populated one if the optional I<$id>
parameter is supplied.

=item I<$status> = I<$image>->C<load>(I<$id>)

Populates the image object with data from the database. Returns C<1> if the
operation was successful.

=back

=head1 PRIVATE METHODS

=over 4

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut
