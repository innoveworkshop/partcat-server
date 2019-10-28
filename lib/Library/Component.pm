#!/usr/bin/perl

package Library::Component;

use strict;
use warnings;

use Carp;
use DBI;
use Scalar::Util qw(looks_like_number);

use Library::Category;
use Library::Component::Parameters;
use Library::Component::Image;

# Constructor.
sub new {
	my ($class, $dbh) = @_;
	my $self = {
		_dbh        => $dbh,
		id          => undef,
		quantity    => undef,
		mpn         => undef,
		category    => Library::Category->new($dbh),
		image       => Library::Component::Image->new($dbh),
		description => undef,
		parameters  => Library::Component::Parameters->new,
		dirty       => 1
	};

	bless $self, $class;
	return $self;
}

# Creates a new component.
sub create {
	my ($class, $dbh, $quantity, $mpn) = @_;
	my $self = $class->new($dbh);

	# Set quantity and mpn correctly.
	if (not $self->set_quantity($quantity)) {
		return;
	}
	if (not $self->set_mpn($mpn)) {
		return;
	}

	# Set dirtiness and return the object.
	$self->{dirty} = 1;
	return $self;
}

# Lists all the components available.
sub list {
	my ($class, %opts) = @_;
	my @components;

	# Select all the rows and query the database.
	my $sth = $opts{dbh}->prepare("SELECT * FROM Inventory");
	$sth->execute();

	# Loop through the rows.
	while (my $row = $sth->fetchrow_hashref()) {
		my $self = $class->new($opts{dbh});
		$self->_populate($row);

		push @components, $self;
	}

	return @components;
}

# Fetch data from the database.
sub load {
	my ($class, %lookup) = @_;
	my $self = $class->new($lookup{dbh});

	# Fetch component data.
	my $component = $self->_fetch_component(%lookup);
	if (defined $component) {
		# Populate the object.
		$self->_populate($component);

		# Set dirtiness and return.
		$self->{dirty} = 0;
		return $self;
	}

	return;
}

# Saves the component data to the database.
sub save {
	my ($self) = @_;
	my $success = 0;

	# Check if all the required parameters are defined.
	foreach my $param ("quantity", "mpn") {
		if (not defined $self->{$param}) {
			carp "Component '$param' was not defined before saving";
			return 0;
		}
	}

	# Propagate changes to category.
	if ((not $self->{category}->save()) and
			(defined $self->{category}->get("id"))) {
		carp "Couldn't save the category object";
		return 0;
	}

	# Propagate changes to image.
	if ((not $self->{image}->save()) and (defined $self->{image}->get("id"))) {
		carp "Couldn't save the image object";
		return 0;
	}

	if (defined $self->{id}) {
		# Update component information.
		$success = $self->_update_component();
		$self->{dirty} = not $success;
	} else {
		# Create a new component.
		my $component_id = $self->_add_component();

		# Check if the component was created successfully.
		if (defined $component_id) {
			$self->{id} = $component_id;
			$self->{dirty} = 0;
			$success = 1;
		}
	}

	return $success;
}

# Deletes a component.
sub delete {
	my ($self) = @_;

	my $sth = $self->{_dbh}->prepare("DELETE FROM Inventory WHERE id = ?");
	return defined $sth->execute($self->{id});
}

# Get a component object parameter.
sub get {
	my ($self, $param) = @_;

	if (defined $self->{$param}) {
		# Check if it is a private parameter.
		if ($param =~ m/^_.+/) {
			return;
		}

		# Valid and defined parameter.
		return $self->{$param};
	}

	return;
}

# Sets a component quantity.
sub set_quantity {
	my ($self, $quantity) = @_;

	# Check if quantity is a number.
	if (looks_like_number($quantity)) {
		$self->{quantity} = $quantity + 0;
		$self->{dirty} = 1;

		return 1;
	}

	return 0;
}

# Sets a component part number.
sub set_mpn {
	my ($self, $mpn, $nocheck) = @_;

	# Check if the component already exists in the database.
	if ((not Library::Component->exists(dbh => $self->{_dbh}, mpn => $mpn)) || $nocheck) {
		$self->{mpn} = $mpn;
		$self->{dirty} = 1;

		return 1;
	}

	return 0;
}

# Sets a component description.
sub set_description {
	my ($self, $description) = @_;

	$self->{description} = $description;
	$self->{dirty} = 1;

	return 1;
}

# Sets a component category.
sub set_category {
	my ($self, %lookup) = @_;

	# Load the category and check if it's valid before using it.
	my $cat = Library::Category->load(dbh => $self->{_dbh}, %lookup);
	if (defined $cat) {
		$self->{category} = $cat;
		$self->{dirty} = 1;
		return 1;
	}

	return 0;
}

