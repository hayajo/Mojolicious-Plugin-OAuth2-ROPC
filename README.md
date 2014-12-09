# NAME

Mojolicious::Plugin::OAuth2::ROPC - a simple OAuth2 endpoint, implements ROPC flow only.

# SYNOPSIS

    # Mojolicious
    my $bridge = $self->plugin('OAuth2::ROPC',
        grant_token_handler => sub {
            my $c = shift;
            my( $credentials, $expires_in ) = @_;
            ...
            return $token;
        },
        auth_token_handler => sub {
            my $c = shift;
            my($token) = @_;
            ...
            return 1;
        },
    );

    $bridge->get('/hello' => sub {
        $_[0]->render(json => { message => 'Hello Mojo!' });
    });


    # Mojolicious::Lite
    my $bridge = plugin 'OAuth2::ROPC',
        grant_token_handler => sub {
            my $c = shift;
            my( $credentials, $expires_in ) = @_;
            ...
            return $token;
        },
        auth_token_handler => sub {
            my $c = shift;
            my($token) = @_;
            ...
            return 1;
        };

    $bridge->get('/hello' => sub {
        $_[0]->render(json => { message => 'Hello Mojo!' });
    });

# DESCRIPTION

[Mojolicious::Plugin::OAuth2::ROPC](https://metacpan.org/pod/Mojolicious::Plugin::OAuth2::ROPC) is a [Mojolicious](https://metacpan.org/pod/Mojolicious) plugin.

# METHODS

[Mojolicious::Plugin::OAuth2::ROPC](https://metacpan.org/pod/Mojolicious::Plugin::OAuth2::ROPC) inherits all methods from
[Mojolicious::Plugin](https://metacpan.org/pod/Mojolicious::Plugin) and implements the following new ones.

## register

    $plugin->register(Mojolicious->new);

Register plugin in [Mojolicious](https://metacpan.org/pod/Mojolicious) application.

# SEE ALSO

[Mojolicious](https://metacpan.org/pod/Mojolicious), [Mojolicious::Guides](https://metacpan.org/pod/Mojolicious::Guides), [http://mojolicio.us](http://mojolicio.us).

# LICENSE

Copyright (C) hayajo.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

hayajo <>
