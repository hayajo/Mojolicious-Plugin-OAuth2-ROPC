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

# OPTIONS

[Mojolicious::Plugin::OAuth2::ROPC](https://metacpan.org/pod/Mojolicious::Plugin::OAuth2::ROPC) supports the following options.

## `grant_token_handler`

Required. Authenticate with credentials, and return generated token when credentials are correct.

    ...
    grant_token_handler => sub {
        my $c = shift;
        my( $credentials, $expires_in ) = @_;
        ...
        return $token; # check the credentials, response the token.
    },
    ...

Credentials contains following keys.

- client\_id
- client\_secret
- username
- password

## `auth_token_handler`

Required. Check the token is valid.

    ...
    auth_token_handler => sub {
        my $c = shift;
        my($token) = @_;
        ...
        return 1; # succeeded to authorize the token.
    },
    ...

## `validate_client_handler`

Optional. Check the client is authorized to use the API.

    ...
    validate_client_handler => sub {
        my $c = shift;
        my( $client_id, $client_secret ) = @_;
        ...
        return 1; # succeeded to validate the client.
    },
    ...

## `grant_scope_handler`

Optional. Limit the scope of the issued token. Refer to the implementation of t/01\_basic.t.

    ...
    grant_scope_handler => sub {
        my $c = shift;
        my( $credentials, $request_scopes ) = @_;
        ...
        return \@scopes; # return valid scopes.
    },
    ...

Credentials contains following keys.

- client\_id
- client\_secret
- username
- password
- token

## `endpoint`

optional. The endpoint of the authorization. default value is /oauth2/token.

## `expires_in`

optional. The lifetime in seconds of the access token. default value is 60 \* 60 \* 24 \* 30 (30 days).

# SEE ALSO

[Mojolicious](https://metacpan.org/pod/Mojolicious), [Mojolicious::Guides](https://metacpan.org/pod/Mojolicious::Guides), [http://mojolicio.us](http://mojolicio.us).

# LICENSE

Copyright (C) hayajo.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

hayajo <>
