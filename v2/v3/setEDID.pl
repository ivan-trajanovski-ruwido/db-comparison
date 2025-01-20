#!/usr/bin/perl -w

use strict;
use CGI;
use DBI;
use MIME::Base64;
use Data::Dumper;
use String::CRC32;

use DataBase;
use MetaEDID;
use RuwidoSignalList;

$CGI::POST_MAX = 1024 * 1024;

my $ruwido_rc = "ruwido_rc";
my $ruwido_meta = "ruwido_rc_meta";

my $db = new DataBase();
my $dbh = $db->connect();
my $signalList = new RuwidoSignalList($db, $dbh);

binmode(STDIN);	#NOTE: this is critical for correctly handling the transmitted binary data

my $q = CGI->new;
my %param = $q->Vars;
my %edid;

sub update_edid
{
	my ($edid) = @_;

	my $old_db = $db->{db};
	$db->{db} = $db->{db_schema_meta};
	my $dbh = $db->connect();
	$db->{db} = $old_db;

	$dbh->do("SELECT * FROM edid WHERE fingerprint = ?", undef, $edid->fingerprint());
	my ($found) = $dbh->selectrow_array("SELECT FOUND_ROWS()");

	if (!$found) {
		my $sth = $dbh->prepare("INSERT IGNORE INTO edid (pnp_id, pnp_txt, product_code, product_serial, manuf_year, manuf_week, monitor_name, monitor_serial, raw, fingerprint, cmnt_brand, cmnt_model) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)");
		$sth->execute($edid->{manufacturer_id}, $edid->{manufacturer_name}, $edid->{product_code}, $edid->{serial_number}, $edid->{year}, $edid->{week}, $edid->{emonitor_name}, $edid->{emonitor_serial}, $edid->{raw}, $edid->fingerprint(), $param{brand}, $param{model}) or return undef;
		$dbh->commit();
	}
	$dbh->disconnect();
}

sub get_all
{
	my ($fingerprint) = @_;

	my $sql = "SELECT *, edid.id AS edid_id, pnp_id, brand.name as brand_name, equipment.name AS model_name ";
	$sql .= "FROM ruwido_rc_meta.edid ";
	$sql .= "LEFT JOIN ruwido_rc_meta.edid_to_equipment ON edid.id = edid_id ";
	$sql .= "LEFT JOIN ruwido_rc.equipment_to_rc_info ON edid_to_equipment.equipment_id = equipment_to_rc_info.equipment_id ";
	$sql .= "LEFT JOIN ruwido_rc.equipment ON equipment.id = edid_to_equipment.equipment_id ";
	$sql .= "LEFT JOIN ruwido_rc.rc_info ON rc_info.id = equipment_to_rc_info.rc_info_id ";
	$sql .= "LEFT JOIN ruwido_rc.brand ON brand.id = equipment.brand_id ";
	$sql .= "WHERE fingerprint = ? ";
	$sql .= "ORDER BY cmnt_brand, product_code";

#print $sql;

#FIXME: multiples matches for a single fingerprint?
	my $sth = $dbh->prepare($sql);
	$sth->execute($fingerprint);
	return (undef, undef, undef) unless ($dbh->selectrow_array("SELECT FOUND_ROWS()"));

	my $row = $sth->fetchrow_hashref();

	my $brand_id = $row->{brand_id};
	my $brand_name = $row->{brand_name};

	my $items_brand = { item => [{ name => $brand_name, id => $brand_id }]};
	my $items_model = { id => $row->{edid_id} };
	my $items_signal = undef;

	if ($brand_id) {
		if (defined $row->{model_name}) {
			$items_model = { item => [{ name => $row->{model_name}, id => $row->{rc_oem_id} }]};
		}

		if ($param{codes}) {
			$items_signal = get_codes($brand_id, $row->{rc_oem_id});
		} else {
			$items_signal = get_signals($brand_id, $row->{rc_oem_id});
		}
		$sth->finish();
	}

	return ($items_brand, $items_model, $items_signal);
}

sub get_brand
{
	my ($pnp_id) = @_;

	my $sth = $dbh->prepare("SELECT brand.id, brand.name FROM $ruwido_meta.pnp_to_brand, $ruwido_rc.brand WHERE pnp_to_brand.brand_id = brand.id AND pnp_id = ?");
        $sth->execute($pnp_id);

#FIXME: multiples matches for a single fingerprint?
	my $row = $sth->fetchrow_hashref();

	return ($row->{id}, $row->{name});
}

sub get_brand2
{
	my ($pnp_id) = @_;

	my ($brand_id, $brand_name) = get_brand($pnp_id);

	my $items_brand = { item => [{ name => $brand_name, id => $brand_id }]};
	my $items_model = undef;	# $items_model = { id => "X" };
	my $items_signal = undef;

	if ($brand_id) {
		if ($param{codes}) {
			$items_signal = get_codes($brand_id, undef);
		} else {
			$items_signal = get_signals($brand_id, undef);
		}
	}

	return ($items_brand, $items_model, $items_signal);
}

