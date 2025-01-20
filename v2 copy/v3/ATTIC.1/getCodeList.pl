#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use DataBase;

use Data::Dumper;

use constant DEFAULT_REFERENCE => 118;
use constant DEFAULT_REVISION => 461;

my $db = new DataBase();
my $dbh = $db->connect();

sub select_brandcode
{
	my ($q, $param) = @_;
	my @bind_values = ();

	my $sth;
	my $sql = "SELECT SQL_CALC_FOUND_ROWS DISTINCT code AS id FROM brand_to_code WHERE 1=1";
	if (defined $param->{brand_id} && $param->{brand_id} ne '') {
		$sql .= $db->bind_and("brand_id = ?", $param->{brand_id}, \@bind_values) if ($param->{brand_id});
	} elsif (defined $param->{brand_name} && $param->{brand_name} ne '') {
		$sql .= $db->bind_and("brand_id IN (SELECT id FROM brand WHERE name sREGEXP= ?)", $param->{brand_name}, \@bind_values) if ($param->{brand_name});
        }
	$sql .= $db->bind_and("type_set & ?", 2**($db->cleanTypeId($param->{type_id})-1), \@bind_values) if ($param->{type_id});
	$sql .= $db->bind_and("project_id = ?", $param->{project}, \@bind_values);
	$sql .= $db->bind_and("revision_id = ?", $param->{revision}, \@bind_values);

	if ($param->{limit}) {
		my $max_limit = $param->{limit};
		$max_limit =~ s/^[0-9]*,//g;

		$sql .= " LIMIT " . $db->cleanLimit($param->{limit}, $max_limit);
	}

	$sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);

	my $total;
	my $items = [];

	($total) = $dbh->selectrow_array("SELECT FOUND_ROWS()");
	while(my $row = $sth->fetchrow_hashref()) {
		push @$items, $row;
	}
	$sth->finish();

	$db->print($q, $total, {codes => {total => $total, code => $items}, type=>"brandcode"}, {-vary => "Accept"});
}

sub weight_per_key
{
	my ($key) = @_;

	my $sth = $dbh->prepare("SELECT COUNT(*) counter FROM weight_oem WHERE permission_id = ?");
	$sth->execute(($key));
	my $row = $sth->fetchrow_hashref();

	return $row->{counter};
}

