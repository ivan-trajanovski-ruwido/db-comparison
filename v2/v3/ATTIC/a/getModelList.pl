#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use DataBase;

my $db = new DataBase();
my $dbh = $db->connect();

sub select_model
{
	my ($q, $param) = @_;
	my @bind_values = ();

	my $sql = "SELECT SQL_CALC_FOUND_ROWS DISTINCT id, name_display AS content FROM mv_union WHERE 1 = 1";
	$sql .= $db->bind_and("mv_union.date >= DATE_SUB(CURDATE(), INTERVAL ? YEAR)", $param->{age}, \@bind_values) if (defined $param->{age} && $param->{age} > 0);

	if ($param->{type_id}) {
		if ($param->{type_id} == 1) {   #FIXME_TV
			$sql .= $db->bind_and("mv_union.type_id = ?", $db->cleanTypeId($param->{type_id}), \@bind_values);
		} else {
			$sql .= $db->bind_and("mv_union.type_set & ?", 2**($db->cleanTypeId($param->{type_id})-1), \@bind_values);
		}
	}
	$sql .= $db->bind_and("FIND_IN_SET(?, mv_union.type_set)", $db->cleanTypeId($param->{type_name}), \@bind_values) if ($param->{type_name});

	if (defined $param->{brand_id} && $param->{brand_id} ne '') {
		$sql .= $db->bind_and("mv_union.brand_id = ?", $param->{brand_id}, \@bind_values);
	} elsif (defined $param->{brand_name} && $param->{brand_name} ne '') {
		$sql .= $db->bind_and("mv_union.brand_id IN (SELECT id FROM brand WHERE name REGEXP ?)", $param->{brand_name}, \@bind_values);
	}
	$sql .= $db->bind_and("mv_union.name REGEXP ?", $db->createSearch($param->{model_name}), \@bind_values) if ($param->{model_name});
	$sql .= " AND mv_union.from_table LIKE 'model_%'";
	$sql .= " ORDER BY name";

	if ($param->{key} eq "d898981e9d82" ||	# bouygues
	    $param->{key} eq "9385807aba71"	# ruwido
	) { #KLUDGE: bouygues - no limit
		if ($param->{limit}) {
			my $max_limit = $param->{limit};
			$max_limit =~ s/^[0-9]*,//g;
			$sql .= " LIMIT " . $db->cleanLimit($param->{limit}, $max_limit);
		}
	} else {
		$sql .= " LIMIT " . $db->cleanLimit($param->{limit});
	}

#print $sql;
	my $sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);

	my ($total) = $dbh->selectrow_array("SELECT FOUND_ROWS()");

	my $items = [];
	while(my $row = $sth->fetchrow_hashref()) {
		push @$items, $row;
	}
	$sth->finish();

	$db->print($q, $total, {models => {total => $total, item => $items}}, {-vary => "Accept-Language"});
}

my $q = CGI->new;
my %param = $q->Vars;

if ($db->checkAccess(\%param)) {
#	$param{age} = 7 unless ($param{age} > 0 || defined $param{project_id});
	select_model($q, \%param);
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
