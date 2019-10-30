#!/usr/bin/perl

package Library::Component::Image;

use strict;
use warnings;
use autodie;

use Carp;
use DBI;
use URI;
use Config::Tiny;
use File::MimeInfo;
use LWP::UserAgent;

# Constructor.
sub new {
	my ($class, $dbh, $config) = @_;
	my $self = {
		_dbh    => $dbh,
		_config => $config,
		id      => undef,
		name    => undef,
		path    => undef,
		dirty   => 1
	};

	bless $self, $class;
	return $self;
}

# Creates a new image.
sub create {
	my ($class, $dbh, $config, $name, $path, $nocheck) = @_;
	my $self = $class->new($dbh, $config);

	# Set name and path correctly.
	if ((not $self->set_name($name)) or
			(not $self->set_path($path, $nocheck))) {
		return;
	}

	# Set dirtiness and return the object.
	$self->{dirty} = 1;
	return $self;
}

# Lists all the images available.
sub list {
	my ($class, %opts) = @_;
	my @images;

	# Select all the rows and query the database.
	my $sth = $opts{dbh}->prepare("SELECT * FROM Images");
	$sth->execute();

	# Loop through the rows.
	while (my $row = $sth->fetchrow_hashref()) {
		my $self = $class->new($opts{dbh}, $opts{config});
		$self->_populate($row);

		push @images, $self;
	}

	return @images;
}

# Populates the object with data from the database.
sub load {
	my ($class, %lookup) = @_;
	my $self = $class->new($lookup{dbh}, $lookup{config});

	# Check if we have the ID.
	if (not defined $lookup{id}) {
		carp "No 'id' field found in %lookup";
		return;
	}

	# Fetch image data.
	my $image = $self->_fetch_image($lookup{id});
	if (defined $image) {
		# Populate the object.
		$self->_populate($image);

		# Set dirtiness and return.
		$self->{dirty} = 0;
		return $self;
	}
}

# Saves the image data to the database.
sub save {
	my ($self) = @_;
	my $success = 0;

	# Check if all the required parameters are defined.
	foreach my $param ("name", "path") {
		if (not defined $self->{$param}) {
			carp "Image '$param' was not defined before saving";
			return 0;
		}
	}

	if (defined $self->{id}) {
		# Update image information.
		$success = $self->_update_image();
		$self->{dirty} = not $success;
	} else {
		# Create a new image.
		my $image_id = $self->_add_image();

		# Check if the image was created successfully.
		if (defined $image_id) {
			$self->{id} = $image_id;
			$self->{dirty} = 0;
			$success = 1;
		}
	}

	return $success;
}

# Deletes a image.
sub delete {
	my ($self) = @_;

	# Remove the item from the database.
	my $sth = $self->{_dbh}->prepare("DELETE FROM Images WHERE id = ?");
	my $ok = $sth->execute($self->{id});

	# Check if the operation was successful.
	if (defined $ok) {
		# Delete file and check if it did work.
		if (unlink $self->{_config}->{path}->{images} . "/" . $self->{path}) {
			return 1;
		}

		carp "Couldn't remove image file: $!";
	}

	return 0;
}

# Get a image object parameter.
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

# Get the direct path to the image file.
sub direct_path {
	my ($self, $filename, $nocheck) = @_;
	my $path = $self->{_config}->{path}->{images};

	# Check if a filename was specified and use the appropriate one.
	if (not defined $filename) {
		$path = "$path/" . $self->{path};
	} else {
		$path = "$path/$filename";
	}

	# Check the path.
	if (defined $nocheck and not $nocheck) {
		if (-s $path) {
			return $path;
		}
	} else {
		return $path;
	}

	return;
}

# Set the image name.
sub set_name {
	my ($self, $name) = @_;

	# Check if the name is defined and not empty.
	if (defined $name and not ($name =~ /^ *$/)) {
		# Set the image name.
		$self->{name} = $name;

		# Set dirtiness and return.
		$self->{dirty} = 1;
		return 1;
	}

	return 0;
}

# Set the image path.
sub set_path {
	my ($self, $path, $nocheck) = @_;
	my $realpath = $self->direct_path($path, $nocheck);

	# Check if the image file exists.
	if (defined $realpath) {
		# Set image path.
		$self->{path} = $path;

		# Set dirtiness and return.
		$self->{dirty} = 1;
		return 1;
	}

	return 0;
}

