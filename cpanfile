requires 'DBI', '>= 1.642';
requires 'Carp', '>= 1.50';
requires 'URI', '>= 1.76';
requires 'Plack', '>= 1.0047';
requires 'Dancer2', '>= 0.208001';
requires 'Dancer2::Plugin::REST', '>= 1.02';
requires 'Config::Tiny', '>= 2.24';
requires 'Email::Valid', '>= 1.202';
requires 'Scalar::Util', '>= 1.53';
requires 'File::MimeInfo', '>= 0.29';
requires 'JSON::MaybeXS', '>= 1.004000';
requires 'Cpanel::JSON::XS', '>= 4.15';
requires 'Try::Tiny', '>= 0.30';
requires 'Authen::Passphrase::BlowfishCrypt', '>= 0.008';

on 'test' => sub {
	requires 'Test::Spec', '>= 0.54';
};

on 'develop' => sub {
	recommends 'Perl::Critic', '>= 1.134';
};
