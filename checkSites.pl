#!/usr/bin/perl
#-------------------------------------------------------------------
my $title = 'checkSites.pl';
my $ver   = '1.0.3';
my $desc   = 'Check connectivity/response times to each production URL/site';
# Sends data to Splunk/forwarder via log file /var/log/ISG/AlertSite/checkSites.log
#  called via crontab by isgadm@desksub01
my $author = 'mhuttner@nodomain.com';
#-------------------------------------------------------------------
$|++;
use strict;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);
use Getopt::Long;
my (%sites,%conf,$log);

myInit();
for my $sn (sort keys %sites) {
  checkSite($sn);
}
myEnd();
#-------------------------------------------------------------------
sub myEnd {
  if ($conf{write}) {
    close $log;
  }
  exit 1;
}
#-------------------------------------------------------------------
sub myInit {
  $ENV{TZ} = "America/New_York";
  $conf{USER} = "mhuttner";
  chomp(my $pass = `cat $ENV{HOME}/.pwd`);
  $ENV{PASS} = $pass;
  $conf{PASS} = $ENV{PASS} or die "Could not set PASS!\n";
  my $logname = "/var/log/ISG/AlertSite/checkSites.log";


  # Reads data at the end of this script
  while (<DATA>) {
    next if /^\s*#/;
    my ($url,$snm,$sid,$cim,$tos,$ip,$ul) = (split/\s*,\s*/);
    $sites{$snm}->{URL} = $url;   # URL to monitor
    $sites{$snm}->{ID}  = $sid;   # site ID (alertSite device)
    $sites{$snm}->{CIM} = $cim;   # check interval (minutes)
    $sites{$snm}->{TOS} = $tos;   # timeout interval (seconds)
    $sites{$snm}->{IP}  = $ip;    # IP address
    $sites{$snm}->{UL}  = $ul;    # user login used?
  }
  GetOptions(
    'verbose'    => \$conf{verbose},
    'debug'      => \$conf{debug},
    'help|usage' => \$conf{usage},
    'version'    => \$conf{version},
  );
  $conf{verbose} = 1 if $conf{debug};
  myUsage() if $conf{usage};
  if ($conf{version}) { print "$ver\n"; exit 1; }

  print "# $title($ver) - $desc\n";
  
  $conf{write} = 0;
  if (open $log, ">>", $logname) {
    print "# Appending to $logname\n";
    $conf{write} = 1;
  } else {
    print "# WARNING: could not write $logname: $!\n# Will send output to STDOUT\n";
  }
  if (!$conf{write}) { print "# Date, Site status elapsed/time/secs\n"; }
}
#-------------------------------------------------------------------
sub checkSite {
  my $sn = shift;
  my $t0 = [gettimeofday];
  my $url = qq($sites{$sn}->{URL}) || die "No URL for $sn!\n";
  my $cmd = "wget -O - --no-check-certificate --http-user=$conf{USER}\@nodomain.com --http-passwd=$conf{PASS} \"$url\"";
  my $c = $cmd; $c =~ s/$conf{PASS}/*****/;
  print "# $c\n" if $conf{verbose};
  my $status = "FAILED";
  open my $fh, "$cmd 2>&1 |" or die "Could not exec $cmd: $!\n";
  while (<$fh>) {
    chomp;
    $status = "OK" if /HTTP request sent, awaiting response... 200 OK/;
    print "$_\n" if $conf{debug};
  } close $fh;
  my $end = time();
  my $elapsed = tv_interval($t0);
  chomp(my $date = `date`);
  if ($conf{write}) {
    print $log "$date \"$sn\" $status $elapsed\n";
  } else {
    print "$date \"$sn\" $status $elapsed\n";
  }
  #printf "%-50s %s (%s)\n",$sn,$status,$elapsed;
}
#-------------------------------------------------------------------
sub myUsage {
  my $msg = shift || "";
  print "ERROR: $msg\n" if $msg ne "";
  print <<EOF;
$title($ver) - $desc

Usage: $title [flags|args]
Flags:
  -verbose|debug|usage|help
  -version

Eg:
  $title        # will execute default check
  $title -usage # this help output
  $title -debug 

EOF
 exit 1;
}
#-------------------------------------------------------------------
#  Only edit this to change monitored scripts
#   This came from AlertSite configuration/monitoring section data
#-------------------------------------------------------------------
#siteUrl, siteName, siteId, checkIntMin, timeOutIntSec, ipAddress, useLogin
#https://aboutlakenonalifeproject.com/contact-us, Lake Nona Project, 89865, 15, 30, 206.188.0.132, Y
## disabled Thu Dec  1 18:07:05 UTC 2016
__DATA__
http://xxx.nodomain.com, xxx.nodomain.com, 115017, 15, 45, 63.131.128.204, Y
https://analytics.nodomain.com/cognos10/cgi-bin/cognosisapi.dll?b_action=xts.run&m=portal/main.xts&startwel=yes, analytics.nodomain.com, 140865, 15. 30, 65.17.214.218, Y
https://basews.nodomain.com/axis2/monitor2.html, basews.nodomain.com, 111377, 15, 30, 65.17.237.190, N
https://csi.nodomain.com/monitor2.html, csi.nodomain.com, 66638, 15, 30, 65.17.237.173, N
https://enterpriseservices.nodomain.com/rest/Y2hiYXBhc3N3b3Jk/Y2hiYTg2NzUzMDk=/US/123MsgId/456/TEST_MATT091610A/invalidpassword/authentication.json, enterpriseservices.nodomain.com, 86579, 5, 30, 65.17.237.179, Y
https://innovation2.nodomain.com/terms-of-use, innovation2.nodomain.com, 66659, 15, 30, 209.18.103.84, N
https://insights.nodomain.com/cognos10/cgi-bin/cognosisapi.dll?b_action=xts.run&m=portal/main.xts&startwel=yes, insights.nodomain.com, 120881, 15, 30, 209.18.103.84, N
http://www.jjhws.com, jjhws.com, 120875, 15, 30, 209.18.103.43, Y
https://my.nodomain.com/monitor2-mhm.html, my.nodomain.com, 66283, 2, 30, 65.17.237.166, Y
https://coaching.nodomain.com/terms-of-use, Nosite - coaching.nodomain.com, 130369, 5, 30, 209.18.67.130, Y
https://coaching.nodomain.com:443/choose-language/es, Nosite Spanish coaching.nodomain.com, 66669, 5, 60, 209.18.67.130, Y
https://salud.nodomain.com/monitor2.html, salud.nodomain.com, 66652, 15, 30, 65.17.237.191, N
http://sbs.nodomain.com/monitor2.html, sbs.nodomain.com stepbystep, 115093, 15, 30, 65.17.237.180, Y
https://sftp.nodomain.com, sftp.nodomain.com, 85217, 5, 30, 65.17.223.119, N
https://sleepworkshop.my-coach.com/monitor2.html, sleepworkshop.my-coach.com, 66650, 15, 60, 65.17.237.181, N
https://nodomain.org/healthmonitor.php, nodomain.org, 66639, 2, 30, 65.17.237.167, Y
