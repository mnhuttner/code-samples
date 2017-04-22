#!/usr/bin/perl
#---------------------------------------------------------------
my $title  = 'getAlertSiteOutages.pl';
my $desc   = 'fetch AlertSite outage info for yesterday';
# uses wget to fetch usage report via report/API
my $ver    = '1.0.0';
my $author = 'mhuttner';
#---------------------------------------------------------------
$|++;
use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use Data::Dumper;
use POSIX qw(strftime);
#---------------------------------------------------------------
my (%sn2id,%id2sn,%conf,$log,$range);

myInit();
myCurl();
myExit();

#---------------------------------------------------------------
sub myInit {
  $ENV{TZ} = "America/New_York";
  $conf{DEBUG} = 1;
  print "# myInit\n" if $conf{DEBUG};
  $conf{SUMMARY} = 1;

  # yesterday
  my ($Y,$m,$d,$H,$M) = (split/\s+/,strftime('%Y %m %d %H %M',localtime(time-86400)));
  my $start_date = "${Y}-${m}-${d}+12:00:00";
  my $end_date   = "${Y}-${m}-${d}+23:59:59";
  $range = "start_date=${start_date}\&end_date=${end_date}"; #$range = 'rdate=LastMonth';

  print "# $title($ver) executing for range($range)\n";
  chomp(my $date = `date`);
  print "# Starting: $date\n";

  my $ln = '/var/log/ISG/AlertSite/AlertSiteOutages.log';
  $conf{LOGNAME} = $ln;
  open $log, ">>", $ln or die "could not create $ln: $!\n";
  print "# Appending: $ln\n";
  $conf{USER} = $ENV{LOGNAME} || "mhuttner";
  $conf{PASS} = $ENV{PASS}    || die "Must set PASS!\n";
}
#---------------------------------------------------------------
sub myExit {
  close $log;
  chomp(my $date = `date`);
  print "# Completed: $date\n";
  exit 1;
}
#---------------------------------------------------------------
sub myCurl {
  print "# myCurl- querying outage report\n" if $conf{DEBUG};
  my $date = "?";
  # https://www.alertsite.com/report-api/detail/C99999?devices=76981,94332&start_date=2013-01-20+00:00:00&end_date=2013-01-22+23:59:59&api_version=2
  my $cmd = "wget -O - --http-user=$conf{USER}\@nodomain.com --http-passwd=$conf{PASS} 'https://www.alertsite.com/report-api/outage/C43663?&${range}&api_version=2'";
  my $c = $cmd; $c =~ s/$conf{PASS}/*******/;
  print "# Command: $c\n" if $conf{DEBUG};
  my $cnt = 0;
  open my $fh, "$cmd 2>&1 |" or die "could not exec $c: $!\n";
  while (<$fh>) {
    chomp;
    next if !/outage_start/;
    if (m/outage_start="(\S.*\d?)".*/) {
      my $date = $1;
      print $log "[$date] OUTAGE $_\n"; print ".";
      #print "[$date] OUTAGE $_\n";
      $cnt++;
    } else {
      die "OOPS($_)\n";
    }
  } close $fh; 
  print "# Total records: [$cnt]\n";
  chomp($date = `date`);
  print "# Completed: $date\n";
}
#---------------------------------------------------------------
sub getSites {
  print "# getSites\n" if $conf{DEBUG};

  # AlertSite REST client-Login, List Devices
  # non-browser REST client needs to manually store cookie
  # login with REST API via URL /user/login, get cookie+resp XML from header
  my $REST_SERVER = 'https://www.alertsite.com/restapi';  # Base path
  my $LOGIN = 'mhuttner@nodomain.com';                      # AlertSite account login
  my $PASSWORD = $ENV{PASS} || die "Must set PASS variable!";

  # Set up User Agent         #
  my $ua = LWP::UserAgent->new;
  $ua->agent('AlertSite REST Client/1.0');

  my ($POST_XML, $req, $resp, $cookie, $session, $OBJCUST, $DEVICE);
  # Login request          #
  my $POST_XML_LOGIN = << "POST_XML_LOGIN";  # Request body

<Login> <Login>$LOGIN</Login> <Password>$PASSWORD</Password> </Login>

POST_XML_LOGIN

  # HTTP request to login.
  # Use text/xml and raw POST data to conform to existing REST API
  $req = HTTP::Request->new(POST => "$REST_SERVER/user/login");
  $req->content_type('text/xml');
  $req->content($POST_XML_LOGIN);
  $resp = $ua->request($req);            # Send request
  $cookie = $resp->header('Set-Cookie'); # Save cookie

  # Save Session ID and Customer Object ID for subsequent API calls
  ($session) = $resp->content =~ m|<SessionID>(\w+)</SessionID>|;
  ($OBJCUST) = $resp->content =~ m|<ObjCust>(\w+)</ObjCust>|;

  # List Devices Request
  my $POST_XML = << "POST_XML";             # Request body
<List>
   <TxnHeader>
      <Request>
          <Login>_LOGIN_</Login>
          <SessionID>_SESSION_</SessionID> </Request>
   </TxnHeader>
   <Source></Source>
</List>
POST_XML

  # Set Login and Session ID from login request response
  $POST_XML =~ s/_LOGIN_/$LOGIN/;
  $POST_XML =~ s/_SESSION_/$session/;

  # Set up HTTP request to list devices and include the cookie from login.
  # Use text/xml and raw POST data to conform to existing REST API.
  $req = HTTP::Request->new(POST => "$REST_SERVER/devices/list");
  $req->header(Cookie => $cookie);
  $req->content_type('text/xml');
  $req->content($POST_XML);
  $resp = $ua->request($req);
  # parse response 
  my $content = $resp->as_string;
  my @lines = split(/\n/, $content);
  my ($sn,$od);
  for (@lines) {
    chomp;
    if (m!TxnName>(\S+?)</TxnName>!) {
      $sn = $1;
      $sn =~ s/%20/ /g;
    } elsif (m!ObjDevice="(\S+?)"!) {
      $sn2id{$sn} = $1;
      $id2sn{$1} = $sn;
    }
  }
}
#---------------------------------------------------------------
#---------------------------------------------------------------
__DATA__
nosite.nodomain.com                              115017
analytics.nodomain.com                           140865
basews.nodomain.com                              111377
csi.nodomain.com                                 66638
enterpriseservices.nodomain.com                  86579
innovation2.nodomain.com                         66659
insights.nodomain.com                            120881
Lake Nona Project                                89865
my.nodomain.com                                  66283
coaching.nodomain.com                            130369
spanish.coaching.nodomain.com                    66669
salud.nodomain.com                               66652
sbs.nodomain.com (stepbystep)                    115093
sftp.nodomain.com                                85217
workshop.nodomain.com                            66650
www.nodomain.org                                 66639
www.morenodomain.org                             72688
www.navynodomain.org                             66649
