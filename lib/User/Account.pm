#!/usr/bin/perl

package User::Account;

use strict;
use warnings;

use Carp;
use DBI;
use Try::Tiny;
use Email::Valid;
use Authen::Passphrase::BlowfishCrypt;

# Constructor.
sub new {
	my ($class, $dbh) = @_;
	my $self = {
		_dbh       => $dbh,
		id         => undef,
		email      => undef,
		password   => undef,
		permission => undef,
		dirty      => 1
	};

	bless $self, $class;
	return $self;
}

# Creates a new user.
sub create {
	my ($class, $dbh, $email, $password, $permission) = @_;
	my $self = $class->new($dbh);

	# Set email and password correctly.
	if (not self->set_email($email)) {
		return undef;
	}
	if (not $self->set_password($password)) {
		return undef;
	}

	# Set all the other data.
	$self->{dirty} = 1;
	$self->{permission} = $permission;

	return $self;
}

# Fetch data from the database.
sub load {
	my ($class, %lookup) = @_;
	my $self = $class->new($lookup{dbh});

	# Fetch user data.
	my $user = $self->_fetch_user(%lookup);
	if (defined $user) {
		# Populate the object.
		$self->{id} = $user->{id};
		$self->{email} = $user->{email};
		$self->{password} = $user->{password};
		$self->{permission} = $user->{permission};
	} else {
		# No user found with those parameters.
		return;
	}

	# Set dirtiness and return object.
	$self->{dirty} = 0;
	return $self;
}

# Saves the user data to the database.
sub save {
	my ($self) = @_;
	my $success = 0;

	# Check if all the required parameters are defined.
	foreach my $param ('email', 'password') {
		if (not defined $self->{$param}) {
			carp "Account '$param' was not defined before saving";
			return 0;
		}
	}

	if (defined $self->{id}) {
		# Update user information.
		$success = $self->_update_user();
		$self->{dirty} = not $success;
	} else {
		# Create a new user.
		my $user_id = $self->_add_user();

		# Check if the user was created successfully.
		if (defined $user_id) {
			$self->{id} = $user_id;
			$self->{dirty} = 0;
			$success = 1;
		}
	}

	return $success;
}

# Get a user parameter.
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

# Sets the user email.
sub set_email {
	my ($self, $email) = @_;
	my $old_email = $self->{email};
	$email = lc $email;

	# Check if this is a new or old user.
	if (defined $self->{id}) {
		# Check if we have a failed new user.
		if (not defined $self->{email}) {
			return 0;
		}

		# Looks like we already have this email. Do nothing.
		if ($self->{email} eq $email) {
			return 1;
		}
	}

	# Check if the email is valid
	if (not Email::Valid->address($email)) {
		carp "The supplied email is invalid";
		return 0;
	}

	# Check if the email isn't used by another user.
	if (_user_exists(email => $email)) {
		carp "There is already a user with this email registered";
		return 0;
	}

	# New user email.
	$self->{email} = $email;

	return 1;
}

# Sets the user password.
sub set_password {
	my ($self, $password) = @_;

	# Check password length.
	if (length($password) < 8) {
		carp "Password must be greater than or equal to 8 characters";
		return 0;
	}

	# Check password for uppercase letters.
	if ($password !~ m/[A-Z]/) {
		carp "Password must contain at least 1 uppercase letter";
		return 0;
	}

	# Check password for lowercase letters.
	if ($password !~ m/[a-z]/) {
		carp "Password must contain at least 1 lowercase letter";
		return 0;
	}

	# Check password for numbers.
	if ($password !~ m/[0-9]/) {
		carp "Password must contain at least 1 number";
		return 0;
	}

	# Hash the password.
	my $bcrypt = Authen::Passphrase::BlowfishCrypt->new(
		cost        => 10,
		salt_random => 1,
		passphrase  => $password
	);

	# Password is OK.
	$self->{password} = $bcrypt->as_rfc2307();
	return 1;
}

# Check if a plain-text password matches the hash.
sub check_password {
	my ($self, $password) = @_;

	# No password provided.
	if (not defined $password) {
		carp "No password provided";
		return 0;
	}

	# Password is not yet set. Fail.
	if (not defined $self->{password}) {
		carp "Password not yet defined. Can't check for a match";
		return 0;
	}

	my $success = try {
		# Get the hashed password.
		my $bcrypt = Authen::Passphrase::BlowfishCrypt->from_rfc2307($self->{password});
		return $bcrypt->match($password);
	} catch {
		# Password not hashed or invalid. Try to do a simple comparison.
		return $password eq $self->{password};
	};

	return $success;
}

# Check if this account is valid.
sub exists {
	my ($class, %lookup) = @_;

	# Calling as a static method.
	if (not ref $class) {
		if (defined $lookup{id}) {
			# Lookup the user by ID.
			my $sth = $lookup{dbh}->prepare("SELECT id FROM Users WHERE id = ?");
			$sth->execute($lookup{id});

			if (defined $sth->fetchrow_arrayref()) {
				return 1;
				}
		} elsif (defined $lookup{email}) {
			# Lookup the user by email.
			my $sth = $lookup{dbh}->prepare("SELECT id FROM Users WHERE email = ?");
			$sth->execute($lookup{email});

			if (defined $sth->fetchrow_arrayref()) {
				return 1;
			}
		}
	} else {
		# Calling as a object method.
		return not $class->{dirty};
	}

	# User wasn't found.
	return 0;
}

# Fetches the user data from the database.
sub _fetch_user {
	my ($self, %lookup) = @_;

	if (defined $lookup{id}) {
		# Lookup the user by ID.
		my $sth = $self->{_dbh}->prepare("SELECT * FROM Users WHERE id = ?");
		$sth->execute($lookup{id});

		return $sth->fetchrow_hashref();
	} elsif (defined $lookup{email}) {
		# Lookup the user by email.
		my $sth = $self->{_dbh}->prepare("SELECT * FROM Users WHERE email = ?");
		$sth->execute($lookup{email});

		return $sth->fetchrow_hashref();
	} else {
		carp "No 'id' or 'email' field found in %lookup";
	}

	return;
}

sub _update_user {
	...
}

sub _add_user {
	...
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
  my $account = User::Account->load(dbh => $dbh, password => "P@ss1234");
  print $account->get("email");

=head1 METHODS

=over 4

=item I<$account> = C<User::Account>->C<new>(I<$dbh>)

Initializes an empty user account object.

=item I<$account> = C<User::Account>->C<create>(I<$dbh>, I<$email>, I<$password>,
I<$permission>)

Creates a new user with I<$email> and I<$password> already checked for validity.
The I<$permission> works kinda like UNIX, 7 is R/W and 6 is just R. B<Remember>
to call <I<$account>->C<save>() to actually save the user to the database.

=item I<$account> = C<User::Account>->C<load>(I<%lookup>)

Loads the user account object with data from the database given a database
handler (I<dbh>), and a email (I<email>) or user ID (I<id>) in the I<%lookup>
argument.

=item I<$status> = I<$account>->C<save>()

Saves the user account data to the database. If the operation is successful,
this will return C<1>.

=item I<$data> = I<$account>->C<get>(I<$param>)

Retrieves the value of I<$param> from the account object.

=item I<$success> = I<$account>->C<set_email>(I<$email>)

Sets the user account email and returns C<1> if the email is valid and is not
associated with another account. B<Remember> to call C<save()> to commit these
changes to the database.

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

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut
