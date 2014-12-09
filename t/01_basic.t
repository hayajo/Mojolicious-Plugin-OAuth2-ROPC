use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;
use Mojo::Util qw/hmac_sha1_sum/;

my $token_db;

my $oauth2_ropc_bridge = plugin 'Mojolicious::Plugin::OAuth2::ROPC',
    validate_client_handler => sub {
        my $c = shift;
        my( $client_id, $client_secret ) = @_;
        return $client_id eq 'id' && $client_secret eq 'secret';
    },
    grant_token_handler => sub {
        my $c = shift;
        my( $credentials, $expires_in ) = @_;

        return unless( $credentials->{username} eq 'test' && $credentials->{password} eq 'test' );

        $token_db
          = hmac_sha1_sum( $credentials->{username}, $credentials->{password}, app->secrets->[0] );
        return $token_db;
    },
    auth_token_handler => sub {
        my $c = shift;
        my($token) = @_;
        return $token eq $token_db;
    };

# non bridged
get '/' => sub {
    my $c = shift;
    $c->render( json => { message => 'Hello Mojo!' } );
};

# bridged
$oauth2_ropc_bridge->any(
    '/hello' => sub {
        my $c = shift;
        $c->render( json => { message => 'Hello Mojo!' } );
    }
);

subtest 'non bridged route', sub {
    my $t = Test::Mojo->new;
    $t->get_ok('/')->status_is(200)->json_is( { message => 'Hello Mojo!' } );
};

subtest 'get token', sub {
    my $endpoint = '/oauth2/token';    # default endpoint

    subtest 'with invalid request' => sub {
        my $t   = Test::Mojo->new;
        $t->post_ok($endpoint)
        ->status_is(400)
        ->json_is( '/error' => 'invalid_request' );
    };

    subtest 'with invalid client request' => sub {
        my $t   = Test::Mojo->new;
        my $url = $t->ua->server->url->userinfo('invalid_id:invalid_secret')->path($endpoint);
        $t->post_ok(
            $url,
            form => {},
        )
        ->status_is(401)
        ->json_is( '/error' => 'invalid_client' );
    };

    subtest 'with unsupported grant type request' => sub {
        my $t   = Test::Mojo->new;
        my $url = $t->ua->server->url->userinfo('id:secret')->path($endpoint);
        $t->post_ok(
            $url,
            form => {
                grant_type => 'unsupported_grant',
            },
        )
        ->status_is(400)
        ->json_is( '/error' => 'unsupported_grant_type' );
    };

    subtest 'with unauthorized user request' => sub {
        my $t   = Test::Mojo->new;
        my $url = $t->ua->server->url->userinfo('id:secret')->path($endpoint);
        $t->post_ok(
            $url,
            form => {
                grant_type => 'password',
                username   => 'invalid_username',
                password   => 'invalid_password',
            },
        )
        ->status_is(400)
        ->json_is( '/error' => 'unauthorized_client' );
    };

    subtest 'with correct request' => sub {
        my $t   = Test::Mojo->new;
        my $url = $t->ua->server->url->userinfo('id:secret')->path($endpoint);
        $t->post_ok(
            $url,
            form => {
                grant_type => 'password',
                username   => 'test',
                password   => 'test',
            },
        )
        ->status_is(200)
        ->json_has('/access_token')
        ->json_is( '/token_type' => 'bearer' )
        ->json_has('/expires_in');
    };
};

subtest 'bridged route', sub {
    my $endpoint = '/hello';

    my $ua = Mojo::UserAgent->new;
    my $token = $ua->post(
        $ua->server->url->userinfo('id:secret')->path('/oauth2/token'),
        form => {
            grant_type => 'password',
            username   => 'test',
            password   => 'test',
        }
    )->res->json('/access_token');

    subtest 'without token', sub {
        my $t = Test::Mojo->new;
        $t->get_ok($endpoint)
        ->status_is(400)
        ->json_is( '/error' => 'invalid_request' );
    };

    subtest 'with token via Authorization Header', sub {
        my $t = Test::Mojo->new;
        $t->get_ok( $endpoint, { Authorization => "Bearer $token" } )
        ->status_is(200)
        ->json_is( { message => 'Hello Mojo!' } );
    };

    subtest 'with token via request body', sub {
        my $t = Test::Mojo->new;
        $t->post_ok( $endpoint, form => { access_token => $token } )
        ->status_is(200)
        ->json_is( { message => 'Hello Mojo!' } );
    };

    subtest 'with token via query param', sub {
        my $endpoint = Mojo::URL->new($endpoint);
        $endpoint->query->param(access_token => $token);
        my $t = Test::Mojo->new;
        $t->post_ok($endpoint)
        ->status_is(200)
        ->json_is( { message => 'Hello Mojo!' } );
    };
};

done_testing();
