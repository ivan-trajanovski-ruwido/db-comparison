#!/usr/bin/perl -w

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use DataBase;

use Data::Dumper;

my $db = new DataBase();
my $dbh = $db->connect();

sub select_type
{
	my ($q, $param) = @_;
#	my $lang = substr($q->http('Accept-Language'), 0, 2);
	my $sql;
	my $sth;
	my @bind_values = ();

	### now do the real work
	$sql = "SELECT SQL_CALC_FOUND_ROWS DISTINCT type.id AS id, type.name AS content, type.name_short AS short";
	$sql .= " FROM permission";
	$sql .= " JOIN type ON type_set & pow(2,type.id-1) WHERE 1=1";
	$sql .= $db->bind_and("permission_key = ?", $param->{key}, \@bind_values) if ($param->{key});
	$sql .= $db->bind_and("name REGEXP ?", $param->{type_name}, \@bind_values) if ($param->{type_name});
	$sql .= " LIMIT " . $db->cleanLimit($param->{limit});

	$sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);

	my $total = $dbh->selectrow_array("SELECT FOUND_ROWS()");

	my $items = [];
	while(my $row = $sth->fetchrow_hashref()) {
		push @$items, $row;
	}
	$sth->finish();

	$db->print($q, $total, {types => {total => $total, item => $items}}, {-vary => "Accept, Accept-Language"});
}

my $q = CGI->new;
my %param = $q->Vars;

if ($db->checkAccess(\%param)) {
	select_type($q, \%param);
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
