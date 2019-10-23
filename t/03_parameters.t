#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use Test::Spec;
use JSON::MaybeXS;
use Array::Compare;

use Library::Component::Parameters;

describe "A parameter container" => sub {
	my $params;
	my $raw = '{"test":"hello","arr":[1,2,3,4.56]}';

	describe "created" => sub {
		describe "empty" => sub {
			it "should be created" => sub {
				$params = Library::Component::Parameters->new;
				is(ref $params, "Library::Component::Parameters");
			};

			it "should have no text" => sub {
				is($params->{text}, undef);
			};

			it "should have no JSON object" => sub {
				is($params->{json}, undef);
			};

			it "should have no data" => sub {
				is($params->{data}, undef);
			};

			it "should return undef when querying parameters" => sub {
				is($params->get("something"), undef);
			};

			it "should return undef when requesting a list" => sub {
				is($params->list, undef);
			};

			it "should return undef when requesting text" => sub {
				is($params->as_text, undef);
			};

			after all => sub {
				$params = undef;
			};
		};

		describe "with JSON" => sub {
			it "should be created" => sub {
				$params = Library::Component::Parameters->new($raw);
				is(ref $params, "Library::Component::Parameters");
			};

			it "should have a matching text" => sub {
				is($params->{text}, $raw);
			};

			it "should have a JSON object" => sub {
				is(ref $params->{json}, JSON::MaybeXS::JSON());
			};

			it "should have some data" => sub {
				is(ref $params->{data}, "HASH");
			};

			it "should have a matching list of names" => sub {
				ok(Array::Compare->new->compare($params->list,
												[ "arr", "test" ]));
			};

			it "should return nothing when getting a invalid parameter" => sub {
				is($params->get("nothing"), undef);
			};

			it "should have a matching text parameter" => sub {
				is($params->get("test"), "hello");
			};

			it "should have a matching array parameter" => sub {
				ok(Array::Compare->new->compare($params->get("arr"),
												[ 1, 2, 3, 4.56 ]));
			};

			it "should have a matching text export text" => sub {
				my $json = JSON::MaybeXS->new(utf8 => 1, canonical => 1);
				my $data = $json->decode($raw);

				$params->{json}->canonical(1);
				is($params->as_text, $json->encode($data));
			};

			after all => sub {
				$params = undef;
			};
		};
	};
};

runtests unless caller;
