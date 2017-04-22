#!/usr/bin/perl
#-----------------------------------------------------------------
my $title = 'getNewRelicAppStats.pl';
my $ver   = '1.0.2';
my $desc  = 'Collect application stats from newrelic via API for splunk';
# uses "curl" to newrelic API url to fetch JSON result statistics
#  sends to splunk via log file /var/log/ISG/NewRelic/getNewRelicAppStats.csv
#  executed via crontab by isgadm@desksub
my $author = 'mhuttner';
#-----------------------------------------------------------------
$|++;
use strict;
use Data::Dumper;
use Getopt::Long;
use JSON;
#-----------------------------------------------------------------
# config data for J&J
my (%apps,%conf,$log);

myInit();
getApps();
for my $appid (sort keys %apps) {
   getAppMetrics($appid);
   getAppInstMetrics($appid);
}
myEnd();

#-----------------------------------------------------------------
sub myInit {
  $ENV{TZ} = "America/New_York";
  $conf{app}     = '13464';
  $conf{apikey}  = '0ff1c518ae83740b53a10a020ef9665f107404734255239';
  $conf{verbose} = 1;
  $conf{debug}   = 0;
  $conf{logname} = '/var/log/ISG/NewRelic/getNewRelicAppStats.csv';
  chomp($conf{date} = `date`);
  GetOptions(
    'verbose' => \$conf{verbose},
    'debug'   => \$conf{debug},
  );
  open $log, ">>", $conf{logname} or die "Could not append to $conf{logname}: $!\n";
  print "# Appending $conf{logname} - $conf{date}\n";
}
#-----------------------------------------------------------------
sub myEnd {
  close $log;
  chomp($conf{date} = `date`);
  print "# Completed at $conf{date}\n\n";
  1;
}
#-----------------------------------------------------------------
sub getAppMetrics {
  my $appid = shift;
  my $aname  = $apps{$appid} || "UNKNOWN";
  print "# getAppMetrics ($appid:$aname)\n" if $conf{verbose};
  my $cmd = "curl -s -X GET https://api.newrelic.com/v2/applications/${appid}/metrics/data.json -H X-Api-Key:$conf{apikey} -d \'names[]=CPU/User+Time&names[]=Agent/MetricsReported/count&names[]=HttpDispatcher&names[]=Memory/Physical&names[]=WebTransaction&names[]=&summarize=true&raw=true\' ";
  my $json = "";
  open my $fh, "$cmd 2>&1|" or die "Could not exec $cmd: $!\n";
  print "$cmd\n" if $conf{debug};
  while (<$fh>) { chomp; $json .= $_; } close $fh;
  if ($json =~ /^\s*$/) { print "# No output for $appid:$aname\n" if $conf{verbose}; return; }
  my $j  = decode_json $json;
  my %j = %{$j};
  for my $app (sort @{$j{metric_data}->{metrics}}) {
    my $name = $app->{name};
    for my $k (sort keys %{$app->{timeslices}[0]->{values}}) {
      my $v = $app->{timeslices}[0]->{values}->{$k};
      print $log "$conf{date}, NewRelicAppMetrics, $aname, $name, $k, $v\n";
    }
  }
}
#-----------------------------------------------------------------
sub getAppInstMetrics {
  my $appid = shift;
  my $aname  = $apps{$appid} || "UNKNOWN";
  print "# getAppInstMetrics($appid:$aname)\n" if $conf{verbose};
  my $cmd = "curl -s -X GET https://api.newrelic.com/v2/applications/${appid}/instances.json -H X-Api-Key:$conf{apikey} ";
  my $json = "";
  open my $fh, "$cmd 2>&1|" or die "Could not exec $cmd: $!\n";
  print "$cmd\n" if $conf{debug};
  while (<$fh>) { chomp; $json .= $_; } close $fh;
  if ($json =~ /^\s*$/) { print "# No output for $appid:$aname\n" if $conf{verbose}; return; }
  my $j  = decode_json $json;
  #print Dumper(\$j); exit; #print Dumper(\$j->{application_instances}); exit;
  for my $app (sort @{$j->{application_instances}}) {
    my $host          = $app->{host};
    my $health_status = $app->{health_status};
    for my $k (sort keys %{$app->{application_summary}}) {
      my $v = $app->{application_summary}->{$k};
      print $log "$conf{date}, NewRelicAppInstMetrics, $aname, $host, $health_status, $k, $v\n";
    }
  }
}
#-----------------------------------------------------------------
sub getApps {
  print "# getApps\n" if $conf{verbose};
  my $cmd = "curl -s -X GET https://api.newrelic.com/v2/applications.json -H X-Api-Key:$conf{apikey} ";
  my $json = "";
  open my $fh, "$cmd 2>&1|" or die "Could not exec $cmd: $!\n";
  print "$cmd\n" if $conf{debug};
  while (<$fh>) {
    chomp; $json .= $_;
  } close $fh;
  my $j  = decode_json $json;
  if ($json =~ /^\s*$/) { die "# No output for $cmd\n"; }
  for my $app (sort @{$j->{applications}}) {
    my $id   = $app->{id};
    my $name = $app->{name};
    $apps{$id} = $name;
  }
}
#-----------------------------------------------------------------
#-----------------------------------------------------------------
