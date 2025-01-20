#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use DataBase;

my $db = new DataBase();
my $dbh = $db->connect();

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

	my $sql = "SELECT SQL_CALC_FOUND_ROWS DISTINCT brand.id AS id, brand.name AS content FROM mv_union JOIN brand ON brand.id = mv_union.brand_id";

	if (exists $param->{top}) {
		$sql .= " LEFT JOIN weight_brand ON brand.id = weight_brand.brand_id";
	}

	$sql .= " WHERE 1=1";
	$sql .= $db->bind_and("mv_union.date >= DATE_SUB(CURDATE(), INTERVAL ? YEAR)", $param->{age}, \@bind_values) if(defined $param->{age});
	$sql .= $db->bind_and("mv_union.type_set & ?", 2**($param->{type_id}-1), \@bind_values) if ($param->{type_id});
	$sql .= $db->bind_and("FIND_IN_SET(?, mv_union.type_set)", $param->{type_name}, \@bind_values) if ($param->{type_name});
#	$sql .= " AND from_table like 'model_%'";

	if (exists $param->{top}) {
		$sql .= " AND weight > 0";
		if (weight_per_key($param->{key})) {
			$sql .= $db->bind_and("permission_id = ?", $param->{key}, \@bind_values);
		} else {
			$sql .= " AND permission_id IS NULL";
		}
		$sql .= " ORDER BY weight DESC, brand.name ASC";
		$param->{limit} = $db->cleanLimit($param->{top}, $param->{limit}) if (defined $param->{top});   #FIXME MIN(limit, top)
	} else {
		$sql .= $db->bind_and("brand.name REGEXP ?", $param->{brand_name}, \@bind_values) if ($param->{brand_name});
		$sql .= " ORDER BY brand.name";
	}

#        if ($param->{key} eq "d898981e9d82" ||  # bouygues
#            $param->{key} eq "9385807aba71"     # ruwido
#        ) { #KLUDGE: bouygues - no limit
#                if ($param->{limit}) {
#                        my $max_limit = $param->{limit};
#                        $max_limit =~ s/^[0-9]*,//g;
#                        $sql .= " LIMIT " . $db->cleanLimit($param->{limit}, $max_limit);
#                }
#        } else {
                $sql .= " LIMIT " . $db->cleanLimit($param->{limit});
#        }

	my $sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);
	my ($total, $items) = $db->fetchall_total_array_hashref($sth);
	$sth->finish();

	if ($db->checkAccessDebug($param)) {
		$db->print($q, $total, {sql => $sql, brands => {total => $total, item => $items}}, {-vary => "Accept"});
	} else {
		$db->print($q, $total, {brands => {total => $total, item => $items}}, {-vary => "Accept"});
	}
}

my $q = CGI->new;
my %param = $q->Vars;

if ($db->checkAccess(\%param)) {
#	$param{age} = 7 if ((defined $param{age} && $param{age} <= 0) || defined $param{project_id});
	select_brand($q, \%param);
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
