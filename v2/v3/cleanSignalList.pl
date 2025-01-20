#!/usr/bin/perl

use CGI;
use DBI;
use MIME::Base64;
use Data::Dumper;
use String::CRC32;

use DataBase;
use RuwidoSignalList;

my $db = new DataBase();
my $dbh = $db->connect();

my $signalList = new RuwidoSignalList($db, $dbh);

my $q = CGI->new;
my %param = $q->Vars;

if ($db->checkAccess(\%param)) {
	my $func_ids = $signalList->db_get_func(\%param);

	my $sql = "SELECT * FROM func_to_name WHERE id IN ($func_ids)";
	my $sth = $dbh->prepare($sql);
	$sth->execute();

	my $data = ({signal => [], 'id' => '0'});

	while(my $row = $sth->fetchrow_hashref()) {
		push $data->{signal}, $row;
	}
	$sth->finish();

	output_to_base64($data) if ($param{output} eq "base64_blob");



	if ($param{key} eq $signalList->{key_master}) {
		$db->print($q, 1, {sql => $signalList->{sql}, database => $db->{db}, remotes => {total => 1, num => 1, remote => $data}}, {-vary => "Accept",
			-access_control_allow_origin => '*',
			-access_control_allow_headers => 'content-type,X-Requested-With',
			-access_control_allow_methods => 'GET,POST,OPTIONS',
			-access_control_allow_credentials => 'true'
		});
	} else {
		$db->print($q, 1, {remotes => {total => 1, num => 1, remote => $data}}, {-vary => "Accept",
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
	my ($remote) = @_;
	my $txt = "";

#	foreach my $id (keys $remote) {
		$txt .= pack("C", 0x01);	# version
		$txt .= pack("C", scalar keys $remote->{signal});	# number of entries
		foreach my $foo (keys $remote->{signal}) {
			my @arr = split (/,/, $remote->{signal}[$foo]->{content});
			my $fkt = pack("S", $remote->{signal}[$foo]->{id});
			my $len_sig = pack("C", scalar @arr);
			my $sig = pack("H*", join "", @arr);

			$txt .= $fkt . $len_sig . $sig;
		}
		delete $remote->{signal};
		$txt .= pack("L", crc32($txt));
		$txt = encode_base64($txt);
		$txt =~ s/[\r\n ]+//g;
		$remote->{base64}->{content} = $txt;
		$txt = "";
#	}
}