sub select_code
{
	my ($q, $param) = @_;
	my $limit = $param->{limit};

	my $use_weight_per_key = weight_per_key($param->{key});

	my @bind_values = ();

	my $sth;

	my $total;
	my $items = [];

	my $sql = "";
	if (!exists $param->{model_name} || $param->{model_name} eq "") {	# empty model name - read also entries which are not referenced by models
		$sql = "SELECT SQL_CALC_FOUND_ROWS code AS id";
		$sql .= " FROM (SELECT code, SUM(IFNULL(weight, 1)) AS weight";
		$sql .= " FROM ruwido_rc.oem_to_code";
		$sql .= " LEFT JOIN ruwido_rc.rc_info USING (rc_oem_id)";
                $sql .= " LEFT JOIN ruwido_rc.equipment_to_rc_info ON rc_info.id = rc_info_id";        #new
#		$sql .= " LEFT JOIN ruwido_rc.weight_oem USING (rc_oem_id)";
		if ($use_weight_per_key) {
			$sql .= $db->bind("LEFT JOIN (SELECT * FROM ruwido_rc.weight_oem WHERE permission_id = ?) w1 USING (rc_oem_id, brand_id)", $param->{key}, \@bind_values);
		} else {
			$sql .= " LEFT JOIN (SELECT * FROM ruwido_rc.weight_oem WHERE permission_id IS NULL) w1 USING (rc_oem_id, brand_id)";
		}
		$sql .= " WHERE 1=1";
		$sql .= $db->bind_and("oem_to_code.type_id = ?", $param->{type_id}, \@bind_values) if ($param->{type_id});
		$sql .= $db->bind_and("oem_to_code.project_id = ?", $param->{project_id}, \@bind_values);
		$sql .= $db->bind_and("oem_to_code.revision_id = ?", $param->{revision_id}, \@bind_values);

		if (defined $param->{brand_id}) {
			$sql .= $db->bind_and("rc_info.brand_id = ?", $param->{brand_id}, \@bind_values);
		} elsif(defined $param->{brand_name}) {
			$sql .= $db->bind_and("rc_info.brand_id IN (SELECT id FROM brand WHERE name = ?)", $param->{brand_name}, \@bind_values);
		}
		$sql .= " GROUP BY rc_oem_id) t1 GROUP BY code";
		$sql .= " ORDER BY SUM(weight) DESC, code DESC";
		$sql .= " LIMIT " . $db->cleanLimit($param->{limit}, 50);

		$sth = $dbh->prepare($sql);
		$sth->execute(@bind_values) or die "Couldn't execute statement: " . $sth->errstr;

		($total) = $dbh->selectrow_array("SELECT FOUND_ROWS()");
		while(my $row = $sth->fetchrow_hashref()) {
			push @$items, $row;
		}
	} else {
		my $sql_oem_ids = "SELECT rc_oem_id, COUNT(*) AS num FROM mv_union JOIN mv_union_to_oem ON mv_union.id = mv_union_to_oem.mv_union_id WHERE 1=1";
		$sql_oem_ids .= $db->bind_and("mv_union.type_set & ?", 2**($db->cleanTypeId($param->{type_id})-1), \@bind_values) if ($param->{type_id});
                $sql_oem_ids .= $db->bind_and("FIND_IN_SET(?, mv_union.type_set)", $db->cleanTypeId($param->{type_name}), \@bind_values) if ($param->{type_name});

		$sql_oem_ids .= $db->bind_and("mv_union.brand_id = ?", $param->{brand_id}, \@bind_values) if (defined $param->{brand_id} && $param->{brand_id} ne '');
		$sql_oem_ids .= $db->bind_and("YEAR(mv_union.date) >= ?", $param->{year}, \@bind_values) if (defined $param->{year} && $param->{year} ne '');
		if (defined $param->{model_id} && $param->{model_id} ne '') {
			$sql_oem_ids .= $db->bind_and("mv_union.id = ?", $param->{model_id}, \@bind_values);
		} elsif (defined $param->{model_name} && $param->{model_name} ne '') {
			$sql_oem_ids .= $db->bind_and("mv_union.name REGEXP ?", $db->createSearch($param->{model_name}), \@bind_values);
		}
		$sql_oem_ids .= " GROUP BY rc_oem_id";

		# get count only
		if (exists $param->{limit} && $param->{limit} eq "0") {
			$sql = "SELECT SQL_CALC_FOUND_ROWS DISTINCT code AS id FROM oem_to_code";	# WHERE rc_oem_id IN ($oem_ids)";
			$sql .= " JOIN ($sql_oem_ids) t1 USING (rc_oem_id)";
			$sql .= " WHERE 1=1";
			$sql .= $db->bind_and("oem_to_code.type_id = ?", $param->{type_id}, \@bind_values) if ($param->{type_id});
			$sql .= $db->bind_and("oem_to_code.project_id = ?", $param->{project_id}, \@bind_values);
			$sql .= $db->bind_and("oem_to_code.revision_id = ?", $param->{revision_id}, \@bind_values);

			$sql .= " LIMIT 1";
			$sth = $dbh->prepare($sql);
			$sth->execute(@bind_values);

			($total) = $dbh->selectrow_array("SELECT FOUND_ROWS()");
		} else {
			$sql = "SELECT SQL_CALC_FOUND_ROWS code AS id";
			$sql .= " FROM (SELECT code, SUM(IFNULL(weight, 1)) AS weight";
			$sql .= " FROM ruwido_rc.oem_to_code";
			$sql .= " JOIN ($sql_oem_ids) t1 USING (rc_oem_id)";
			$sql .= " LEFT JOIN ruwido_rc.rc_info USING (rc_oem_id)";
                	$sql .= " LEFT JOIN ruwido_rc.equipment_to_rc_info ON rc_info.id = rc_info_id";        #new
			if ($use_weight_per_key) {
				$sql .= $db->bind("LEFT JOIN (SELECT * FROM ruwido_rc.weight_oem WHERE permission_id = ?) w1 USING (rc_oem_id, brand_id)", $param->{key}, \@bind_values);
			} else {
				$sql .= " LEFT JOIN (SELECT * FROM ruwido_rc.weight_oem WHERE permission_id IS NULL) w1 USING (rc_oem_id, brand_id)";
			}

#			$sql = "SELECT SQL_CALC_FOUND_ROWS code AS id FROM oem_to_code";
#			$sql .= " JOIN ($sql_oem_ids) t1 USING (rc_oem_id)";
#			$sql .= " LEFT JOIN weight_oem USING (rc_oem_id)";
			$sql .= " WHERE 1=1";
			$sql .= $db->bind_and("oem_to_code.type_id = ?", $param->{type_id}, \@bind_values) if ($param->{type_id});
			$sql .= $db->bind_and("oem_to_code.project_id = ?", $param->{project_id}, \@bind_values);
			$sql .= $db->bind_and("oem_to_code.revision_id = ?", $param->{revision_id}, \@bind_values);
			$sql .= "GROUP BY rc_oem_id) t1 GROUP BY code ORDER BY SUM(weight) DESC, code DESC";
#			$sql .= " GROUP BY id";
#			$sql .= " ORDER BY SUM(weight) DESC, SUM(num) DESC";
			$sql .= " LIMIT " . $db->cleanLimit($param->{limit}, 50);

			$sth = $dbh->prepare($sql);
			$sth->execute(@bind_values);

			($total) = $dbh->selectrow_array("SELECT FOUND_ROWS()");
			while(my $row = $sth->fetchrow_hashref()) {
				push @$items, $row;
			}
		}
	}

	$sth->finish();

	$db->print($q, $total, {codes => {total => $total, code => $items}}, {-vary => "Accept"});
}

my $q = CGI->new;
my %param = $q->Vars;

$param{model_id} = '' if (defined $param{model_id} && $param{model_id} eq "true");		# HACK for jquery
$param{model_name} = '' if (defined $param{model_name} && $param{model_name} eq "true");	# HACK for jquery

$param{project_id} = $param{reference} if (!defined $param{project_id});
$param{project_id} = $param{project} if (!defined $param{project_id});
$param{revision_id} = $param{revision} if (!defined $param{revision_id});

if ($db->checkAccess(\%param)) {
	if (defined $param{use_brandcode} &&  $param{use_brandcode} eq "true") {
		select_brandcode($q, \%param);
	} else {
		select_code($q, \%param);
	}
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
