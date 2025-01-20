#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use CGI;
use DBI;

use MIME::Base64;
use Data::Dumper;
use String::CRC32;

use DataBase;
use RuwidoSignalList;

my $q = CGI->new;
my %param = $q->Vars;

my $db = new DataBase();
my $dbh = $db->connect();

$db->cleanupParam(\%param);

my $signalList = new RuwidoSignalList($db, $dbh);

if ($db->{__permission}) {
	my $func_ids = $db->{__fkt};	#signalList->db_get_func(\%param);

	my $sql = "SELECT * FROM function WHERE id IN ($func_ids)";
	my $sth = $dbh->prepare($sql);
	$sth->execute();

	my $data = ({signal => [], 'id' => '0'});

	while(my $row = $sth->fetchrow_hashref()) {
		push @{$data->{signal}}, $row;
	}
	$sth->finish();

	output_to_base64($data) if ($param{output} eq "base64_blob");

	$db->print($q, 1, {remotes => {total => 1, num => 1, remote => $data}}, {-vary => "Accept",
		-access_control_allow_origin => '*',
		-access_control_allow_headers => 'content-type,X-Requested-With',
		-access_control_allow_methods => 'GET,POST,OPTIONS',
		-access_control_allow_credentials => 'true'
	});
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;

sub output_to_base64
{
	my ($remote) = @_;
	my $txt = "";


	$txt .= pack("C", 0x01);	# version
	$txt .= pack("C", keys $remote->{signal});	# number of entries
	foreach my $foo (keys $remote->{signal}) {
		my $fkt = pack("S", $remote->{signal}[$foo]->{id});
		my $len_sig = pack("C", 1);
		my $sig = "";

		if ($param{key} eq "4f5f6683e2ed" ||    #hotwire
		    $param{key} eq "b16e7704eafc"       #telus hostpitality
		) {
			if ($param{type_id} == 9) {
				$fkt |= 1 << 12;
			}
		}
		elsif (defined $param{type_id} && $param{output} eq "base64_blob_layer") {
			$fkt |= ($param{type_id} & 0x1f) << 11;
		}

		$txt .= $fkt . $len_sig . $sig;
	}
	delete $remote->{signal};
	$txt .= pack("L", crc32($txt));
	$txt = encode_base64($txt);
	$txt =~ s/[\r\n ]+//g;
	$remote->{base64}->{content} = $txt;
	$txt = "";
}