# Sets a component image.
sub set_image {
	my ($self, $image_id) = @_;

	$self->{dirty} = 1;
	$self->{image} = Library::Component::Image->load(dbh => $self->{_dbh},
													 id => $image_id);

	return defined $self->{image};
}

# Sets a component parameters.
sub set_parameters {
	my ($self, %params) = @_;
	$self->{parameters}->set(%params);
}

# Check if this component is valid.
sub exists {
	my ($class, %lookup) = @_;

	# Check type of call.
	if (not ref $class) {
		# Calling as a static method.
		if (not defined $lookup{dbh}) {
			croak "A database handler wasn't defined";
		}

		if (defined $lookup{id}) {
			# Lookup the component by ID.
			my $sth = $lookup{dbh}->prepare("SELECT id FROM Inventory WHERE id = ?");
			$sth->execute($lookup{id});

			if (defined $sth->fetchrow_arrayref()) {
				return 1;
			}
		} elsif (defined $lookup{mpn}) {
			# Lookup the component by MPN.
			my $sth = $lookup{dbh}->prepare("SELECT id FROM Inventory WHERE mpn = ?");
			$sth->execute($lookup{email});

			if (defined $sth->fetchrow_arrayref()) {
				return 1;
			}
		}
	} else {
		# Calling as a object method.
		return not $class->{dirty};
	}

	# Component wasn't found.
	return 0;
}

# Returns this object as a hash reference for serialization.
sub as_hashref {
	my ($self, %opts) = @_;
	my $obj = {
		id => $self->{id},
		quantity =>  $self->{quantity},
		mpn => $self->{mpn},
		category => $self->{category}->as_hashref,
		description => $self->{description},
		parameters => $self->{parameters}->as_hashref,
		image => $self->{image}->as_hashref
	};

	return $obj;
}

# Populate the object.
sub _populate {
	my ($self, $row) = @_;

	# Populate the usual part of the object.
	$self->{id} = $row->{id};
	$self->{quantity} = $row->{quantity};
	$self->{mpn} = $row->{mpn};
	$self->{description} = $row->{description};
	$self->{parameters}->parse($row->{parameters});
	$self->{image} = Library::Component::Image->load(dbh => $self->{_dbh},
													 id => $row->{image_id});

	# Populate the category object.
	if (defined $row->{cat_id}) {
		my $category = Library::Category->load(dbh => $self->{_dbh},
											   id => $row->{cat_id});

		$self->{category} = $category;
		if (not defined $category) {
			carp "Couldn't find the category for this component by the ID "
				. $row->{cat_id};
			return;
		}
	}
}

# Fetches the component data from the database.
sub _fetch_component {
	my ($self, %lookup) = @_;

	if (defined $lookup{id}) {
		# Lookup the component by ID.
		my $sth = $self->{_dbh}->prepare("SELECT * FROM Inventory WHERE id = ?");
		$sth->execute($lookup{id});

		return $sth->fetchrow_hashref();
	} elsif (defined $lookup{mpn}) {
		# Lookup the component by part number.
		my $sth = $self->{_dbh}->prepare("SELECT * FROM Inventory WHERE mpn = ?");
		$sth->execute($lookup{mpn});

		return $sth->fetchrow_hashref();
	} else {
		carp "No 'id' or 'mpn' field found in %lookup";
	}

	return;
}

