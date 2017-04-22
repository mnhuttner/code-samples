#!/usr/bin/perl
#--------------------------------------------------------------------------------
my $title = 'monHostsDf.pl';
my $ver   = '1.0.2';
my $author = 'mhuttner';
my $desc  = 'Collect linux "df" disk utilization stats for Splunk';
# Sends data to Splunk/forwarder via log file in /var/log/ISG/Monitoring/monHostsDf.csv
# Executed via crontab by isgadm@desksub01
#--------------------------------------------------------------------------------
$|++;
use strict;
use Data::Dumper;
my (%hosts,$log,$date,$hf);
#--------------------------------------------------------------------------------
myInit();
getDf();
myEnd();
1;
#--------------------------------------------------------------------------------
sub myInit {
  $ENV{TZ} = "America/New_York";
  my $ln = "/var/log/ISG/Monitoring/monHostsDf.csv";
  open $log, ">>", $ln or die "Could not append $ln: $!\n";
  $hf = "$ENV{HOME}/etc/hosts.ssh.internal";
  open my $fh, "<", $hf or die "Could not read $hf: $!\n";
  while (<$fh>) {
    chomp; next if /^\s*#/;
    $hosts{$1}++ if m/^\s*(\S+)/;
  } close $fh;

  chomp($date = `date`);
  chomp(my $hn = `hostname`);
  print "$title - executing on $hn at $date\n";
  print "# Appending to $ln\n";
}
#--------------------------------------------------------------------------------
sub myEnd {
  close $log;
  exit 1;
}
#--------------------------------------------------------------------------------
sub getDf {
  my (%h);
  my $cmd = "pssh --user mhuttner --hosts $hf --inline-stdout 'echo HOST:\$(hostname -f);  df -hP'";
  my ($ip,$hn);
  open my $fh, "$cmd 2>&1 |" or die "Could not exec $cmd: $!\n";
  print "# $cmd\n";
  while (<$fh>) {
    chomp; next if /^\s*$/; next if /FAILURE|Filesystem/;
    if (m/SUCCESS]\s+(\S+)/) {
      $ip = $1; 
    } elsif (m/^\s*HOST:(\S+)/) {
      $hn = $1; $h{$hn}++;
    } elsif (m/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*$/) {
      my ($fs,$sz,$us,$av,$up,$mt) = ($1,$2,$3,$4,$5,$6);
      $up =~ s/%//;
      next if $mt =~ /^(\/dev|\/run|\/sys)/;
      my $st = "ok";
      $st = "ERROR" if $up >85;
      print $log "$date, monHostsDf, $hn, $mt, $up, $fs, $st\n";
    } else {
      die "ERR($_)\n";
    }
  } close $fh;
  my $cnt = scalar keys %h;
  #map { print "$_\n"; } sort keys %h;
  print "# Total:  $cnt hosts\n";
}
#--------------------------------------------------------------------------------
#--------------------------------------------------------------------------------
