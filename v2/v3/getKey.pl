#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
#use DBI;
use DataBase;

use Data::Dumper;
use Carp;

my $db = new DataBase();
#my $dbh = $db->connect();

sub select_func
{
	my ($q, $param) = @_;

	#carp Dumper $param;

	$db->print($q, 1, {key => "0afdfc10668a"}, {-vary => "Accept-Language"}) if ($param->{model} eq "2779-504");	# leaf
	$db->print($q, 1, {key => "676587b1d143"}, {-vary => "Accept-Language"}) if ($param->{model} eq "2788-502");	# telia.lt
	$db->print($q, 1, {key => "230746b3d388"}, {-vary => "Accept-Language"}) if ($param->{model} eq "2781-509");	# sonifi
}

my $q = CGI->new;
my %param = $q->Vars;

select_func($q, \%param);

#$db->disconnect();
exit 0;

	select_func($q, \%param);

#$db->disconnect();
exit 0;
