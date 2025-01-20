#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use CGI;
use DBI;
use POSIX qw(strftime);
use DataBase;
use RuwidoManual;

use Data::Dumper;

use constant MAX_CODES_PER_LINE => 6;

my $q = CGI->new;
my %param = $q->Vars;

my $db = new DataBase();
my $dbh = $db->connect();

my $manual = new RuwidoManual($dbh);

$db->cleanupParam(\%param);

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

	my @bind_values = ();
	my $sql = "SELECT *, brand.name AS brand_name FROM brand_to_code ";
	$sql .= " JOIN brand ON (brand_id = brand.id) ";
	$sql .= " JOIN offline_db ON (offline_db_id = offline_db.id) ";
	$sql .= " WHERE 1=1";
	$sql .= $db->bind("AND brand_id IN (SELECT id FROM brand WHERE name = ?)", $db->cleanTypeId($param->{brand_name}), \@bind_values) if ($param->{brand_name});
	$sql .= $db->bind("AND 1<<(type_id-1) & ?", $db->{__types},  \@bind_values) if ($db->{__types});
	$sql .= $db->bind("AND revision_id = ?", $param->{revision_id}, \@bind_values);
	$sql .= " ORDER BY brand.name";

	$sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);

	if ($param->{output} eq "html") {
		while(my $row = $sth->fetchrow_hashref()) {
			$html .= $q->Tr($q->td([$row->{name}, $row->{code}])) if ($row->{code});
		}
	} else {
		while(my $row = $sth->fetchrow_hashref()) {
			next unless (defined $row->{code});

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

			if ($first_letter ne uc(substr($row->{brand_name}, 0, 1))) {
				$first_letter = uc(substr($row->{brand_name}, 0, 1));
				$txt .= "\n" . $first_letter . "\n";
			}
			$txt .= $row->{brand_name} . $row->{code} . "\n";
		}
	}
	$sth->finish();

	@bind_values = ();
	$sql = "SELECT code FROM brand_to_code ";
	$sql .= " JOIN offline_db ON (offline_db_id = offline_db.id) ";
	$sql .= " WHERE brand_id IS NULL";
	$sql .= $db->bind("AND 1<<(type_id-1) & ?", $db->{__types},  \@bind_values) if ($db->{__types});
	$sql .= $db->bind("AND revision_id = ?", $param->{revision_id}, \@bind_values);

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

$param{type_id} = 1 if (!defined $param{type_id});
$param{output} = "text" if (!defined $param{output});

select_code($q, \%param);

$db->disconnect();
exit 0;
