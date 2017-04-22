#!/usr/bin/perl
#--------------------------------------------------------------------------------
my $title  = 'monHostsTop.pl';
my $ver    = '1.0.2';
my $author = 'mhuttner';
my $desc   = 'collect linux "top" stats for splunk';
# utilizes parallel SSH tool "pssh" installed in /usr/local/bin
# send to splunk via log file /var/log/ISG/Monitoring/monHostsTop.csv
# run via crontab by isgadm @ desksub
#--------------------------------------------------------------------------------
$|++;
use strict;
use Data::Dumper;
use Socket;
my (%hosts,$log,$date,$hf,$met);

myInit();
getTop();
myEnd();

#--------------------------------------------------------------------------------
sub myInit {
  $ENV{TZ} = "America/New_York";
  $met = 'monHostsTop';
  my $ln = "/var/log/ISG/Monitoring/monHostsTop.csv";
  open $log, ">", $ln or die "Could not append $ln: $!\n";
  $hf = "$ENV{HOME}/etc/hosts.ssh.internal";
  print "# Reading $hf\n";
  open my $fh, "<", $hf or die "Could not read $hf: $!\n";
  while (<$fh>) {
    chomp; next if /^\s*#/;
    $hosts{$1}++ if m/^\s*(\S+)/;
  } close $fh;

  $ENV{TZ} = "America/New_York";
  chomp($date = `date`);
  chomp(my $hn = `hostname`);
  print "# $title($ver) - executing on $hn at $date\n";
  print "# Appending to $ln\n";
}
#--------------------------------------------------------------------------------
sub myEnd {
  close $log;
  exit 1;
}
#--------------------------------------------------------------------------------
sub getTop {
  my (%h);
  my $cmd = "pssh --user mhuttner --hosts $hf --inline-stdout 'echo HOST:\$(hostname -f); top -b | head -6'";
  open my $fh, "$cmd 2>&1 |" or die "Could not exec $cmd: $!\n";
  my ($hn,$ip,$ct,$ut,$ud,$us,$la1,$la5,$la15,$to,$ru,$sl,$st,$zo);
  $hn=$ip=$ct=$ut=$ud=$us=$la1=$la5=$la15=$to=$ru=$sl=$st=$zo="?";
  print "# $cmd\n";
  print "# date, metric, hostname, IP, uptime, users, lavg1, lavg5, lavg15, tasks, running, sleeping, stopped, zombies\n";
  while (<$fh>) {
    chomp;
    next if /FAILURE/;
    if (m/\[SUCCESS\]\s+(\S+)/) {
      $ip = $1;
    } elsif (m/^\s*HOST:(\S+)/) {
      $hn = $1; $h{$hn}++;
    } elsif (m/top -\s+(\S.*)/) {
      my @row = (split/,/,$1);
      ($ct,$ud) = ($1,$2) if $row[0] =~ m/^\s*(\S+)\s+up\s+(\S+)\s+days/;
      ($ut) = $1 if $row[1] =~ m/(\S+)/;
      $ut = "$ud $ut";
      $us = $1 if $row[2] =~ m/^\s*(\S+)\s+user/;
      $la1 = $1 if $row[3] =~ m/(\S+)\s*$/;
      $la5 = $1 if $row[4] =~ m/(\S+)\s*$/;
      $la15 = $1 if $row[5] =~ m/(\S+)\s*$/;
    } elsif (m/\s*Tasks:\s+(\d+)\s+total,\s+(\d+)\s+running,\s*(\d+)\s+sleeping,\s+(\d+)\s*stopped,\s*(\d+)\s*zombie/) {
      ($to,$ru,$sl,$st,$zo) = ($1,$2,$3,$4,$5);
      print $log "$date,$met,$hn,$ip,$ut,$us,$la1,$la5,$la15,$to,$ru,$sl,$st,$zo\n";
      $ct=$ut=$ud=$us=$la1=$la5=$la15=$to=$ru=$sl=$st=$zo="?";
    }
  } close $fh;
  my $cnt = scalar keys %h;
  print "# Total:  $cnt hosts\n";
  chomp($date = `date`);
  print "# Completed: $date\n";
}
#--------------------------------------------------------------------------------
#--------------------------------------------------------------------------------
