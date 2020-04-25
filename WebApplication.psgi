#!/usr/bin/perl

package PartCat::WebApplication;

use strict;
use warnings;

use DBI;
use Dancer2;
use Dancer2::Plugin::REST;
use Config::Tiny;

use User::Account;
use Library::Category;
use Library::Component;
use Library::Component::Image;

# Set the default (de)serializer to JSON.
set serializer => "JSON";

# Stuff required to be done before each request.
hook before => sub {
	# Set the environment variables.
	var config => Config::Tiny->read("config/testing.conf");
	var dbh => DBI->connect("dbi:SQLite:dbname=" . vars->{config}->{database}->{name},
							"", "", { AutoCommit => 1, RaiseError => 1});
};

# Root path.
get "/" => sub {
	return "It works!";
};

# Component handler.
prefix "/component" => sub {
	# List them.
	get "/list" => sub {
		my @comp_refs;

		# Check if the user is authenticated.
		check_auth();

		# Grab a component list and create their references.
		my @components = Library::Component->list(dbh => vars->{dbh});
		for my $component (@components) {
			push @comp_refs, $component->as_hashref;
		}

		# Return the data.
		return {
			list => \@comp_refs,
			count => scalar @comp_refs
		};
	};

	# Get a component.
	get "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get component.
		my $component = Library::Component->load(dbh => vars->{dbh},
												 id => route_parameters->get("id"));
		if (defined $component) {
			return $component->as_hashref;
		}

		return status_not_found({ error => "Component not found." });
	};

	# Create a component.
	post "/new" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Create component.
		my $component = Library::Component->create(vars->{dbh},
												   body_parameters->get("quantity"),
												   body_parameters->get("mpn"));

		# Check if the component object was able to be created.
		if (defined $component) {
			# Check if the object population was successful before saving.
			if (populate_component($component, 0)) {
				# Save the component.
				if ($component->save()) {
					return $component->as_hashref();
				}
			}
		}

		return status_bad_request({ error => "Some problem occured while trying to create the component. Check your parameters and try again." });
	};

	# Edit a component.
	post "/edit/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Load component.
		my $component = Library::Component->load(dbh => vars->{dbh},
												 id => route_parameters->get("id"));

		# Check if the component object was loaded successfully.
		if (defined $component) {
			# Check if the object population was successful before saving.
			if (populate_component($component, 1)) {
				# Save the component.
				if ($component->save()) {
					return $component->as_hashref;
				}
			}

			return status_bad_request({ error => "Some problem occured while trying to edit the component. Check your parameters and try again." });
		}

		return status_not_found({ error => "Component not found." });
	};

	# Delete a component by its ID.
	del "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get component.
		my $component = Library::Component->load(dbh => vars->{dbh},
												 id => route_parameters->get("id"));
		if (defined $component) {
			$component->delete();
			return { message => "Component deleted successfully." };
		}

		return status_not_found({ error => "Component not found." });
	};
};

# Category handler.
prefix "/category" => sub {
	# List them.
	get "/list" => sub {
		my @cat_refs;

		# Check if the user is authenticated.
		check_auth();

		# Grab a categories list and create their references.
		my @categories = Library::Category->list(dbh => vars->{dbh});
		for my $category (@categories) {
			push @cat_refs, $category->as_hashref;
		}

		# Return the data.
		return {
			list => \@cat_refs,
			count => scalar @cat_refs
		};
	};

	# Get a category.
	get "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get category.
		my $category = Library::Category->load(dbh => vars->{dbh},
											   id => route_parameters->get("id"));
		if (defined $category) {
			return $category->as_hashref;
		}

		return status_not_found({ error => "User not found." });
	};

	# Create a category.
	post "/new" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Create category.
		my $category = Library::Category->create(vars->{dbh},
												 body_parameters->get("name"));

		# Check if the category object was able to be created.
		if (defined $category) {
			if ($category->save()) {
				return $category->as_hashref;
			}
		}

		return status_bad_request({ error => "Some problem occured while trying to create the category. Check your parameters and try again." });
	};

	# Edit a category.
	post "/edit/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Load category.
		my $category = Library::Category->load(dbh => vars->{dbh},
											   id => route_parameters->get("id"));

		# Check if the category object was loaded successfully.
		if (defined $category) {
			# Check if the object population was successful before saving.
			if ($category->set_name(body_parameters->get("name"))) {
				# Save the category.
				if ($category->save()) {
					return $category->as_hashref;
				}
			}

			return status_bad_request({ error => "Some problem occured while trying to edit the category. Check your parameters and try again." });
		}

		return status_not_found({ error => "Category not found." });
	};

	# Delete a category by its ID.
	del "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get category.
		my $category = Library::Category->load(dbh => vars->{dbh},
											   id => route_parameters->get("id"));
		if (defined $category) {
			$category->delete();
			return { message => "Category deleted successfully." };
		}

		return status_not_found({ error => "Category not found." });
	};
};

