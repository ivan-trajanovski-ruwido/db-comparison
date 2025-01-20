#!/usr/bin/perl

use CGI;
use DBI;
use MIME::Base64;
use Data::Dumper;
use String::CRC32;

use DataBase;
use RcSignalDecode;
use RuwidoSignalList;

my $db = new DataBase();
my $dbh = $db->connect();

my $signalList = new RuwidoSignalList($db, $dbh);

my $q = CGI->new;
my %param = $q->Vars;

$param{oem_id} = $param{code} if (defined $param{code});        # temporary preparation forbeing able to use "codes" in the future

$param{model_id} = '' if (defined $param{model_id} && $param{model_id} eq "true");              # HACK for jquery
$param{model_name} = '' if (defined $param{model_name} && $param{model_name} eq "true");        # HACK for jquery
$param{debug} = 0 if (!exists $param{debug});
$param{debug} = 0 if ($param{output} eq "base64_blob");

delete $param{brand_id} if ($param{brand_id} eq '');
delete $param{brand_name} if ($param{brand_name} eq '');
delete $param{model_id} if ($param{model_id} eq '');
delete $param{model_name} if ($param{model_name} eq '');

delete $param{type_id} if ($param{type_id} == 0);
delete $param{type_id} if ($param{type_id} eq '');

### Ericsson, Bell, Telus
if ($param{key} eq "f6bc3e6fd3a3" || $param{key} eq "5d22af224da8" || $param{key} eq "3da1344683b4") {
#	$param{compress} = 2;
	$param{age} = 7;
	$param{debug} = 0;
}

if ($param{compress} >= 2) {
	$param{weight} = 1;
}

$param{debug} = 0 if (!$db->checkAccessDebug(\%param));
$param{fkt_required} = $signalList->_func_expand($param{fkt_required}) if (defined $param{fkt_required});

if (!exists $param{fkt}) {
	$param{fkt} = $param{fkt_required};
} elsif ($param{fkt_required} && $param{fkt} ne "") {
	$param{fkt} .= "," . $param{fkt_required};
} 

if ($db->checkAccess(\%param)) {
	$signalList->get_signal($q, \%param);

	output_to_base64() if ($param{output} eq "base64_blob");

	if ($param{key} eq $signalList->{key_master}) {
		$db->print($q, $signalList->{total}, {sql => $signalList->{sql}, database => $db->{db}, remotes => {total => $signalList->{total}, num => $signalList->{num}, remote => $signalList->{remote}}}, {-vary => "Accept",
			-access_control_allow_origin => '*',
			-access_control_allow_headers => 'content-type,X-Requested-With',
			-access_control_allow_methods => 'GET,POST,OPTIONS',
			-access_control_allow_credentials => 'true'
		});
	} else {
		$db->print($q, $signalList->{total}, {remotes => {total => $signalList->{total}, num => $signalList->{num}, remote => $signalList->{remote}}}, {-vary => "Accept",
			-access_control_allow_origin => '*',
			-access_control_allow_headers => 'content-type,X-Requested-With',
			-access_control_allow_methods => 'GET,POST,OPTIONS',
			-access_control_allow_credentials => 'true'
		});
	}
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;

sub output_to_base64
{
	my $txt = "";

	foreach my $id (keys $signalList->{remote}) {
		$txt .= pack("C", 0x01);	# version
		$txt .= pack("C", scalar keys $signalList->{remote}[$id]->{signal});	# number of entries
		foreach my $foo (keys $signalList->{remote}[$id]->{signal}) {
			my @arr = split (/,/, $signalList->{remote}[$id]->{signal}[$foo]->{content});
			my $fkt = pack("S", $signalList->{remote}[$id]->{signal}[$foo]->{id});
			my $len_sig = pack("C", scalar @arr);
			my $sig = pack("H*", join "", @arr);

			$txt .= $fkt . $len_sig . $sig;
#			$txt .= $signalList->{remote}[$id]->{signal}[$foo]->{id} . " " . $sig;
		}
		delete $signalList->{remote}[$id];
		$txt .= pack("L", crc32($txt));
		$txt = encode_base64($txt);
		$txt =~ s/[\r\n ]+//g;
		$signalList->{remote}[$id]->{base64}->{content} = $txt;
		$txt = "";
	}
}

