#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use POSIX qw(strftime);

use DataBase;
use RuwidoManual;

use constant MAX_CODES_PER_LINE => 6;

my $db = new DataBase();
my $dbh = $db->connect();

my $manual = new RuwidoManual();
$manual->{dbh} = $dbh;

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

		my $sql = "";
		$sql .= "SELECT code";
		$sql .= ", descr" if (defined $param->{fkt});
		$sql .= " FROM ruwido_rc.oem_to_code";
		$sql .= " JOIN oem_to_signal USING (rc_oem_id)" if (defined $param->{fkt});
		$sql .= " LEFT JOIN ruwido_rc.rc_info USING (rc_oem_id)";
		$sql .= " LEFT JOIN ruwido_rc.equipment_to_rc_info ON rc_info.id = rc_info_id";
		$sql .= " JOIN ruwido_rc.brand ON (rc_info.brand_id = brand.id)";
		if ($use_weight_per_key) {
			$sql .= $db->bind("LEFT JOIN (SELECT * FROM ruwido_rc.weight_oem WHERE permission_id = ?) w1 USING (rc_oem_id, brand_id)", $param->{key}, \@bind_values);
		} else {
			$sql .= " LEFT JOIN (SELECT * FROM ruwido_rc.weight_oem WHERE permission_id IS NULL) w1 USING (rc_oem_id, brand_id)";
		}

#		$sql .= $db->bind("LEFT JOIN (SELECT * FROM ruwido_rc.weight_oem WHERE permission_id = ? OR permission_id IS NULL) w1 USING (rc_oem_id, brand_id)", $param->{key}, \@bind_values);
#		$sql .= $db->bind_and("(weight.permission_id = ? OR weight.permission_id IS NULL)", $param->{key}, \@bind_values);$
		$sql .= "  WHERE 1=1";
#		$sql .= $db->bind_and("oem_to_code.type_id = ?", $db->cleanTypeId($param->{type_id}), \@bind_values) if ($param->{type_id});
		$sql .= $db->bind_and("oem_to_code.type_id = ?", $param->{type_id}, \@bind_values) if ($param->{type_id});
		$sql .= $db->bind_and("oem_to_code.project_id = ?", $param->{project_id}, \@bind_values);
		$sql .= $db->bind_and("oem_to_code.revision_id = ?", $param->{revision_id}, \@bind_values);
		$sql .= "GROUP BY code ORDER BY SUM(IFNULL(weight, 1)) DESC, code DESC";

		$sth = $dbh->prepare($sql);
		$sth->execute(@bind_values);

		my @code = ();
		while(my $row = $sth->fetchrow_hashref()) {
			if (defined $param->{fkt}) {
				push @code, $row->{code} . "(".$row->{descr}.")";
			} else {
				push @code, $row->{code};
			}
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

		my $sql = "SELECT name, GROUP_CONCAT(code ORDER BY weight DESC, code DESC) AS code";

		if (defined $param->{fkt}) {
			$sql .= " FROM (SELECT brand.name AS name, CONCAT(code, ' (', descr, ')') AS code, SUM(IFNULL(weight, 1)) AS weight ";
		} else {
			$sql .= " FROM (SELECT brand.name AS name, code, SUM(IFNULL(weight, 1)) AS weight ";
		}
		$sql .= " FROM ruwido_rc.oem_to_code";
		$sql .= "  LEFT JOIN oem_to_signal USING (rc_oem_id)" if (defined $param->{fkt});
		$sql .= "  LEFT JOIN ruwido_rc.rc_info USING (rc_oem_id)";
		$sql .= "  LEFT JOIN ruwido_rc.equipment_to_rc_info ON rc_info.id = rc_info_id";	#new
		$sql .= "  JOIN ruwido_rc.brand ON (rc_info.brand_id = brand.id)";
		if ($use_weight_per_key) {
			$sql .= $db->bind("LEFT JOIN (SELECT * FROM ruwido_rc.weight_oem WHERE permission_id = ?) w1 USING (rc_oem_id, brand_id)", $param->{key}, \@bind_values);
		} else {
			$sql .= " LEFT JOIN (SELECT * FROM ruwido_rc.weight_oem WHERE permission_id IS NULL) w1 USING (rc_oem_id, brand_id)";
		}
		$sql .= "  WHERE 1=1";
		$sql .= $db->bind_and("oem_to_code.type_id = ?", $param->{type_id}, \@bind_values) if ($param->{type_id});
		$sql .= $db->bind_and("oem_to_code.project_id = ?", $param->{project_id}, \@bind_values);
		$sql .= $db->bind_and("oem_to_code.revision_id = ?", $param->{revision_id}, \@bind_values);
		$sql .= $db->bind_and("func_id = ?", $param->{fkt}, \@bind_values) if (defined $param->{fkt});	# FIXME: check for permissions AND filter for signal function_id
		$sql .= "GROUP BY brand.id, code) t1 GROUP BY name";

		$sth = $dbh->prepare($sql);
		$sth->execute(@bind_values);

		if ($param->{output} eq "html") {
			while(my $row = $sth->fetchrow_hashref()) {
				$html .= $q->Tr($q->td([$row->{name}, $row->{code}])) if ($row->{code});
			}
		} elsif ($param->{output} eq "csv") {
			$txt .= "sql: " . $sql . "\n" if ($param->{debug} >= 1);
			while(my $row = $sth->fetchrow_hashref()) {
				$txt .= $row->{name} . "," . $row->{code} . "\n" if ($row->{code});
			}
		} else {
			$txt .= "sql: " . $sql . "\n" if (defined $param->{debug} && $param->{debug} >= 1);
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

my $q = CGI->new;
my %param = $q->Vars;

$param{type_id} = 1 if (!defined $param{type_id});
$param{output} = "text" if (!defined $param{output});

if ($db->checkAccess(\%param)) {
	select_code($q, \%param);
} else {
	select_code($q, \%param);
#	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