# Image handler.
prefix "/image" => sub {
	# List them.
	get "/list" => sub {
		my @image_refs;

		# Check if the user is authenticated.
		check_auth();

		# Grab a image list and create their references.
		my @images = Library::Component::Image->list(dbh => vars->{dbh},
													 config => vars->{config});
		for my $image (@images) {
			push @image_refs, $image->as_hashref;
		}

		# Return the data.
		return {
			list => \@image_refs,
			count => scalar @image_refs
		};
	};

	# Get a image.
	get "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get image.
		my $image = Library::Component::Image->load(dbh => vars->{dbh},
													config => vars->{config},
													id => route_parameters->get("id"));
		if (defined $image) {
			return $image->as_hashref;
		}

		return status_not_found({ error => "Image not found." });
	};

	# Get the image file.
	get "/file/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get image.
		my $image = Library::Component::Image->load(dbh => vars->{dbh},
													config => vars->{config},
													id => route_parameters->get("id"));
		if (defined $image) {
			my $path = $image->direct_path;

			# Check if the path is valid.
			if (defined $path) {
				# Remove the "public/" part, since send_file is relative to it.
				$path =~ s/^public\///;
				use Data::Dumper;
				print Dumper($path);

				# Send the image file.
				send_file($path);
			}
		}

		return status_not_found({ error => "Image not found." });
	};

	# Create a image.
	post "/new" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Create image.
		my $image = Library::Component::Image->create(vars->{dbh},
													  vars->{config},
													  body_parameters->get("name"),
													  "", 1);

		# Upload image.
		my $success = $image->download_from_uri(body_parameters->get("uri"));

		# Check if the image object was able to be created.
		if ($success and defined $image) {
			if ($image->save()) {
				return $image->as_hashref;
			}
		}

		return status_bad_request({ error => "Some problem occured while trying to create the image. Check your parameters and try again." });
	};

	# Edit a image.
	post "/edit/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Load image.
		my $image = Library::Component::Image->load(dbh => vars->{dbh},
													config => vars->{config},
													id => route_parameters->get("id"));

		# Check if the image object was loaded successfully.
		my $success = defined $image;
		if ($success) {
			# Set name.
			my $name = body_parameters->get("name");
			if (defined $name) {
				$success = ($success and $image->set_name($name));
			}

			# Set image file.
			my $uri = body_parameters->get("uri");
			if (defined $uri) {
				$success = ($success and $image->download_from_uri($uri));
			}

			# Check if the object population was successful before saving.
			if ($success) {
				# Save the image.
				if ($image->save()) {
					return $image->as_hashref;
				}
			}

			return status_bad_request({ error => "Some problem occured while trying to edit the image. Check your parameters and try again." });
		}

		return status_not_found({ error => "Image not found." });
	};

	# Delete a image by its ID.
	del "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get image.
		my $image = Library::Component::Image->load(dbh => vars->{dbh},
													config => vars->{config},
													id => route_parameters->get("id"));
		if (defined $image) {
			$image->delete();
			return { message => "Image deleted successfully." };
		}

		return status_not_found({ error => "Image not found." });
	};

};

# User handler.
prefix "/user" => sub {
	# List them.
	get "/list" => sub {
		my @user_refs;

		# Check if the user is authenticated.
		check_auth();

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

	# Get a user.
	get "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get user.
		my $user = User::Account->load(dbh => vars->{dbh},
									   id => route_parameters->get("id"));
		if (defined $user) {
			return $user->as_hashref(pass_hidden => 1);
		}

		return status_not_found({ error => "User not found." });
	};

	# Create a user.
	post "/new" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Create user.
		my $user = User::Account->create(vars->{dbh},
										 body_parameters->get("email"),
										 body_parameters->get("password"),
										 7);

		# Check if the user object was able to be created.
		if (defined $user) {
			if ($user->save()) {
				return $user->as_hashref(pass_hidden => 1);
			}
		}

		return status_bad_request({ error => "Some problem occured while trying to create the user. Check your parameters and try again." });
	};

	# Edit a user.
	post "/edit/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Load user.
		my $user = User::Account->load(dbh => vars->{dbh},
									   id => route_parameters->get("id"));

		# Check if the user object was loaded successfully.
		my $success = defined $user;
		if ($success) {
			# Set email.
			my $email = body_parameters->get("email");
			if (defined $email) {
				$success = ($success and $user->set_email($email));
			}

			# Set password.
			my $password = body_parameters->get("password");
			if (defined $password) {
				$success = ($success and $user->set_password($password));
			}

			# Check if the object population was successful before saving.
			if ($success) {
				# Save the component.
				if ($user->save()) {
					return $user->as_hashref(pass_hidden => 1);
				}
			}

			return status_bad_request({ error => "Some problem occured while trying to edit the user. Check your parameters and try again." });
		}

		return status_not_found({ error => "User not found." });
	};

	# Delete a user by its ID.
	del "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get user.
		my $user = User::Account->load(dbh => vars->{dbh},
									   id => route_parameters->get("id"));

		# Check if the user object was loaded successfully.
		if (defined $user) {
			$user->delete();
			return { message => "User deleted successfully." };
		}

		return status_not_found({ error => "User not found." });
	};
};

