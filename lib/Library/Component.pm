#!/usr/bin/perl

package Library::Component;

use strict;
use warnings;

use Carp;
use DBI;

use Library::Category;
use Library::Component::Parameters;

# Constructor.
sub new {
	my ($class, $dbh) = @_;
	my $self = {
		_dbh        => $dbh,
		id          => undef,
		quantity    => undef,
		mpn         => undef,
		category    => Library::Category->new($dbh),
		image       => undef, #Library::Image->new($dbh),
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

# Fetch data from the database.
sub load {
	my ($class, %lookup) = @_;
	my $self = $class->new($lookup{dbh});

	# Fetch component data.
	my $component = $self->_fetch_component(%lookup);
	if (defined $component) {
		# Populate the object.
		$self->{id} = $component->{id};
		$self->{quantity} = $component->{quantity};
		$self->{mpn} = $component->{mpn};
		$self->{description} = $component->{description};
		$self->{parameters}->parse($component->{parameters});

		# Populate the category object.
		if (defined $component->{cat_id}) {
			my $category = Library::Category->load(
				dbh => $lookup{dbh},
				id => $component->{cat_id});
			$self->{category} = $category;

			if (not defined $category) {
				carp "Couldn't find the category for this component by the ID "
					. $component->{cat_id};
				return;
			}
		}

		# Populate the image object.
		if (defined $component->{image_id}) {
			# TODO: Implement a image class.
			...
		}

		# Populate the parameters object.
		if (defined $component->{parameters}) {
			# TODO: Implement a parameters class.
		}

		# Set dirtiness and return.
		$self->{dirty} = 0;
		return $self;
	}
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

	# Propagate changes to inherited parameters.
	if (not $self->{category}->save()) {
		carp "Couldn't save the category object";
		return 0;
	}
	if ($self->{image}->save()) {
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
	...
}

# Sets a component part number.
sub set_mpn {
	...
}

# Sets a component category.
sub set_category {
	...
}

# Sets a component image.
sub set_image {
	...
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
		$sth->execute($lookup{email});

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
	if (not Library::Component->exists(dbh => $self->{_dbh}, id => $self->{id})) {
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
	if (User::Account->exists(dbh => $self->{_dbh}, mpn => $self->{mpn})) {
		carp "Component part number already exists";
		return;
	}

	# Add the new user to the database.
	my $sth = $self->{_dbh}->prepare("INSERT INTO Users(email, password,
                                      permission) VALUES (?, ?, ?)");
	if ($sth->execute($self->{email}, $self->{password}, $self->{permission})) {
		# Get the user ID from the last insert operation.
		return $self->{_dbh}->last_insert_id(undef, undef, 'users', 'id');
	}
}

1;

__END__

=head1 NAME

User::Account - Abstraction layer to represent a user of the system.

=head1 SYNOPSIS

  # Create a database handler.
  my $dbh = DBI->connect(...);

  # Creating a new user.
  my $account = User::Account->create($dbh, "email@test.com", "password", 7);
  $account->save();

  # Loading an existing user from the database.
  my $account = User::Account->load(dbh => $dbh, email => "email@test.com");
  my $account = User::Account->load(dbh => $dbh, id => 123);
  print $account->get("email");

=head1 METHODS

=over 4

=item I<$account> = C<User::Account>->C<new>(I<$dbh>)

Initializes an empty user account object using a database handler I<$dbh>.

=item I<$account> = C<User::Account>->C<create>(I<$dbh>, I<$email>, I<$password>,
I<$permission>)

Creates a new user with I<$email> and I<$password> already checked for validity.
The I<$permission> works kinda like UNIX, 7 is R/W and 6 is just R. B<Remember>
to call I<$account>->C<save>() to actually save the user to the database.

=item I<$account> = C<User::Account>->C<load>(I<%lookup>)

Loads the user account object with data from the database given a database
handler (I<dbh>), and a email (I<email>) or user ID (I<id>) in the I<%lookup>
argument.

=item I<$status> = I<$account>->C<save>()

Saves the user account data to the database. If the operation is successful,
this will return C<1>.

=item I<$data> = I<$account>->C<get>(I<$param>)

Retrieves the value of I<$param> from the account object.

=item I<$success> = I<$account>->C<set_email>(I<$email>[, I<$nocheck>])

Sets the user account email and returns C<1> if the email is valid and is not
associated with another account. B<Remember> to call C<save()> to commit these
changes to the database.

If you don't want this function to check if the email already exists in the
database, just set the I<$nocheck> argument to C<1>.

=item I<$success> = I<$account>->C<set_password>(I<$password>)

Sets the user account password and returns C<1> if the password is valid.
B<Remember> to call C<save()> to commit these changes to the database.

=item I<$correct> = I<$account>->C<check_password>(I<$password>)

Check if a plain-text password matches the stored hash and returns C<1> if they
match.

=item I<$valid> = I<$account>->C<exists>(I<%lookup>)

Checks if this account exists and if it is valid and can be used in other
objects. In other words: Has a user ID defined in the database and has not been
edited without being saved.

If called statically the I<%lookup> argument is used to check in the database.
It should contain a I<dbh> parameter and a I<email> B<or> I<id>.

=back

=head1 PRIVATE METHODS

=over 4

=item I<\%data> = I<$self>->C<_fetch_user>(I<%lookup>)

Fetches user data from the database given a user ID (I<id>) or email (I<email>)
passed in the I<%lookup> argument.

=item I<$success> = I<$self>->C<_update_user>()

Updates the user data in the database with the values from the object and
returns 1 if the operation was successful.

=item I<$user_id> = I<$self>->C<_add_user>()

Creates a new user inside the database with the values from the object and
returns the user ID if everything went fine.

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut
