#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use DataBase;

my $db = new DataBase();
my $dbh = $db->connect();

sub select_func
{
	my ($q, $param) = @_;
	my @bind_values = ();

	my $sql = "SELECT id, name FROM func_to_name ORDER BY id;";
	my $sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);

	my $items = [];
	while(my $row = $sth->fetchrow_hashref()) {
		push @$items, $row;
	}
	$sth->finish();

	$db->print($q, 1, {functions => {item => $items}}, {-vary => "Accept-Language"});
}

my $q = CGI->new;
my %param = $q->Vars;

select_func($q, \%param);

$db->disconnect();
exit 0;

if ($db->checkAccess(\%param)) {
	select_func($q, \%param);
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