# Checks if the user is authenticated.
sub check_auth {
	my $email = request_header("Email");
	my $password = request_header("Password");

	# Check if the headers were defined and check if the user exists.
	if (defined $email and defined $password) {
		my $user = User::Account->load(dbh => vars->{dbh}, email => $email);

		# Check if the user was found and the password matches.
		if (defined $user) {
			if ($user->check_password($password)) {
				return;
			}
		}
	}

	halt(status_unauthorized({ error => "Email and/or password incorrect." }));
}

# Populates a component object with data from the request.
sub populate_component {
	my ($component, $editing) = @_;
	my $success = 1;

	# If editing, then be able to change the quantity and mpn.
	if ($editing) {
		# Set quantity.
		my $quantity = body_parameters->get("quantity");
		if (defined $quantity) {
			$success = ($success and $component->set_quantity($quantity));
		}

		# Set part number.
		my $mpn = body_parameters->get("mpn");
		if (defined $mpn) {
			$success = ($success and $component->set_mpn($mpn));
		}
	}

	# Set description.
	my $description = body_parameters->get("description");
	if (defined $description) {
		$success = ($success and $component->set_description($description));
	}

	# Set category.
	my $cat_id = body_parameters->get("cat_id");
	if (defined $cat_id) {
		$success = ($success and $component->set_category(id => $cat_id));
	}

	# Set image.
	my $image_id = body_parameters->get("image_id");
	if (defined $image_id) {
		$success = ($success and $component->set_image($image_id));
	}

	# Set parameters.
	my $params = body_parameters->get("parameters");
	if (defined $params) {
		$component->set_parameters(%{$params});
	}

	return $success;
}

start;

__END__

=head1 NAME

PartCat::WebApplication - PartCat web application.

=head1 SYNOPSIS

  # Initialize the server.
  $ plackup -r -R lib WebApplication.psgi

=head1 API ENDPOINTS

=over 4

=head2 COMPONENT

=over 4

=item C<GET> I</component/list>

Lists all the components available.

=item C<GET> I</component/:id>

Get information about a component by its I<id>.

=item C<POST> I</component/new>

Creates a new component with a I<quantity> and a I<mpn> passed in the request
body as a JSON object. B<Optional arguments:> I<description>, I<cat_id>,
I<image_id>, and a I<parameters> JSON object.

=item C<POST> I</component/edit/:id>

Edits a component by its I<id> with a I<quantity> and a I<mpn> passed in the
request body as a JSON object. B<Optional arguments:> I<description>, I<cat_id>,
I<image_id>, and a I<parameters> JSON object.

=item C<DELETE> I</component/:id>

Deletes a component with a specific I<id>.

=back

=head2 CATEGORY

=over 4

=item C<GET> I</category/list>

Lists all the categories available.

=item C<GET> I</category/:id>

Get information about a category by its I<id>.

=item C<POST> I</category/new>

Creates a new category with a I<name> passed in the request body as a JSON
object.

=item C<POST> I</category/edit/:id>

Edits a category by its I<id> with a I<name> passed in the request body as a
JSON object.

=item C<DELETE> I</category/:id>

Deletes a category with a specific I<id>.

=back

=head2 IMAGE

=over 4

=item C<GET> I</image/list>

Lists all the images available.

=item C<GET> I</image/:id>

Get information about an image by its I<id>.

=item C<GET> I</image/file/:id>

Get the image file by its I<id>.

=item C<POST> I</image/new>

Creates a new image with a I<name> and a URL or base64-encoded data URI image
file as I<uri> passed in the request body as a JSON object.

=item C<POST> I</image/edit/:id>

Edits a image by its I<id> with a I<name> and/or I<uri> passed in the request
body as a JSON object.

=item C<DELETE> I</image/:id>

Deletes an image with a specific I<id>.

=back

=head2 USER

=over 4

=item C<GET> I</user/list>

Lists all the users available.

=item C<GET> I</user/:id>

Get information about a user by its I<id>.

=item C<POST> I</user/new>

Creates a new user with a I<email>, I<password> and I<permission> passed in the
request body as a JSON object.

=item C<POST> I</user/edit/:id>

Edits a user by its I<id> with a I<email>, I<password> and I<permission> passed
in the request body as a JSON object.

=item C<DELETE> I</user/:id>

Deletes a user with a specific I<id>.

=back

=back

=head1 PRIVATE METHODS

=over 4

=item I<\%err_msg> = C<check_auth>

Checks if the authentication headers were sent and that they match with a stored
user. In case of an error or the user doesn't exist a I<\%err_msg> is returned.

=item I<$success> = C<populate_component>(I<$component>, I<$editing>)

Populates a I<$component> object with all the optional parameters gathered from
the request. Set the I<$editing> flag to C<1> to enable populating the quantity
and the part number.

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut
