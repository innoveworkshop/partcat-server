#!/usr/bin/perl

package Library::Component::Parameters;

use strict;
use warnings;

use Carp;
use JSON::MaybeXS;

# Constructor.
sub new {
	my ($class, $text) = @_;
	my $self = {
		text => $text,
		json => undef,
		data => undef
	};

	bless $self, $class;

	# Check if text was defined and parse it.
	if (defined $text) {
		$self->parse($text);
	}

	return $self;
}

# Parses the parameters.
sub parse {
	my ($self, $text) = @_;

	if (defined $text) {
		# Set text and decode the JSON.
		$self->{text} = $text;
		$self->{json} = JSON::MaybeXS->new(utf8 => 1);
		$self->{data} = $self->{json}->decode($text);
	}
}

# Gets a list of available parameters.
sub list {
	my ($self) = @_;

	if (defined $self->{data}) {
		my @names = sort keys %{$self->{data}};
		return \@names;
	}

	return;
}

# Get a specific parameter.
sub get {
	my ($self, $name) = @_;

	if (defined $self->{data}) {
		return $self->{data}->{$name};
	}

	return;
}

# Returns the parameters as text.
sub as_text {
	my ($self) = @_;

	if (defined $self->{data}) {
		$self->{text} = $self->{json}->encode($self->{data});
		return $self->{text};
	}

	return;
}

1;

__END__

=head1 NAME

Library::Component::Parameters - Abstraction layer to interact with component parameters.

=head1 SYNOPSIS

  # Get the JSON text from the database.
  my $json_text = ...;

  # Create a component
  my $component = Library::Component::Parameters->new();
  $component->parse($json_text);

  # Get new JSON encoded as text to put in the database.
  my $text = $component->as_text;
  print "$text\n";

=head1 METHODS

=over 4

=item I<$params> = C<Library::Component::Parameters>->C<new>([I<$text>])

Initializes an empty component parameters object or a populated one if the
optional JSON text (I<$text>) parameter is supplied.

=item I<$params>->C<parse>(I<$text>)

Parses a JSON text (I<$text>) and populates the class with its contents.

=item I<\@names> = I<$params>->C<list>

Returns a array reference of all the available parameters.

=item I<$param> = I<$params>->C<get>(I<$name>)

Returns a parameter data (could be a string, number, array reference, hash
reference, etc.) given a I<$name>.

=item I<$json_text> = I<$params>->C<as_text>

Returns an encoded JSON string of the parameters.

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut
