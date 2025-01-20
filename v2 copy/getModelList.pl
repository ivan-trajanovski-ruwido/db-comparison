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

sub select_model
{
	my ($q, $param) = @_;
	my @bind_values = ();

	my $sql = "SELECT SQL_CALC_FOUND_ROWS DISTINCT id, name AS content FROM crossref WHERE 1 = 1";

	$sql .= $db->bind("AND crossref.date >= DATE_SUB(CURDATE(), INTERVAL ? YEAR)", $param->{age}, \@bind_values) if ($param->{age});
	$sql .= $db->bind("AND crossref.type_set & ?", $db->{__types}, \@bind_values);

	if (defined $param->{brand_id} && $param->{brand_id} ne '') {
		$sql .= $db->bind("AND crossref.brand_id = ?", $param->{brand_id}, \@bind_values);
	} elsif (defined $param->{brand_name} && $param->{brand_name} ne '') {
		$sql .= $db->bind("AND crossref.brand_id IN (SELECT id FROM brand WHERE name REGEXP ?)", $param->{brand_name}, \@bind_values);
	}

	$sql .= $db->bind("AND crossref.name_search REGEXP ?", $db->createSearch($param->{model_name}), \@bind_values) if ($param->{model_name});
	$sql .= " ORDER BY name";

	$sql .= " LIMIT " . $db->cleanLimit($param->{limit}) if ($param->{limit});

	my $sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);
	my ($total, $items) = $db->fetchall_total_array_hashref($sth);
	$sth->finish();

	$db->print($q, $total, {models => {total => $total, item => $items}}, {-vary => "Accept"});
}

if ($db->{__permission}) {
	select_model($q, \%param);
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