########################################
$param{edid} =~ s/\ /\+/g;	# TM 20160817 dirty hack
$param{edid} = decode_base64($param{edid}) if ($param{edid});
$param{brand} =~ s/^\ +// if ($param{brand});
$param{brand} =~ s/\ +$// if ($param{brand});
$param{model} =~ s/^\ +// if ($param{model});
$param{model} =~ s/\ +$// if ($param{model});

#my @param_arr = ("key", "fkt", "output", "codes", "revision_id", "project_id");
#foreach my $item (@param_arr) {
foreach my $item (("key", "fkt", "output", "codes", "revision_id", "project_id", "type_id")) {
	$param{$item} = $q->url_param($item) if (!defined $param{$item});
}
#$param{key} = $q->url_param('key') if (!defined $param{key});
#$param{fkt} = $q->url_param('fkt') if (!defined $param{fkt});
#$param{output} = $q->url_param('output') if (!defined $param{output});
#
#$param{codes} = $q->url_param('codes') if (!defined $param{codes});
#$param{revision_id} = $q->url_param('revision_id') if (!defined $param{revision_id});
#$param{project_id} = $q->url_param('project_id') if (!defined $param{project_id});

if ($param{key} eq "f6bc3e6fd3a3") {
	#$param{compress} = 2;
	$param{age} = 7;
}

if (1) {	#$db->checkAccess(\%param)) {
	my $meta = new MetaEDID();
	my $edid = $meta->parse($param{edid});

	if (!defined $edid) {
		$db->print_error ($q, 200, "Failed to parse EDID information ");
		goto END;
	}

#	update_edid($edid);

	########################################

	my ($brands, $models, $remotes);

#print Dumper $edid;
#	($brands, $models, $remotes) = get_all($edid->fingerprint());
	($brands, $models, $remotes) = get_brand2($edid->{manufacturer_id}) unless (defined $brands);

#print Dumper $remotes;
	if ($remotes) {
#	$db->print($q, $signalList->{total}, {remotes => {total => $signalList->{total}, num => $signalList->{num}, remote => $signalList->{remote}}}, {-vary => "Accept",
#		$db->print2($q, 1, {brands => $brands, models => $models, remotes => {total => $signalList->{total}, num => $signalList->{num}, remote => $remotes}}, {-vary => "Accept"});
		$db->print($q, $signalList->{total}, {brands => $brands, models => $models, remotes => {total => $signalList->{total}, num => $signalList->{num}, remote => $remotes}}, {-vary => "Accept",
                        -access_control_allow_origin => '*',
                        -access_control_allow_headers => 'content-type,X-Requested-With',
                        -access_control_allow_methods => 'GET,POST,OPTIONS',
                        -access_control_allow_credentials => 'true'
                });
	} else {
		$db->print($q, 0, {}, {-vary => "Accept"});
	}
} else {
	$db->print_error($q, 401, "Unauthorized");
}

END:
$db->disconnect();

exit;

sub get_signals
{
	my ($brand_id, $oem_id) = @_;

	my %pa;
	$pa{key} = $param{key};
	$pa{limit} = 3;
	$pa{type_id} = 1;
	$pa{type_id} = $param{type_id} if (defined $param{type_id});
	$pa{brand_id} = $brand_id;
	$pa{fkt} = $param{fkt};
	$pa{oem_id} = $oem_id if ($oem_id);

	$pa{compress} = 2;	#$param{compress};
	$pa{age} = 7;	#$param{age};
	$pa{weight} = 1;	#$param{weight};
#	$pa{debug} = 3;
#	$pa{oem_id_min} = 13000;
#	$pa{year} = 2009;
#	$pa{fkt} = $param{fkt} ? $param{fkt} : "power,[[VOLUME]]";
#	$pa{_NO_FKT_PERM} = 1;
	#$pa{model_id}
	#$pa{model_name}

	$signalList->get_signal($q, \%pa);

	output_to_base64($signalList) if ($param{output} eq "base64_blob");

	return $signalList->{remote};
}

sub get_codes
{
	my ($brand_id, $oem_id) = @_;

	my %pa;
	$pa{key} = $param{key};
	$pa{limit} = 3;
	$pa{type_id} = 1;
	$pa{brand_id} = $brand_id;
	$pa{fkt} = $param{fkt};
	$pa{oem_id} = $oem_id if ($oem_id);
	$pa{age} = $param{age} if ($param{age});
	$pa{compress} = $param{compress} if ($param{compress});

	my $codeList = new RuwidoSignalList($db, $dbh);
	$codeList->get_signal($q, \%pa);

	return $codeList->{remote};
}

sub output_to_base64
{
	my ($signalList) = @_;

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
		$txt =~ s/[\r\n "]+//g;
		$signalList->{remote}[$id]->{base64}->{content} = $txt;
		$txt = "";
	}
}
