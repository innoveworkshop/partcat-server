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
							"", "", { AutoCommit => 1 });
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
		my $success = defined $component;
		if ($success) {
			# Set description.
			my $description = body_parameters->get("description");
			if (defined $description) {
				$success = $success or $component->set_description($description);
			}

			# Set category.
			my $cat_id = body_parameters->get("cat_id");
			if (defined $cat_id) {
				$success = $success or $component->set_category(id => $cat_id);
			}

			# Set image.
			my $image_id = body_parameters->get("image_id");
			if (defined $image_id) {
				$success = $success or $component->set_image($image_id);
			}

			# Set parameters.
			my $params = body_parameters->get("parameters");
			if (defined $params) {
				$component->set_parameters(%{$params});
			}

			# Check if all the previous operations were successful before saving.
			if ($success) {
				print "HELLOOOOOOO\n";
				# Save the component.
				if ($component->save()) {
					return $component->as_hashref();
				}
			}
		}

		return status_bad_request({ error => "Some problem occured while trying to create the component. Check your parameters and try again." });
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

	# Delete a user by its ID.
	del "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get user.
		my $user = User::Account->load(dbh => vars->{dbh},
									   id => route_parameters->get("id"));
		if (defined $user) {
			$user->delete();
			return { message => "User deleted successfully." };
		}

		return status_not_found({ error => "User not found." });
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

		# TODO: Improve this to include upload and download from URL.

		# Create image.
		my $image = Library::Component::Image->create(vars->{dbh},
													  vars->{config},
													  body_parameters->get("name"),
													  body_parameters->get("path"));

		# Check if the image object was able to be created.
		if (defined $image) {
			if ($image->save()) {
				return $image->as_hashref;
			}
		}

		return status_bad_request({ error => "Some problem occured while trying to create the image. Check your parameters and try again." });
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

	# Delete a user by its ID.
	del "/:id" => sub {
		# Check if the user is authenticated.
		check_auth();

		# Get user.
		my $user = User::Account->load(dbh => vars->{dbh},
									   id => route_parameters->get("id"));
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

start;

__END__

=head1 NAME

PartCat::WebApplication - PartCat web application.

=head1 SYNOPSIS

  # Initialize the server.
  $ plackup -r -R lib bin/WebApplication.psgi

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

Creates a new image with a I<name> and a I<path> passed in the request body as a
JSON object.

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

=item C<DELETE> I</user/:id>

Deletes a user with a specific I<id>.

=back

=back

=head1 METHODS

=over 4

=item I<\%err_msg> = C<check_auth>

Checks if the authentication headers were sent and that they match with a stored
user. In case of an error or the user doesn't exist a I<\%err_msg> is returned.

=back

=head1 AUTHOR

Nathan Campos <nathan@innoveworkshop.com>

=head1 COPYRIGHT

Copyright (c) 2019- Innove Workshop Company.

=cut
