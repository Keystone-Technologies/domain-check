package Mojolicious::Command::update;
use Mojo::Base 'Mojolicious::Command';

use Mojo::UserAgent;
use Mojo::JSON 'j';

use Net::Whois::Parser;
use DateTime::Format::Flexible;

use File::Spec::Functions qw(catdir catfile splitdir);

has description => 'abc';
has usage => 'xyz';

sub run {
  my $self = shift;
  my $cmd = shift;
  
  my $couchdb = "http://db.xlxcd1.kit.cm:5984/domain-check";
  my $ua = Mojo::UserAgent->new;

  for my $hostname ( @ARGV ) {
    say $hostname;
    my $tx = $ua->get("$couchdb/$hostname");
    my $json = $tx->res->json;
    # Domain expiration
    my $now = DateTime::Format::Flexible->parse_datetime('now');
    my $mod = DateTime::Format::Flexible->parse_datetime($json->{domain}->{last_modified} || 'now');
    my $diff = $now->epoch - $mod->epoch;
warn $diff;
    if ( $diff >= 12000 || $diff <= 1 ) {
      if ( my $info = parse_whois(domain => $hostname) ) {
        my $expires;
        my $diff;
        $expires = DateTime::Format::Flexible->parse_datetime($info->{expiration_date} || 'now');
        $diff = $expires - $now;
        printf "Domain Expires: %s%s\n", $expires->ymd, ($diff->in_units('months') < 3 ? " (< 3 months)" : '');
        $json->{domain} = {
          last_modified => scalar(localtime),
          expires => $info->{expiration_date} ? $expires->ymd : '',
          is_expiring => ($diff->in_units('months') < 3),
        };
        #warn Data::Dumper::Dumper($info);
        say j($ua->put("$couchdb/$hostname" => json => $json)->res->json);
      }
    } else {
      if ( $json->{domain}->{expires} ) {
        my $expires = DateTime::Format::Flexible->parse_datetime($json->{domain}->{expires} || 'now');
        my $diff = $now - $expires;
        printf "(CACHED) Domain Expires: %s%s\n", $expires->ymd, ($diff->years + $diff->months/12 < 3 ? " (< 3 months)" : '');
      }
    }
  } continue { print "\n" }
}

1;
