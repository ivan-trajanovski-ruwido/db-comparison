#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use CGI;
use DBI;
use DataBase;

my $q = CGI->new;
my %param = $q->Vars;

my $db = new DataBase();
my $dbh = $db->connect();

$db->cleanupParam(\%param);

sub weight_per_key
{
	my ($key) = @_;

	my $sth = $dbh->prepare("SELECT COUNT(*) counter FROM weight_brand WHERE permission_id = ?");
	$sth->execute(($key));
	my $row = $sth->fetchrow_hashref();

	return $row->{counter};
}

sub select_brand
{
	my ($q, $param) = @_;
	my @bind_values = ();

#	my $sql1 = sql_allowed_types($param);

	my $sql = "SELECT SQL_CALC_FOUND_ROWS DISTINCT brand.id AS id, brand.name AS content FROM crossref JOIN brand ON brand.id = crossref.brand_id";
	$sql .= " LEFT JOIN weight_brand ON brand.id = weight_brand.brand_id" if ($param->{top});

	$sql .= " WHERE 1=1";

	$sql .= $db->bind("AND crossref.date >= DATE_SUB(CURDATE(), INTERVAL ? YEAR)", $param->{age}, \@bind_values) if ($param->{age});
	$sql .= $db->bind("AND crossref.type_set & ?", $db->{__types}, \@bind_values);

	if ($param->{top}) {
		$sql .= " AND weight > 0";

		# if weight exist for this key use it, otherwise use default weights
		if (weight_per_key($param->{key})) {
			$sql .= $db->bind("AND permission_id = ?", $param->{key}, \@bind_values);
		} else {
			$sql .= " AND permission_id IS NULL";
		}
		$sql .= " ORDER BY weight DESC, brand.name ASC";

#		$param->{limit} = min($param->{top}, $param->$db->cleanLimit($param->{top}, $param->{limit}) if (defined $param->{top});   #FIXME MIN(limit, top)
	} else {
		$sql .= $db->bind("AND brand.name REGEXP ?", $param->{brand_name}, \@bind_values) if ($param->{brand_name});
		$sql .= " ORDER BY brand.name";
	}

	$sql .= $db->bind("LIMIT ?", $param->{limit}) if ($param->{limit});

	my $sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);
	my ($total, $items) = $db->fetchall_total_array_hashref($sth);
	$sth->finish();

	$db->print($q, $total, {brands => {total => $total, item => $items}}, {-vary => "Accept"});
}

if ($db->{__permission}) {
	select_brand($q, \%param);
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
