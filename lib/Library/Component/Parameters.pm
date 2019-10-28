#!/usr/bin/perl

package Library::Component::Parameters;

use strict;
use warnings;

use Carp;
use JSON::MaybeXS;
use Try::Tiny;

# Constructor.
sub new {
	my ($class, $text) = @_;
	my $self = {
		text => "{}",
		json => JSON::MaybeXS->new(utf8 => 1),
		data => undef
	};

	# Bless object and parse the JSON text.
	bless $self, $class;
	$self->parse($text);

	return $self;
}

# Parses the parameters.
sub parse {
	my ($self, $text) = @_;

	if (defined $text) {
		# Set text.
		$self->{text} = $text;

		# Check if the text is empty and create a blank object with it.
		if ($text =~ /^\s*$/) {
			$self->{text} = "{}";
		}

		# Try to decode the JSON object.
		try {
			$self->{data} = $self->{json}->decode($self->{text});
		} catch {
			# Clean up.
			$self->{text} = undef;
			$self->{json} = undef;

			carp "An error occured while parsing the component parameters: $_";
		};
	}
}

# Gets a list of available parameters.
sub list {
	my ($self) = @_;

	if (defined $self->{data}) {
		my @names = sort keys %{$self->{data}};

		# Check if the list isn't empty.
		if ((scalar @names) > 0) {
			return \@names;
		}
	}

	return;
}

# Get a specific parameter.
sub get {
	my ($self, $name) = @_;
	return $self->{data}->{$name};
}

# Sets some parameters.
sub set {
	my ($self, %params) = @_;

	for my $name (keys %params) {
		$self->{data}->{$name} = $params{$name};
	}
}

# Returns this object as a hash reference for serialization.
sub as_hashref {
	my ($self, %opts) = @_;
	return $self->{data};
}

# Returns the parameters as text.
sub as_text {
	my ($self) = @_;

	if (defined $self->{data}) {
		$self->{text} = $self->{json}->encode($self->{data});
		return $self->{text};
	}
}

1;

__END__

=head1 NAME

Library::Component::Parameters - Abstraction layer to interact with component parameters.

=head1 SYNOPSIS

  # Get the JSON text from the database.
  my $json_text = ...;

  # Create a component
  my $params = Library::Component::Parameters->new();
  $params->parse($json_text);
  $params->set(Vmax => 12.34, Vbe => 0.65);

  # Get new JSON encoded as text to put in the database.
  my $text = $params->as_text;
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

=item I<$params>->C<set>(I<%params>)

Sets the parameters defined in I<%params>.

=item I<$param> = I<$params>->C<get>(I<$name>)

Returns a parameter data (could be a string, number, array reference, hash
reference, etc.) given a I<$name>.

=item I<\%json> = I<$params>->C<as_hashref>

Returns a hash reference of this object. Perfect for serialization.

=item I<$json_text> = I<$params>->C<as_text>

Returns an encoded JSON string of the parameters.

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut
