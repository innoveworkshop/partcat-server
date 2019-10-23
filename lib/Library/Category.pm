#!/usr/bin/perl

package Library::Category;

use strict;
use warnings;

use Carp;
use DBI;

# Constructor.
sub new {
	my ($class, $dbh, $id, $name) = @_;
	my $self = {
		_dbh => $dbh,
		id   => $id,
		name => $name,
	};

	bless $self, $class;
	return $self;
}

# Creates a new category.
sub create {
	my ($class, $dbh, $name) = @_;
	my $self = $class->new($dbh);

	# Set name correctly.
	if (not $self->set_name($name)) {
		return;
	}

	return $self;
}

# Fetch category data from the database.
sub load {
	my ($class, %lookup) = @_;
	my $self = $class->new($lookup{dbh});

	# Fetch category data.
	my $category = $self->_fetch_category(%lookup);
	if (defined $category) {
		# Populate the object.
		$self->{id} = $category->{id};
		$self->{name} = $category->{name};

		return $self;
	}
}

# Saves the category to the database.
sub save {
	my ($self) = @_;
	my $success = 0;

	# Check if all the required parameters are defined.
	foreach my $param ("name") {
		if (not defined $self->{$param}) {
			carp "Category '$param' was not defined before saving";
			return 0;
		}
	}

	if (defined $self->{id}) {
		# Update category information.
		$success = $self->_update_category();
	} else {
		# Create a new category.
		my $cat_id = $self->_add_category();

		# Check if the category was created successfully.
		if (defined $cat_id) {
			$self->{id} = $cat_id;
			$success = 1;
		}
	}

	return $success;
}

# Get a category parameter.
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

# Sets the category name.
sub set_name {
	my ($self, $name, $nocheck) = @_;
	my $old_name = $self->{name};

	# Check if this is a new or old category.
	if (defined $self->{id}) {
		# Check if we have a failed new category.
		if (not defined $self->{name}) {
			return 0;
		}

		# Looks like we already have this category. Do nothing.
		if ($self->{name} eq $name) {
			return 1;
		}
	}

	# Check if the category isn't used by another user.
	if ((defined $nocheck) && (not $nocheck)) {
		if (Library::Category->exists(dbh => $self->{_dbh}, name => $name)) {
			carp "There is already a category with this name registered";
			return 0;
		}
	}

	# New category name.
	$self->{name} = $name;
	return 1;
}

# Check if this category is valid.
sub exists {
	my ($class, %lookup) = @_;

	# Check type of call.
	if (not ref $class) {
		# Calling as a static method.
		if (not defined $lookup{dbh}) {
			croak "A database handler wasn't defined";
		}

		if (defined $lookup{id}) {
			# Lookup the category by ID.
			my $sth = $lookup{dbh}->prepare("SELECT id FROM Categories WHERE id = ?");
			$sth->execute($lookup{id});

			if (defined $sth->fetchrow_arrayref()) {
				return 1;
			}
		} elsif (defined $lookup{name}) {
			# Lookup the user by name.
			my $sth = $lookup{dbh}->prepare("SELECT id FROM Categories WHERE name = ?");
			$sth->execute($lookup{name});

			if (defined $sth->fetchrow_arrayref()) {
				return 1;
			}
		}
	} else {
		# Calling as a object method.
		return 1;
	}

	# Category wasn't found.
	return 0;
}

# List all the categories available.
sub list {
	my ($class, $dbh) = @_;
	my @categories;

	# Fetch all the categories and populate the list with objects.
	my $cats = $dbh->selectall_arrayref("SELECT * FROM Categories ORDER BY name ASC");
	for my $cat (@{$cats}) {
		push @categories, Library::Category->new($dbh, $cat->{id}, $cat->{name});
	}

	return @categories;
}

# Fetches the category data from the database.
sub _fetch_category {
	my ($self, %lookup) = @_;

	if (defined $lookup{id}) {
		# Lookup by ID.
		my $sth = $self->{_dbh}->prepare("SELECT * FROM Categories WHERE id = ?");
		$sth->execute($lookup{id});

		return $sth->fetchrow_hashref();
	} elsif (defined $lookup{name}) {
		# Lookup by name.
		my $sth = $self->{_dbh}->prepare("SELECT * FROM Categories WHERE name = ?");
		$sth->execute($lookup{name});

		return $sth->fetchrow_hashref();
	} else {
		carp "No 'id' or 'name' field found in %lookup";
	}

	return;
}

