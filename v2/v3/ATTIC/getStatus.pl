#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use DataBase;

my $db = new DataBase();
my $dbh = $db->connect();

sub select_status
{
	my ($q, $param) = @_;

	my $sth;
	my $sql = "SELECT NOW()";
	$sth = $dbh->prepare($sql);
	$sth->execute();
	my ($now) = $sth->fetchrow_array();
	$sth->finish();

	$sql = "SHOW SLAVE STATUS;";
	$sth = $dbh->prepare($sql);
	$sth->execute();
	my $row = $sth->fetchrow_hashref();
	$sth->finish();

	$db->printHeader($q);
	printf ('<data version="1.0"><status time="%s">', $now);
	printf ('<slave>');
	printf ('<io_running>%s</io_running>', $row->{Slave_IO_Running});
	printf ('<sql_running>%s</sql_running>', $row->{Slave_SQL_Running});
	printf ('<seconds_behind_master>%s</seconds_behind_master>', $row->{Seconds_Behind_Master});
	printf ('<last_io_error>%s</last_io_error>', $row->{Last_IO_Errno});
	printf ('<last_sql_error>%s</last_sql_error>', $row->{Last_SQL_Errno});
	printf ('</slave>');
	printf ('</status></data>');
}

my $q = CGI->new;
my %param = $q->Vars;
select_status($q, \%param);

$db->disconnect();
exit 0;