# Check if this image is valid.
sub exists {
	my ($class, %lookup) = @_;
	my $dbh;

	# Check type of call.
	if (not ref $class) {
		# Calling as a static method.
		if (not defined $lookup{dbh}) {
			croak "A database handler wasn't defined";
		}

		$dbh = $lookup{dbh};
	} else {
		# Calling as a object method.
		$dbh = $class->{_dbh};

		# Check for dirtiness.
		if ($class->{dirty}) {
			return 0;
		}
	}

	# Lookup the component by ID.
	if (defined $lookup{id}) {
		my $sth = $lookup{dbh}->prepare("SELECT id FROM Images WHERE id = ?");
		$sth->execute($lookup{id});

		if (defined $sth->fetchrow_arrayref()) {
			return 1;
		}
	}

	# Image wasn't found.
	return 0;
}

# Returns this object as a hash reference for serialization.
sub as_hashref {
	my ($self, %opts) = @_;
	my $obj = {
		id => $self->{id},
		name =>  $self->{name},
		path => $self->{path}
	};

	return $obj;
}

# Saves a uploaded image.
sub download_from_uri {
	my ($self, $uri_text) = @_;
	my $uri = URI->new($uri_text);
	my $mime;
	my $content;

	# Check if the URI is valid.
	if ($uri->has_recognized_scheme) {
		# Check if the URI is a URL.
		if ($uri->scheme ne "data") {
			# Setup LWP with a generic Firefox UA to increase compatibility.
			my $ua = LWP::UserAgent->new(
				agent => "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:24.0) Gecko/20100101 Firefox/24.0",
				cookie_jar => {}
			);

			# Fetch the file.
			my $res = $ua->get($uri_text);

			# Fail if there were aany issues with our download.
			if (not $res->is_success) {
				carp "A problem occured when fetching the image from a URL: " .
					$res->status_line;
				return 0;
			}

			# Store the file contents into a variable.
			$content = $res->decoded_content(charset => "none");
			$mime = $res->header("Content-Type");

			# Check if there was a MIME type available.
			if (not defined $mime) {
				carp "Content-Type header wasn't defined.";
				return 0;
			}
		} else {
			# It's a data URI.
			$mime = $uri->media_type;
			$content = $uri->data;
		}

		# Get file extension from MIME type.
		my $ext = File::MimeInfo->extensions($mime);

		# Create a filename-safe path.
		my $filename = $self->{name} =~ s/[\s\/<>:;"'\\\|\?\*!\@\$#\%^&~`{}\[\]]//gr;
		$filename = "$filename.$ext";

		# TODO: Check if the file exists and give a unique filename if it does.

		# Open file and write the data to it.
		open(my $fh, ">", $self->direct_path($filename, 1));
		binmode $fh;
		print $fh $content;
		close($fh);

		# Return true if the file was created successfully.
		return $self->set_path($filename);
	}

	return 0;
}

# Populate the object.
sub _populate {
	my ($self, $row) = @_;

	$self->{id} = $row->{id};
	$self->set_name($row->{name});
	$self->{path} = $row->{path};
}

# Fetches the image data from the database.
sub _fetch_image {
	my ($self, $id) = @_;

	my $sth = $self->{_dbh}->prepare("SELECT * FROM Images WHERE id = ?");
	$sth->execute($id);

	return $sth->fetchrow_hashref();
}

# Update a image in the database.
sub _update_image {
	my ($self) = @_;

	# Check if image exists.
	if (not Library::Component::Image->exists(dbh => $self->{_dbh},
											  id => $self->{id})) {
		carp "Can't update a image that doesn't exist";
		return 0;
	}

	# Update the image information.
	my $sth = $self->{_dbh}->prepare("UPDATE images SET name = ?, path = ?
                                     WHERE id = ?");
	if ($sth->execute($self->{name}, $self->{path}, $self->{id})) {
		return 1;
	}

	return 0;
}

# Adds a new image to the database.
sub _add_image {
	my ($self) = @_;

	# Check if the image already exists.
	if (defined $self->{id}) {
		carp "Image ID already exists";
		return;
	}

	# Add the new image to the database.
	my $sth = $self->{_dbh}->prepare("INSERT INTO Images(name, path)
                                     VALUES (?, ?)");
	if ($sth->execute($self->{name}, $self->{path})) {
		# Get the image ID from the last insert operation.
		return $self->{_dbh}->last_insert_id(undef, undef, 'images', 'id');
	}
}

1;

__END__

=head1 NAME

Library::Component::Image - Abstraction layer to interact with component images.

=head1 SYNOPSIS

  # Read the configuration file.
  my $config = Config::Tiny->read(...);

  # Create a database handler.
  my $dbh = DBI->connect(...);

  # Create an empty image object.
  my $image = Library::Component::Image->new($dbh, $config);

  # Load a image.
  my $id = 123;
  $image = Library::Component::Image->load(dbh => $dbh,
                                           config => $config,
                                           id => $id);
  my $path = $image->get("path");
  $image->save();

  # Get a list of images.
  my @list = Library::Component::Image->list(dbh => $dbh);

=head1 METHODS

=over 4

=item I<$image> = C<Library::Component::Image>->C<new>(I<$dbh>, I<$config>)

Initializes an empty image object with a database handler (I<$dbh>) and a
Config::Tiny object (I<$config>).

=item I<$image> = C<Library::Component::Image>->C<create>(I<$dbh>, I<$config>,
I<name>, I<$path>[, $nocheck])

Creates a new image with I<$name> and I<$path> already checked for validity,
unless the I<$nocheck> argument is set to I<true>, which will skip the path
check. Requires a database handler (I<$dbh>) and a Config::Tiny object
(I<$config>).

=item I<@list> = C<Library::Component::Image>->C<list>(I<%opts>)

Returns a list of all the available images in the database as a I<@list> of
objects. This function requires a database handler as I<dbh> and a
Config::Tiny object as I<config>.

=item I<$image> = C<Library::Component::Image>->C<load>(I<%lookup>)

Loads the image object with data from the database given a database handler
(I<dbh>), a Config::Tiny object (I<config>), and a ID (I<id>) in the I<%lookup>
argument.

=item I<$status> = I<$image>->C<save>()

Saves the image data to the database. If the operation is successful, this will
return C<1>.

=item I<$image>->C<delete>()

Deletes the current image from the database.

=item I<$data> = I<$image>->C<get>(I<$param>)

Retrieves the value of I<$param> from the image object.

=item I<$path> = I<$image>->C<direct_path>([I<$filename>, I<$nocheck>])

Retrieves the path relative to the project root to the image file using the
object I<path>, if the file is not found I<undef> is returned. You can also
specify a I<$filename> to be used instead of the I<path> and skip the check
with I<$nocheck> as C<1>.

=item I<$success> = I<$image>->C<set_path>(I<$path>[, I<$nocheck>])

Sets the image I<path> and returns C<1> if it's valid. If the I<$nocheck>
parameter is I<true>, the file checks are going to be skipped. B<Remember> to
call C<save()> to commit these changes to the database.

=item I<$success> = I<$image>->C<set_name>(I<$name>)

Sets the image I<name> and returns C<1> if it's valid. B<Remember> to call
C<save()> to commit these changes to the database.

=item I<$valid> = I<$image>->C<exists>(I<%lookup>)

Checks if this image exists and if it is valid and can be used in other objects.
In other words: Has a image ID defined in the database and has not been edited
without being saved.

If called statically the I<%lookup> argument is used to check in the database.
It should contain a I<dbh> parameter and a I<id>.

=item I<\%img> = I<$image>->C<as_hashref>

Returns a hash reference of this object. Perfect for serialization.

=item I<$success> = I<$image>->C<download_from_uri>(I<$uri_text>)

Downloads an image file passed as either a URL or a data URI as the I<$uri_text>
argument and returns C<1> if the operation was successful.

=back

=head1 PRIVATE METHODS

=item I<$self>->C<_populate(I<$row>)

Populates the object with a I<$row> directly from the database.

=item I<\%data> = I<$self>->C<_fetch_image>(I<$id>)

Fetches image data from the database given a image I<id>.

=item I<$success> = I<$self>->C<_update_image>()

Updates the image data in the database with the values from the object and
returns C<1> if the operation was successful.

=item I<$image_id> = I<$self>->C<_add_image>()

Creates a new image inside the database with the values from the object and
returns the component ID if everything went fine.

=over 4

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut
