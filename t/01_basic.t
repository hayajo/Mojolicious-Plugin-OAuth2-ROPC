use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;
use Mojo::Util qw/hmac_sha1_sum/;

my $token_db = {};
my $scope_db = {
    myclient => [qw| /hello /goodbye /thanks |],
};

my $oauth2_ropc_bridge = plugin 'Mojolicious::Plugin::OAuth2::ROPC',
    validate_client_handler => sub {
        my $c = shift;
        my( $client_id, $client_secret ) = @_;
        return $client_id eq 'myclient' && $client_secret eq 'mysecret';
    },
    grant_token_handler => sub {
        my $c = shift;
        my( $credentials, $expires_in ) = @_;

        return unless( $credentials->{username} eq 'test' && $credentials->{password} eq 'test' );

        my $token
          = hmac_sha1_sum( $credentials->{username}, $credentials->{password}, app->secrets->[0] );

        $token_db->{$token} = {
            client_id => $credentials->{client_id},
            expire    => time + $expires_in,
        };

        return $token;
    },
    grant_scope_handler => sub {
        my $c = shift;
        my( $credentials, $request_scopes ) = @_;

        my( %union, %intersection );
        my $client_scopes = $scope_db->{ $credentials->{client_id} } || [];
        for( @$request_scopes, @$client_scopes) {
            $union{$_}++ && $intersection{$_}++;
        }

        my @scopes = keys %intersection;
        $token_db->{ $credentials->{token} }->{scope} = \@scopes;

        return \@scopes;
    },
    auth_token_handler => sub {
        my $c = shift;
        my($token) = @_;

        return unless $token_db->{$token};

        if( $token_db->{$token}->{expire} < time ) {
            delete $token_db->{$token};
            return;
        }
        elsif( !( grep { $_ eq $c->req->url->path } @{ $token_db->{$token}->{scope} } ) ) {
            return;
        }

        return 1;
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
        my $url = $t->ua->server->url->userinfo('myclient:mysecret')->path($endpoint);
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
        my $url = $t->ua->server->url->userinfo('myclient:mysecret')->path($endpoint);
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

    subtest 'with invalid scope only' => sub {
        my $t   = Test::Mojo->new;
        my $url = $t->ua->server->url->userinfo('myclient:mysecret')->path($endpoint);
        $t->post_ok(
            $url,
            form => {
                grant_type => 'password',
                username   => 'test',
                password   => 'test',
                scope      => 'hoge fuga piyo',
            },
        )
        ->status_is(400)
        ->json_is( '/error' => 'invalid_scope' );
    };

    subtest 'without scope' => sub {
        my $t   = Test::Mojo->new;
        my $url = $t->ua->server->url->userinfo('myclient:mysecret')->path($endpoint);
        $t->post_ok(
            $url,
            form => {
                grant_type => 'password',
                username   => 'test',
                password   => 'test',
            },
        )
        ->status_is(200)
        ->json_hasnt('/scope');
    };

    subtest 'with correct request' => sub {
        my $t   = Test::Mojo->new;
        my $url = $t->ua->server->url->userinfo('myclient:mysecret')->path($endpoint);
        $t->post_ok(
            $url,
            form => {
                grant_type => 'password',
                username   => 'test',
                password   => 'test',
                scope      => '/hello /goodbye /thanks hoge fuga piyo',
            },
        )
        ->status_is(200)
        ->json_has('/access_token')
        ->json_is( '/token_type' => 'bearer' )
        ->json_is( '/scope'      => join( ' ', sort qw| /hello /goodbye /thanks | ) )
        ->json_has('/expires_in');
    };
};

subtest 'bridged route', sub {
    my $endpoint = '/hello';

    my $ua = Mojo::UserAgent->new;
    my $token = $ua->post(
        $ua->server->url->userinfo('myclient:mysecret')->path('/oauth2/token'),
        form => {
            grant_type => 'password',
            username   => 'test',
            password   => 'test',
            scope      => '/hello',
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
