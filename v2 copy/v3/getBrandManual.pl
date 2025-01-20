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

sub select_code
{
	my ($q, $param) = @_;
	my $limit = $param->{limit};

	my $sth;
	my $first_letter = "";
	my $html = "";
	my $txt = $manual->get_header("BrandManual for ", $param);

	if ($param->{output} eq "html") {
		$html .= $q->header(
			-type  =>  'text/html',
			-charset => 'UTF-8',
		);
		$html .= $q->start_html(
			-title => "Brand Manual (".$param->{project_id}.":".$param->{revision_id}.")",
			-style => {'src'=>'/css/ruwido.css'},
		);
		$txt =~ s/\n/<br\/>/g;
		$html .= $txt;
		$html .= $q->start_table(
			-class => "three-col"
		);
		$html .= $q->Tr($q->th(["Brand", "Code"]));
	}

	my @bind_values1 = ();
	my $sql_brand = "SELECT * FROM brand ";
	$sql_brand .= " WHERE 1=1";
	$sql_brand .= " ORDER BY brand.name";

	my $sth_brand = $dbh->prepare($sql_brand);
	$sth_brand->execute(@bind_values1);

	while(my $brand = $sth_brand->fetchrow_hashref()) {
		my @bind_values = ();

		my $sql = "SELECT DISTINCT code AS code FROM brand_to_code WHERE 1=1";
		$sql .= $db->bind_and("brand_id IN (SELECT id FROM brand WHERE name = ?)", $db->cleanTypeId($param->{brand_name}), \@bind_values) if ($param->{brand_name});
		$sql .= $db->bind_and("brand_id = ?", $db->cleanTypeId($brand->{id}), \@bind_values) if ($brand->{id});
		$sql .= $db->bind_and("type_set & ?", 2**($param->{type_id}-1), \@bind_values) if (${$param}{type_id});
		$sql .= $db->bind_and("project_id = ?", $param->{project_id}, \@bind_values);
		$sql .= $db->bind_and("revision_id = ?", $param->{revision_id}, \@bind_values);

		$sth = $dbh->prepare($sql);
		$sth->execute(@bind_values);

		if ($param->{output} eq "html") {
			while(my $row = $sth->fetchrow_hashref()) {
				$html .= $q->Tr($q->td([$brand->{name}, $row->{code}])) if ($row->{code});
			}
		} else {
			while(my $row = $sth->fetchrow_hashref()) {
				next unless ($row->{code});

				my @arr = split /,/, $row->{code};
				$row->{code} = "";
				for (my $i=0; $i < scalar(@arr); $i++) {
					if ($i % MAX_CODES_PER_LINE) {
						$row->{code} .= "   " . $arr[$i];
					} else {
						$row->{code} .= "\n" unless ($i == 0);
						$row->{code} .= "\t" . $arr[$i];
					}
				}

				if ($first_letter ne uc(substr($brand->{name}, 0, 1))) {
					$first_letter = uc(substr($brand->{name}, 0, 1));
					$txt .= "\n" . $first_letter . "\n";
				}
				$txt .= $brand->{name} . $row->{code} . "\n";
			}
		}
		$sth->finish();
	}

	my @bind_values = ();
	my $sql .= "SELECT DISTINCT code AS code FROM brand_to_code WHERE 1=1";
	$sql .= " AND brand_id IS NULL";
	$sql .= $db->bind_and("type_set & ?", 2**($param->{type_id}-1), \@bind_values) if (${$param}{type_id});
	$sql .= $db->bind_and("project_id = ?", $param->{project_id}, \@bind_values);
	$sql .= $db->bind_and("revision_id = ?", $param->{revision_id}, \@bind_values);

        $sth = $dbh->prepare($sql);
        $sth->execute(@bind_values);
	if ($param->{output} eq "html") {
		while(my $row = $sth->fetchrow_hashref()) {
			$html .= $q->Tr($q->td(["Other Brands", $row->{code}])) if ($row->{code});
		}
	} else {
		while(my $row = $sth->fetchrow_hashref()) {
			next unless ($row->{code});

			my @arr = split /,/, $row->{code};
			$row->{code} = "";
			for (my $i=0; $i < scalar(@arr); $i++) {
				if ($i % MAX_CODES_PER_LINE) {
					$row->{code} .= "   " . $arr[$i];
				} else {
					$row->{code} .= "\n" unless ($i == 0);
					$row->{code} .= "\t" . $arr[$i];
				}
			}

			$txt .= "\n---\n";
			$txt .= "Other Brands " . $row->{code} . "\n";
		}
	}

	if ($param->{output} eq "html") {
		$html .= $q->end_table();
		$html .= $q->end_html();

		print $html;
	} else {
		print "Content-type: text/plain; charset=utf-8\n";
		print $txt;
	}
}

my $q = CGI->new;
my %param = $q->Vars;

$param{type_id} = 1 if (!defined $param{type_id});
$param{output} = "text" if (!defined $param{output});

#if ($db->checkAccess(\%param)) {
# && ($ENV{HTTP_X_FORWARDED_FOR} =~ /178.188.122./ || $ENV{HTTP_X_FORWARDED_FOR} =~ /10.11.100./)) {
	select_code($q, \%param);
#} else {
#	$db->print_error($q, 401, "Unauthorized");
#}

$db->disconnect();
exit 0;
