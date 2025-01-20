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

sub select_func
{
	my ($q, $param) = @_;
	my @bind_values = ();

	my $sql = "SELECT id, name FROM function ORDER BY id;";
#FIXME: add restriction to allowed functions ...

	my $sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);

	my $items = [];
	while(my $row = $sth->fetchrow_hashref()) {
		push @$items, $row;
	}
	$sth->finish();

	$db->print($q, 1, {functions => {item => $items}}, {-vary => "Accept-Language"});
}

if ($db->{__permission}) {
	select_func($q, \%param);
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
