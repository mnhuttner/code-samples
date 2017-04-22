#!/usr/bin/perl
#-----------------------------------------------------------------------------
my $ver    = '1.0.4';
my $desc   = 'check IPA replication monitoring script';
my $author = 'mhuttner';
#-----------------------------------------------------------------------------
$|++;
my $title  = 'checkIpaReplication.pl';
use strict;
use Getopt::Long;
use Data::Dumper;
my (%data,%conf,%servers,%opt);

myInit();
getResult($conf{s1});
getResult($conf{s2});
checkResults();
notify();
exit $conf{status};

#-----------------------------------------------------------------------------
sub myInit {
  $ENV{TZ} = "America/New_York";
  $conf{status}  = 1;
  $conf{test}    = 0;
  $conf{pass}    = 'JLww##Do@6N8';
  $conf{s1}      = 'ns01.dev.healthmedia.net';
  $conf{s2}      = 'ns02.dev.healthmedia.net';
  chomp(my $date = `date`);
  chomp(my $host = `hostname -f`);
  chomp(my $id   = `whoami`);
  GetOptions(
    'verbose' => \$conf{verbose},
    'debug'   => \$conf{debug},
    'test'    => \$conf{test},
    'version' => \$conf{version},
    'usage|help' => \$conf{usage},
  );
  myUsage() if $conf{usage};
  myVersion() if $conf{version};
  print "# $title($ver) - $desc\n";
  print "# Executing as $id on $host at $date ($conf{test})\n";
}
#-----------------------------------------------------------------------------
sub checkResults {
  $conf{data} = "ID, TYPE, STATUS, $conf{s1}, $conf{s2}\n";

  for my $id (sort keys %data) {
    # compare s1 with s2 values
    my $v1r = $data{$id}->{$conf{s1}}->{REPLICA} || "?";
    my $v1l = $data{$id}->{$conf{s1}}->{LASTMOD} || "?";
    my $v2r = $data{$id}->{$conf{s2}}->{REPLICA} || "?";
    my $v2l = $data{$id}->{$conf{s2}}->{LASTMOD} || "?";

    # comparison results
    my $sl = "ERROR"; $sl = "OK" if $v1l eq $v2l;
    my $sr = "ERROR"; $sr = "OK" if $v1r eq $v2r;
    $conf{data} .= "$id, REPLICA, $sr, $v1r, $v2r\n";
    $conf{data} .= "$id, LASTMOD, $sl, $v1l, $v2l\n";
    print "# REPLICA: $id : $conf{s1} => $sr ($v1r === $v2r) \n";
    print "# LASTMOD: $id : $conf{s2} => $sl ($v2l === $v2l) \n";
    $conf{status} = 0 if ($sr eq "ERROR" or $sl eq "ERROR");
  }
  print "# Final status: = $conf{status}\n";
}
#-----------------------------------------------------------------------------
sub getResult {
  my $server = shift;
  my $cmd = 'ldapsearch -h ' . $server . ' -D "cn=directory manager" -w "' . $conf{pass} . '" -b "o=ipaca" "(&(objectclass=nstombstone)(nsUniqueId=ffffffff-ffffffff-ffffffff-ffffffff))" nscpentrywsi | perl -p00e \'s/\r?\n //g\'';
  my $c = $cmd;  $c =~ s/$conf{pass}/********/;
  print "# Executing cmd: ($c)\n";  # Note, masked cleartext password output
  my $fn = "/var/tmp/$server.ldap";
  open my $fh2, ">", $fn or die "Could not create $fn: $!\n";
  print "# Creating $fn\n";
  open my $fh, "$cmd 2>&1 |" or die "Could not exec $cmd: $!\n";
  while (<$fh>) {
    chomp;
    print $fh2 "$_\n";
    if ($conf{debug}) {
      print "[DEBUG] $_\n";
    }
    if (m/nsruvReplicaLastModified:\s*{replica\s+(\d+)\s+ldap:\/\/([^\.]+)\S*\s+(\S.*\S)\s*$/) { 
      my ($id,$hn,$val) = ($1,$2,$3);
      $data{"$id:$hn"}->{$server}->{LASTMOD} = $val;
    } elsif (m/{replica\s+(\d+)\s+ldap:\/\/([^\.]+)\S*\s+(\S.*\S)\s*$/) {
      my ($id,$hn,$val) = ($1,$2,$3);
      $data{"$id:$hn"}->{$server}->{REPLICA} = $val;
    }
  } close $fh;
  system("chmod 666 $fn");
}
#-----------------------------------------------------------------------------
sub notify {
  my $cmd = "/usr/local/bin/isgMonNotify.pl -env prod -severity warning -source checkIPA -summary \"IPA replication error $conf{test}\" -msg \'$conf{data}\' ";
  if (! $conf{status} or $conf{test}) {
    print "ERROR detected in status: $conf{status}\n";
    print "# Executing: $cmd\n";
    system($cmd);
  } else {
    print "GOOD status: $conf{status}\n";
  }
}
#-----------------------------------------------------------------------------
sub myVersion {
  print "$ver\n"; exit 1;
}
#-----------------------------------------------------------------------------
sub myUsage {
  my $msg = shift || "";
  if ($msg ne "") { $msg = "ERROR: $msg\n"; }
  print <<EOF;
$title($ver) - $desc
$msg
Usage: $title [flags|args]
Flags
  -verbose|debug|usage|help|version
  -test         [execute test scenario, see example below]
Args:

  Eg: $title  # no arguments, performs IPA comparison test
      $title --version
      $title --debug

EOF
  exit 1;
}
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
