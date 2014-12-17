package Mojolicious::Plugin::OAuth2::ROPC;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = "0.01";

sub register {
    my $self = shift;
    my( $app, $opts ) = @_;

    $opts->{grant_token_handler} or die "Missing mandatory parameter: grant_token_handler";
    $opts->{auth_token_handler}  or die "Missing mandatory parameter: auth_token_handler";

    $opts->{endpoint}                ||= '/oauth2/token';
    $opts->{expires_in}              ||= 60 * 60 * 24 * 30; # 30 days
    $opts->{validate_client_handler} ||= sub { return 1 };
    $opts->{grant_scope_handler}     ||= sub { return [] };

    $app->helper(
        oauth2_bearer_access_token => sub {
            my $c = shift;

            if( my $auth = $c->req->headers->authorization ) {
                my( $scheme, $token ) = split( /\s+/, $auth, 2 );
                return $token if( $scheme =~ /bearer/i );
            }
            elsif( my $token = $c->req->param('access_token') ) {
                return $token;
            }

            return;
        }
    );

    my $routes = $app->routes;
    $routes->post(
        $opts->{endpoint},
        sub {
            my $c = shift;

            # check request
            if( !$c->req->headers->content_type || $c->req->headers->content_type ne 'application/x-www-form-urlencoded' ) {
                oauth2_error( $c, error => 'invalid_request' );
                return;
            }

            # check client with authorization header
            my ($client_id, $client_secret);
            if( my $userinfo = $c->req->url->to_abs->userinfo ) {
                ( $client_id, $client_secret ) = split( /:/, $userinfo, 2 );
            }
            if( !$opts->{validate_client_handler}->( $c, $client_id, $client_secret ) ) {
                oauth2_error( $c, error => 'invalid_client', code => 401 );
                return;
            }

            # check grant_type
            if( !$c->param('grant_type') || $c->param('grant_type') ne 'password' ) {
                oauth2_error( $c, error => 'unsupported_grant_type' );
                return;
            }

            my $credentials = +{
                client_id     => $client_id,
                client_secret => $client_secret,
                username      => $c->param('username'),
                password      => $c->param('password'),
            };

            # grant access_token
            my $token = $opts->{grant_token_handler}->( $c, $credentials, $opts->{expires_in} );
            if( !$token ) {
                oauth2_error( $c, error => 'unauthorized_client' );
                return;
            }

            my $res = {
                access_token => $token,
                token_type   => 'bearer',
                expires_in   => $opts->{expires_in},
            };

            # grant_scope
            if (my $scope = $c->param('scope')) {
                $credentials->{token} = $token;
                my $requested_scope = [ split( / +/, $scope || '' ) ];

                my $granted_scope = $opts->{grant_scope_handler}->( $c, $credentials, $requested_scope );
                if( ref $granted_scope ne 'ARRAY' ) {
                    die "grant_scope_handler have to return ArrayRef.";
                }
                if( !@$granted_scope ) {
                    oauth2_error( $c, error => 'invalid_scope' );
                    return;
                }

                $res->{scope} = join( ' ', sort @$granted_scope );
            }

            oauth2_response( $c, %$res );
        }
    );

    my $bridge = $routes->under(
        sub {
            my $c = shift;

            # extract access_token
            my $token = $c->oauth2_bearer_access_token();
            if (!$token) {
                oauth2_error($c);
                return;
            }

            # authenticate access_token
            if( !$opts->{auth_token_handler}->( $c, $token ) ) {
                oauth2_error( $c, error => 'invalid_grant' );
                return;
            }

            return 1;
        }
    );

    return $bridge;
}

sub oauth2_response {
    my $c    = shift;
    my %data = @_;

    $c->res->headers->cache_control('no-store');
    $c->res->headers->add( Pragma => 'no-cache' );
    $c->res->headers->add( 'X-Content-Type-Options' => 'nosniff');

    $c->render( json => \%data );
}

sub oauth2_error {
    my $c      = shift;
    my %params = @_;

    $c->res->code( $params{code} || 400 );
    oauth2_response( $c, error => $params{error} || 'invalid_request' );
}

1;
__END__

=encoding utf-8

=head1 NAME

Mojolicious::Plugin::OAuth2::ROPC - a simple OAuth2 endpoint, implements ROPC flow only.

=head1 SYNOPSIS

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

=head1 DESCRIPTION

L<Mojolicious::Plugin::OAuth2::ROPC> is a L<Mojolicious> plugin.

=head1 METHODS

L<Mojolicious::Plugin::OAuth2::ROPC> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=head1 LICENSE

Copyright (C) hayajo.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

hayajo E<lt>E<gt>

=cut

