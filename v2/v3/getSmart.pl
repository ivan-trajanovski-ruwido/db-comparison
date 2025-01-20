#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use Data::Dumper;

use DataBase;
use RuwidoSignalList;

my $db = new DataBase();
my $dbh = $db->connect();

my $signalList = new RuwidoSignalList($db, $dbh);

sub smart
{
	my ($q, $param) = @_;
	my %descr = ();

	foreach my $entry (keys $param) {
		my $val = $param->{$entry};
		next if ($entry !~ /^descr_/);
		$entry =~ s/^descr_//;
		$descr{$entry} = $val;
	}

	my $sql_fkt = "";
	$sql_fkt .= sprintf("AND func_id IN (%s) ", $signalList->db_get_func($param)) if (defined $param->{fkt});

	my $sql = "SELECT rc_oem_id, type_id FROM oem_to_signal o1 ";
	my $sth;
	my $i;

	for ($i=2; $i<=keys %descr; $i++) {
		$sql .= sprintf("JOIN oem_to_signal o%d USING (rc_oem_id, type_id, type_layer) ", $i);
	}

	$sql .= "WHERE 1=1 ";
	$i = 1;
	foreach my $entry (keys %descr) {
#		$sql .= sprintf("AND o%d.func_id = %d AND o%d.descr = '%s' ", $i, $entry, $i, $descr{$entry});
		$sql .= sprintf("AND o%d.func_id IN (SELECT func_to_name.id FROM func_to_name WHERE name = '%s') AND o%d.descr = '%s' ", $i, $entry, $i, $descr{$entry});
#		$sql .= sprintf("AND o%d.type_id = 1 AND o%d.func_id IN (SELECT func_to_name.id FROM func_to_name WHERE name = '%s') AND o%d.descr = '%s' ", $i, $i, $entry, $i, $descr{$entry});
		$i++;
	}


	print "Content-type: text/plain; charset=utf-8\n\n";

if (keys %descr) {
########################################
	print ("RC_OEM_IDS:\n");
	printf "----------\n";

	$sth = $dbh->prepare("SELECT DISTINCT GROUP_CONCAT(rc_oem_id) AS rc_oem_id, 1 AS dummy FROM ($sql) t1 GROUP BY dummy");
	$sth->execute();
	while(my $row = $sth->fetchrow_hashref()) {
		print $row->{rc_oem_id} . "\n";
	}
	$sth->finish();

	printf "----------------------------------------\n";

########################################
	print ("MODELS:\n");
	printf "----------\n";

	$sth = $dbh->prepare("SELECT DISTINCT brand.name AS brand, GROUP_CONCAT(name_display) AS name FROM mv_union JOIN brand ON (brand.id = brand_id) JOIN mv_union_to_oem ON (mv_union.id = mv_union_id) JOIN ($sql) t1 USING (rc_oem_id) GROUP BY brand");
	$sth->execute();
	while(my $row = $sth->fetchrow_hashref()) {
		print $row->{brand} . ": " . $row->{name} . "\n";
	}
	$sth->finish();

	printf "----------------------------------------\n";
}
########################################
	print ("FUNCTIONS:\n");
	printf "----------\n";

#	my $sql1 = "SELECT func_to_name.name AS func_name, COUNT(DISTINCT descr) AS num_descr, COUNT(DISTINCT descr)/COUNT(DISTINCT rc_oem_id) AS ratio, GROUP_CONCAT(DISTINCT rc_oem_id ORDER BY rc_oem_id ASC) AS oem FROM oem_to_signal JOIN ($sql) t1 USING (rc_oem_id, type_id) JOIN func_to_name ON (func_id = func_to_name.id)";
#	my $sql1 = "SELECT func_to_name.name AS func_name, COUNT(DISTINCT descr) AS num_descr, COUNT(DISTINCT rc_oem_id) AS num_oem FROM oem_to_signal JOIN ($sql) t1 USING (rc_oem_id, type_id) JOIN func_to_name ON (func_id = func_to_name.id)";

	my $sql1 = "SELECT func_to_name.name AS func_name, COUNT(DISTINCT descr) AS num_descr, COUNT(DISTINCT rc_oem_id) AS num_oem, GROUP_CONCAT(DISTINCT descr) AS d, GROUP_CONCAT(DISTINCT rc_oem_id ORDER BY rc_oem_id ASC) AS oem  FROM oem_to_signal JOIN ($sql) t1 USING (rc_oem_id, type_id) JOIN func_to_name ON (func_id = func_to_name.id)";
#	$sql1 .= "WHERE 1=1 AND prio=1 ";
	$sql1 .= "WHERE 1=1 ";
	if (defined $param->{fkt}) {
		$sql1 .= sprintf("AND func_id IN (%s) ", $signalList->db_get_func($param));
	}
#	$sql1 .= "GROUP BY func_id ORDER BY num_descr DESC, ratio DESC, func_id ASC";
#	$sql1 .= "GROUP BY func_id ORDER BY num_oem ASC, num_descr DESC, func_id ASC";
	$sql1 .= "GROUP BY func_id ORDER BY num_descr DESC, num_oem ASC, func_id ASC";

	$sth = $dbh->prepare($sql1);

	$sth->execute();
	my $found = 1;
	while(my $row = $sth->fetchrow_hashref()) {
		if ($row->{num_oem} < 10) {
			printf ("%-20s: %4d %4d\t\"%s\"\t%s\n", $row->{func_name}, $row->{num_descr}, $row->{num_oem}, $row->{d}, $row->{oem});
		} else {
			printf ("%-20s: %4d %4d\t\"%s\"\t...\n", $row->{func_name}, $row->{num_descr}, $row->{num_oem}, $row->{d});
		}
		$found = 0 if ($row->{num_descr} != 1);
	}

	$sth->finish();

	printf "----------------------------------------\n";
	print "=== FOUND ===\n" if ($found);
}

########################################

my $q = CGI->new;
my %param = $q->Vars;

$param{model_id} = '' if (defined $param{model_id} && $param{model_id} eq "true");		# HACK for jquery
$param{model_name} = '' if (defined $param{model_name} && $param{model_name} eq "true");	# HACK for jquery
$param{debug} = 0 if (!$db->checkAccessDebug(\%param));

#$db->print_error($q, 401, "Unauthorized") if (exists $param->{"cycle_"});

	smart($q, \%param);
#if ($db->checkAccess(\%param)) {
	#smart($q, \%param);
#} else {
	#$db->print_error($q, 401, "Unauthorized");
#}

$db->disconnect();
exit 0;
