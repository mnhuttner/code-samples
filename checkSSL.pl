#!/usr/bin/perl
#-------------------------------------------------------------------
my $title = 'checkSSL.pl';
my $ver   = '1.0.3';
my $desc   = 'check SSL certificate expiry on listed sites/hosts';
# sends data to Splunk/forwarder via log file in /var/log/ISG/Monitoring/checkSSL.log
# called via batch scheduler as isgadm@desksub01
my $author = 'mhuttner';
#-------------------------------------------------------------------
$|++;
use Data::Dumper;
use Date::Manip;
use Time::Piece;
use POSIX qw(strftime);
use Socket;
#-------------------------------------------------------------------
my (%sites,$log,$now,$date);

myInit();
for my $sn (sort keys %sites) {
  checkSite($sn);
}
myEnd();
#-------------------------------------------------------------------
sub myEnd {
  close $log;
  chomp($date = `date`);
  print "# Completed at: $date\n";
  exit 1;
}
#-------------------------------------------------------------------
sub myInit {
  $ENV{TZ} = "America/New_York";
  my $logname = "/var/log/ISG/Monitoring/checkSSL.log";
  open $log, ">>", $logname or die "could not write $logname: $!\n";
  print "# Appending to $logname\n";
  $now = strftime("%Y%m%d%H:%M:%S",localtime);
  chomp($date = `date`);
  print "# $title($ver) started at $date\n";
  # This uses embedded data at the bottom of this script
  while (<DATA>) {
    next if /^\s*#/;
    my ($url) = (split/\s*,\s*/);
    chomp($url);
    $sites{$url}++;
  }
}
#-------------------------------------------------------------------
sub checkSite {
  my $sn = shift;
  my $hn = "?";
  my $ip = "?";
  #print "# Checking $sn\n";
  if ($sn =~ /^[0-9][0-9]/) {
    $ip = $sn;
    chomp($hn = `ssh mhuttner\@$ip "hostname -f" 2>/dev/null`);
  } else {
    $hn = $sn;
    my $tmp = inet_aton($hn) || "?";
    if ($tmp eq "?") {
      print "# Invalid site($sn) cannot resolve IP\n";
      $ip = "unknown";
    } else {
      $ip = inet_ntoa(inet_aton($hn));
    }
  }
  my $cmd = "echo | openssl s_client -connect $sn:443 2>/dev/null | openssl x509 -noout -dates";
  #print "# $cmd\n";
  my $status = "FAILED";
  open my $fh, "$cmd 2>&1 |" or die "Could not exec $cmd: $!\n";
  while (<$fh>) {
    chomp;
    if (m/notAfter=(\S.*)/) {
      #print "#-> $1\n";
      my $str = $1; chomp($str); $str =~ s/\/n//g; $str =~ s/\/r//g;
      my $str2 = ParseDate($str);
      my $d1 = Time::Piece->strptime($now, "%Y%m%d%H:%M:%S");
      my $d2 = Time::Piece->strptime($str2, "%Y%m%d%H:%M:%S");
      my $diff = $d2 - $d1;
      my $days = int($diff->days);
      my $status = "ok";
      if ($days < 1) {
        $status = "ERROR:$str";
      }
      print $log "$date,$hn,$ip,$days,$status\n";
      #print "$date,$hn,$ip,$days,$status\n";
    }
  } close $fh;
}
#-------------------------------------------------------------------
#  Only edit this if you need to change what is monitored
#-------------------------------------------------------------------
__DATA__
7minute.nodomain.com
analytics.nodomain.com
basews.nodomain.com
csi.nodomain.com
enterpriseservices.nodomain.com
innovation2.nodomain.com
insights.nodomain.com
www.jjhws.com
my.nodomain.com
coaching.nodomain.com
coaching.nodomain.com
salud.nodomain.com
sbs.nodomain.com
sftp.nodomain.com
workshop.my-coach.com
nodomain2.org
#--------------------------------------------------------------------
10.30.12.45
10.30.2.81
10.30.33.5
192.168.148.22
192.168.148.32
192.168.148.33
192.168.148.34
192.168.148.35
192.168.148.38
192.168.148.40
192.168.148.46
192.168.148.49
192.168.148.53
192.168.148.58
192.168.148.59
192.168.148.61
192.168.151.10
192.168.151.11
192.168.151.12
192.168.151.13
192.168.151.14
192.168.151.4
192.168.151.5
192.168.151.9
#--------------------------------------------------------------------