# Update a component in the database.
sub _update_component {
	my ($self) = @_;

	# Check if component exists.
	if (not Library::Component->exists(dbh => $self->{_dbh},
									   id => $self->{id})) {
		carp "Can't update a component that doesn't exist";
		return 0;
	}

	# Update the component information.
	my $sth = $self->{_dbh}->prepare("UPDATE inventory SET quantity = ?, mpn = ?,
                                     cat_id = ?, image_id = ?, description = ?,
                                     parameters = ? WHERE id = ?");
	if ($sth->execute($self->{quantity}, $self->{mpn}, $self->{category}->{id},
					  $self->{image}->{id}, $self->{description},
					  $self->{parameters}->as_text, $self->{id})) {
		return 1;
	}

	return 0;
}

# Adds a new component to the database.
sub _add_component {
	my ($self) = @_;

	# Check if the part number already exists.
	if (Library::Component->exists(dbh => $self->{_dbh}, mpn => $self->{mpn})) {
		carp "Component part number already exists";
		return;
	}

	# Add the new component to the database.
	my $sth = $self->{_dbh}->prepare("INSERT INTO Inventory(quantity, mpn,
                                     cat_id, image_id, description, parameters)
                                     VALUES (?, ?, ?, ?, ?, ?)");
	if ($sth->execute($self->{quantity}, $self->{mpn}, $self->{category}->{id},
					  $self->{image}->{id}, $self->{description},
					  $self->{parameters}->as_text)) {
		# Get the component ID from the last insert operation.
		return $self->{_dbh}->last_insert_id(undef, undef, 'inventory', 'id');
	}
}

1;

__END__

=head1 NAME

Library::Component - Abstraction layer to represent a component.

=head1 SYNOPSIS

  # Create a database handler.
  my $dbh = DBI->connect(...);

  # Creating a new component.
  my $quantity = 123;
  my $mpn = "BC234";
  my $component = Library::Component->create($dbh, $quantity, $mpn);
  $component->save();

  # Loading an existing component from the database.
  my $component = Library::Component->load(dbh => $dbh, mpn => $mpn);
  my $component = Library::Component->load(dbh => $dbh, id => 432);
  print $component->get("mpn");

  # Get a list of components.
  my @list = Library::Component->list(dbh => $dbh);

=head1 METHODS

=over 4

=item I<$component> = C<Library::Component>->C<new>(I<$dbh>)

Initializes an empty component object using a database handler I<$dbh>.

=item I<$component> = C<Library::Component>->C<create>(I<$dbh>, I<quantity>,
I<$mpn>)

Creates a new component with I<$quantity> and I<$mpn> already checked for
validity.

=item I<@list> = C<Library::Component>->C<list>(I<%opts>)

Returns a list of all the available components in the database as a I<@list> of
objects. This function requires a database handler as I<dbh>.

=item I<$component> = C<Library::Component>->C<load>(I<%lookup>)

Loads the component object with data from the database given a database handler
(I<dbh>), and a mpn (I<mpn>) or ID (I<id>) in the I<%lookup> argument.

=item I<$status> = I<$component>->C<save>()

Saves the component data to the database. If the operation is successful, this
will return C<1>.

=item I<$component>->C<delete>()

Deletes the current component from the database.

=item I<$data> = I<$component>->C<get>(I<$param>)

Retrieves the value of I<$param> from the component object.

=item I<$success> = I<$component>->C<set_quantity>(I<$quantity>)

Sets the component quantity and returns C<1> if it's valid. B<Remember> to call
C<save()> to commit these changes to the database.

=item I<$success> = I<$component>->C<set_mpn>(I<$mpn>[, I<$nocheck>])

Sets the component part number and returns C<1> if it's valid and is not
associated with another component. If you want to skip the checks, just set the
I<$nocheck> argument to C<1>. B<Remember> to call C<save()> to commit these
changes to the database.

=item I<$success> = I<$component>->C<set_description>(I<$description>)

Sets the component description and returns C<1> if it's valid. B<Remember> to
call C<save()> to commit these changes to the database.

=item I<$success> = I<$component>->C<set_category>(I<%lookup>)

Sets the component category using either I<id> or I<name> in the I<%lookup>
parameter and returns C<1> if it's valid. B<Remember> to call C<save()> to
commit these changes to the database.

=item I<$success> = I<$component>->C<set_image>(I<$image_id>)

Sets the component image using a image ID (I<$image_id>) and returns C<1> if
it's valid. B<Remember> to call C<save()> to commit these changes to the
database.

=item I<$component>->C<set_parameters>(I<%params>)

Sets some component parameters using the I<%params> hash.

=item I<$valid> = I<$component>->C<exists>(I<%lookup>)

Checks if this component exists and if it is valid and can be used in other
objects. In other words: Has a component ID defined in the database and has not
been edited without being saved.

If called statically the I<%lookup> argument is used to check in the database.
It should contain a I<dbh> parameter and a I<mpn> B<or> I<id>.

=item I<\%cat> = I<$category>->C<as_hashref>

Returns a hash reference of this object. Perfect for serialization.

=back

=head1 PRIVATE METHODS

=over 4

=item I<$self>->C<_populate(I<$row>)

Populates the object with a I<$row> directly from the database.

=item I<\%data> = I<$self>->C<_fetch_component>(I<%lookup>)

Fetches component data from the database given a component I<id> B<or> I<mpn>
passed in the I<%lookup> argument.

=item I<$success> = I<$self>->C<_update_component>()

Updates the component data in the database with the values from the object and
returns C<1> if the operation was successful.

=item I<$component_id> = I<$self>->C<_add_component>()

Creates a new component inside the database with the values from the object and
returns the component ID if everything went fine.

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut
