#!/usr/bin/perl
#---------------------------------------------------------------
my $title = 'getAlertSiteOutages.pl';
my $desc  = 'Collect and log AlertSite outage data for yesterday';
# fetches AlertSite stats via REST/API
# sends to splunk/forwarder via log file /var/log/ISG/AlertSite/checkAlertSiteOutages.log
#  via crontab by isgadm@desksub
my $ver   = '1.0.3';
my $author = 'mhuttner';
#---------------------------------------------------------------
$|++;
use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use Data::Dumper;
#---------------------------------------------------------------
my (%sn2id,%id2sn,%conf,$log);
my $interval = shift || 10;

myInit();
myCurl();
myExit();

#---------------------------------------------------------------
sub myInit {
  $ENV{TZ} = "America/New_York";
  $conf{DEBUG} = 1;
  chomp(my $dt = `date`);
  print "# $title($ver) - executing at $dt\n";
  print "# myInit\n" if $conf{DEBUG};
  $conf{SUMMARY} = 1;
  # get time range for report
  my $start = getRange(0);
  my $end   = getRange(10);
  my $range = "start_date=${start}&end_date=${end}";

  $conf{RANGE} = $range;
  print "#-> range($range) interval($interval)\n";
  #$conf{RPTDAY} = 'LastMonth';
  my $ln = '/var/log/ISG/AlertSite/checkAlertSiteOutages.log';
  $conf{LOGNAME} = $ln;
  open $log, ">>", $ln or die "could not create $ln: $!\n";
  print "# Creating $ln\n";
  $conf{DAY} = "?";
  $conf{USER} = $ENV{LOGNAME} || "isgadm";
  chomp(my $pass = `cat ~/.pwd 2>/dev/null`);
  $conf{PASS} = $pass;
}
#---------------------------------------------------------------
sub myExit {
  close $log;
  exit 1;
}
#---------------------------------------------------------------
sub myCurl {
  print "# myCurl- querying outage report\n" if $conf{DEBUG};
  my $date = "?";
  #my $range = "start_date=2016-11-16+12:00:00&end_date=2016-11-16+23:59:59";
  my $range = $conf{RANGE};
  my $cmd = "wget -O - --http-user=$conf{USER}\@nodomain.com --http-passwd=$conf{PASS} 'https://www.alertsite.com/report-api/outage/C43663?&${range}&api_version=2'";
  my $c = $cmd; $c =~ s/$conf{PASS}/*******/;
  print "$c\n" if $conf{DEBUG};
  my $cnt = 0;
  my $out = "";
  open my $fh, "$cmd 2>&1 |" or die "could not exec $c: $!\n";
  while (<$fh>) {
    chomp;
    next if !/outage_start/;
    if (m/outage_start="(\S.*?)" /) {
      my $date = $1;
      $out .= sprintf "[$date] OUTAGE $_\n";
      print $log "[$date] OUTAGE $_\n";
      print ".";
      $cnt++;
    } else {
      die "OOPS($_)\n";
    }
  } close $fh; 
  print " [$cnt]\n";
  print "# OUTPUT:\n$out\n";
}
#---------------------------------------------------------------
sub getSites {
  print "# getSites\n" if $conf{DEBUG};

  # AlertSite REST client-Login, List Devices
  # non-browser REST client needs to manually store cookie
  # login with REST API via URL /user/login, get cookie+resp XML from header
  my $REST_SERVER = 'https://www.alertsite.com/restapi';  # Base path
  my $LOGIN = 'mhuttner@nodomain.com';                      # AlertSite account login
  chomp(my $pass = `cat ~/.pwd 2>/dev/null`);
  #my $PASSWORD = $ENV{PASS} || die "Must set PASS variable!";
  my $PASSWORD = $pass;

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

sub getRange {
  my $int = shift;
  my $cmd = "date -d\"${int} min ago\" \'+%F %H:%M\'";
  chomp(my $d = `$cmd`);
  if (my ($y,$m,$d,$H,$M) = (split/[\s:-]/,$d)[0,1,2,3,4]) {
    return "${y}-${m}-${d}+${H}:${M}:00:00";
  } else {
    die "ERRROR parsing date:($d)\n";
  }
}
#---------------------------------------------------------------
#---------------------------------------------------------------
