#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use CGI;
use DBI;
use POSIX qw(strftime);

use DataBase;
use RuwidoManual;

use constant MAX_CODES_PER_LINE => 6;

my $q = CGI->new;
my %param = $q->Vars;

my $db = new DataBase();
my $dbh = $db->connect();

my $manual = new RuwidoManual();
$manual->{dbh} = $dbh;

$db->cleanupParam(\%param);

sub weight_per_key
{
	my ($key) = @_;

	my $sth = $dbh->prepare("SELECT COUNT(*) counter FROM weight_global_code WHERE permission_key = ?");

	$sth->execute(($key));
	my $row = $sth->fetchrow_hashref();

	return $row->{counter};
}

sub select_code
{
	my ($q, $param) = @_;
	my $limit = $param->{limit};

	my $use_weight_per_key = weight_per_key($param->{key});

	$param->{per_line} = MAX_CODES_PER_LINE if (!defined $param->{per_line} || $param->{per_line} > MAX_CODES_PER_LINE);
	delete $param->{per_line} if ($param->{per_line} == 0);

	my $sth;
	my $first_letter = "";
	my $html = "";
	my $txt = $manual->get_header("CodeManual for ", $param);

	if ($param->{output} eq "csv") {
		delete $param->{per_line};
	}
	if ($param->{output} eq "html") {
		$html .= $q->header(
			-type  =>  'text/html',
			-charset => 'UTF-8',
		);
		$html .= $q->start_html(
			-title => "Code Manual (".$param->{project_id}.":".$param->{revision_id}.")",
			-style => {'src'=>'/css/ruwido.css'},
		);
		$txt =~ s/\n/<br\/>/g;
		$html .= $txt;
		$html .= $q->start_table(
			-class => "three-col"
		);
		$html .= $q->Tr($q->th(["Brand", "Code"]));
	}

	if ($param->{output} ne "html") {
		print "Content-type: text/plain; charset=utf-8\n";
		print $txt;
		$txt = "";
	}

	# prepend a list of all available codes (ordered by weight)
if ($param->{global}) {
		my @bind_values = ();

		my $sql1 = "";
		$sql1 .= "SELECT code, SUM(IFNULL(weight, 1)) AS weight";
		$sql1 .= " FROM crossref";
		$sql1 .= " JOIN brand ON (brand.id = brand_id)";
		$sql1 .= " LEFT JOIN crossref_to_global_code ON (crossref.id = crossref_id)";
		$sql1 .= " LEFT JOIN global_code_to_offline_db USING (global_code_id)";
		if ($use_weight_per_key) {
			$sql1 .= $db->bind(" LEFT JOIN (SELECT * FROM weight_global_code WHERE permission_key = ?) w1 USING (global_code_id)", $param->{key}, \@bind_values);
		} else {
			$sql1 .= " LEFT JOIN (SELECT * FROM weight_global_code WHERE permission_key IS NULL) w1 USING (global_code_id)";
		}

 		$sql1 .= " WHERE  crossref.source IN ('model_name', 'rc_name')";
		# FIND_IN_SET('amp', type_set)
		$sql1 .= $db->bind("AND type_set & ?", $db->{__types},  \@bind_values) if ($db->{__types});
		$sql1 .= $db->bind("AND offline_db_id = (SELECT id FROM offline_db WHERE revision_id = ?)", $param->{revision_id}, \@bind_values);
		$sql1 .= "GROUP BY code ORDER BY SUM(IFNULL(weight, 1)) DESC, code DESC";

		my $sql = $sql1;

		$sth = $dbh->prepare($sql);
		$sth->execute(@bind_values);

		my @code = ();
		while(my $row = $sth->fetchrow_hashref()) {
#			if (defined $param->{fkt}) {
#				push @code, $row->{code} . "(".$row->{descr}.")";
#			} else {
				push @code, $row->{code};
#			}
		}

		if ($param->{output} eq "html") {
			$html .= $q->Tr($q->td(["GLOBAL", join(",", @code)])) if (scalar(@code));
		} elsif ($param->{output} eq "csv") {
			$txt .= "GLOBAL," . join(",", @code) . "\n" if (scalar(@code));
		} else {
			my $code_txt = "";
			for (my $i=0; $i < scalar(@code); $i++) {
				if (!$param->{per_line} || $i % $param->{per_line}) {
					$code_txt .= "   " . $code[$i];
				} else {
					$code_txt .= "\n" unless ($i == 0);
					$code_txt .= "\t" . $code[$i];
				}
			}

			$txt .= "GLOBAL" . $code_txt . "\n";
		}
		$sth->finish();
}

if (1) {
		my @bind_values = ();

#select brand.name AS name, code, SUM(IFNULL(weight, 1)) AS weight FROM crossref LEFT JOIN brand ON (brand.id = brand_id) LEFT JOIN crossref_to_global_code ON (crossref.id = crossref_id) LEFT JOIN global_code_to_offline_db USING (global_code_id) LEFT JOIN (SELECT * FROM weight_global_code WHERE permission_key = "a30eda6c22f8XXX") w1 USING (global_code_id) WHERE  crossref.source IN ("model_name", "rc_name") AND type_set & 1  AND offline_db_id = (SELECT id FROM offline_db WHERE revision_id = 2301) GROUP BY brand.id, code

#SELECT name, GROUP_CONCAT(code ORDER BY weight DESC, code DESC) AS code FROM (select brand.name AS name, code, SUM(IFNULL(weight, 1)) AS weight FROM crossref LEFT JOIN brand ON (brand.id = brand_id) LEFT JOIN crossref_to_global_code ON (crossref.id = crossref_id) LEFT JOIN global_code_to_offline_db USING (global_code_id) LEFT JOIN (SELECT * FROM weight_global_code WHERE permission_key = "a30eda6c22f8XXX") w1 USING (global_code_id) WHERE  crossref.source IN ("model_name", "rc_name") AND type_set & 1  AND offline_db_id = (SELECT id FROM offline_db WHERE revision_id = 2301) GROUP BY brand.id, code) t1 GROUP by name;

		my $sql1 = "";
		$sql1 .= "SELECT brand.name AS name, code, SUM(IFNULL(weight, 1)) AS weight";
		$sql1 .= " FROM crossref";
		$sql1 .= " JOIN brand ON (brand.id = brand_id)";
		$sql1 .= " LEFT JOIN crossref_to_global_code ON (crossref.id = crossref_id)";
		$sql1 .= " LEFT JOIN global_code_to_offline_db USING (global_code_id)";
		if ($use_weight_per_key) {
			$sql1 .= $db->bind(" LEFT JOIN (SELECT * FROM weight_global_code WHERE permission_key = ?) w1 USING (global_code_id)", $param->{key}, \@bind_values);
		} else {
			$sql1 .= " LEFT JOIN (SELECT * FROM weight_global_code WHERE permission_key IS NULL) w1 USING (global_code_id)";
		}

 		#$sql1 .= " WHERE crossref.source IN ('model_name', 'rc_name')";
 		$sql1 .= " WHERE 1=1";
		$sql1 .= $db->bind("AND type_set & ?", $db->{__types},  \@bind_values) if ($db->{__types});
		$sql1 .= $db->bind("AND offline_db_id = (SELECT id FROM offline_db WHERE revision_id = ?)", $param->{revision_id}, \@bind_values);
		$sql1 .= "GROUP BY brand.id, code";

		my $sql = "";
		$sql .= "SELECT name, GROUP_CONCAT(code ORDER BY weight DESC, code DESC) AS code";
		$sql .= " FROM ($sql1) t1 GROUP by name";

		$sth = $dbh->prepare($sql);
		$sth->execute(@bind_values);

		if ($param->{output} eq "html") {
			while(my $row = $sth->fetchrow_hashref()) {
				$html .= $q->Tr($q->td([$row->{name}, $row->{code}])) if ($row->{code});
			}
		} elsif ($param->{output} eq "csv") {
			while(my $row = $sth->fetchrow_hashref()) {
				$txt .= $row->{name} . "," . $row->{code} . "\n" if ($row->{code});
			}
		} else {
			while(my $row = $sth->fetchrow_hashref()) {
				next unless ($row->{code});

				my @arr = split /,/, $row->{code};
				$row->{code} = "";
				for (my $i=0; $i < scalar(@arr); $i++) {
					if (!$param->{per_line} || $i % $param->{per_line}) {
						if (defined $param->{fkt}) {
							$row->{code} .= "\t" . $arr[$i];
						} else {
							$row->{code} .= "   " . $arr[$i];
						}
					} else {
						$row->{code} .= "\n" unless ($i == 0);
						$row->{code} .= "\t" . $arr[$i];
					}
				}

				if ($first_letter ne uc(substr($row->{name}, 0, 1))) {
					$first_letter = uc(substr($row->{name}, 0, 1));
					$txt .= "\n" . $first_letter . "\n";
				}
				$txt .= $row->{name} . $row->{code} . "\n";
			}
		}
		$sth->finish();
}

	if ($param->{output} eq "html") {
		$html .= $q->end_table();
		$html .= $q->end_html();

		print $html;
	} else {
		print $txt;
	}
}

if ($db->checkAccess(\%param)) {
	select_code($q, \%param);
} else {
	select_code($q, \%param);
#	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