# Updates the category in the database.
sub _update_category {
	my ($self) = @_;

	# Check if category exists.
	if (not Library::Category->exists(dbh => $self->{_dbh}, id => $self->{id})) {
		carp "Can't update a category that doesn't exist";
		return 0;
	}

	# Update the category information.
	my $sth = $self->{_dbh}->prepare("UPDATE categories SET name = ? WHERE id = ?");
	if ($sth->execute($self->{name}, $self->{id})) {
		return 1;
	}

	return 0;
}

# Adds a new category to the database.
sub _add_category {
	my ($self) = @_;

	# Check if the category name already exists.
	if (Library::Category->exists(dbh => $self->{_dbh}, name => $self->{name})) {
		carp "Category name already exists";
		return;
	}

	# Add the new category to the database.
	my $sth = $self->{_dbh}->prepare("INSERT INTO Categories(name) VALUES (?)");
	if ($sth->execute($self->{name})) {
		# Get the category ID from the last insert operation.
		return $self->{_dbh}->last_insert_id(undef, undef, 'categories', 'id');
	}
}


1;

__END__

=head1 NAME

Library::Category - Abstraction layer to represent a component category.

=head1 SYNOPSIS

  # Create a database handler.
  my $dbh = DBI->connect(...);

  # Creating a new category.
  my $category = Library::Category->create($dbh, "Transistors");
  $category->save();

  # Loading an existing user from the database.
  $category = Library::Category->load(dbh => $dbh, id = 123);
  $category = Library::Category->load(dbh => $dbh, name = "Transistors");
  print $category->get("name");

  # Listing categories available.
  my @categories = Library::Category->list($dbh);

=head1 METHODS

=over 4

=item I<$category> = C<Library::Category>->C<new>(I<$dbh>[, I<$id>, I<$name>])

Initializes an empty category object using a database handler (I<$dbh>).
Parameters I<$id> and I<$name> are optional.

=item I<$category> = C<Library::Category>->C<create>(I<$dbh>, I<$name>)

Creates a new category with I<$name> already checked for validity. B<Remember>
to call I<$category>->C<save>() to actually save the category to the database.

=item I<$category> = C<Library::Category>->C<load>(I<%lookup>)

Loads the category object with data from the database given a database handler
(I<dbh>), and a name (I<name>) or ID (I<id>) in the I<%lookup> argument.

=item I<@categories> = C<Library::Category>->C<list>(I<$dbh>)

Fetches a complete list of category objects from the database sorted
alphabetically.

=item I<$status> = I<$category>->C<save>()

Saves the category data to the database. If the operation is successful, this
will return C<1>.

=item I<$data> = I<$category>->C<get>(I<$param>)

Retrieves the value of I<$param> from the category object.

=item I<$success> = I<$category>->C<set_name>(I<$name>[, I<$nocheck>])

Sets the category name and returns C<1> if the name is not already in the
database. B<Remember> to call C<save()> to commit these changes to the database.

If you don't want this function to check if the name already exists in the
database, just set the I<$nocheck> argument to C<1>.

=item I<$valid> = I<$category>->C<exists>(I<%lookup>)

Checks if this category exists and if it is valid and can be used in other
objects. In other words: Has a ID defined in the database.

If called statically the I<%lookup> argument is used to check in the database.
It should contain a I<dbh> parameter and a I<name> B<or> I<id>.

=back

=head1 PRIVATE METHODS

=over 4

=item I<\%data> = I<$self>->C<_fetch_category>(I<%lookup>)

Fetches category data from the database given a category I<id> B<or> I<name>
passed in the I<%lookup> argument.

=item I<$success> = I<$self>->C<_update_category>()

Updates the category data in the database with the values from the object and
returns C<1> if the operation was successful.

=item I<$category_id> = I<$self>->C<_add_category>()

Creates a new category inside the database with the values from the object and
returns the ID if everything went fine.

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut
