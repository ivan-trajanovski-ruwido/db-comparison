#!/usr/bin/perl -w

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

sub select_type
{
	my ($q, $param) = @_;
	my $sql;
	my $sth;
	my @bind_values = ();

	$sql = "SELECT SQL_CALC_FOUND_ROWS DISTINCT type.id AS id, type.name AS content, type.name_short AS short FROM type";
	$sql .= " JOIN permission ON permission.type_set & pow(2,type.id-1) WHERE 1=1";

	$sql .= $db->bind("AND permission_key = ?", $param->{key}, \@bind_values) if ($param->{key});
	$sql .= $db->bind("AND name REGEXP ?", $param->{type_name}, \@bind_values) if ($param->{type_name});
	$sql .= $db->bind("AND 1<<(type_id-1) & ?", $db->{__types},  \@bind_values) if ($db->{__types});


	$sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);
	my ($total, $items) = $db->fetchall_total_array_hashref($sth);
	$sth->finish();

	$db->print($q, $total, {types => {total => $total, item => $items}}, {-vary => "Accept, Accept-Language"});
}

if ($db->{__permission}) {
	select_type($q, \%param);
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
