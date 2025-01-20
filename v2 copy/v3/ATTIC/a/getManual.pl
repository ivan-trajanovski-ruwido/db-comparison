#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use POSIX qw(strftime);

use DataBase;
use RuwidoManual;
use RuwidoSignalList;

use constant MAX_CODES_PER_LINE => 6;

my $db = new DataBase();
my $dbh = $db->connect();

my $signalList = new RuwidoSignalList($db, $dbh);
my $manual = new RuwidoManual();
$manual->{dbh} = $dbh;

sub select_code
{
	my ($q, $param) = @_;
	my $limit = $param->{limit};

	print $q->header(
		-type  =>  'text/html',
		-charset => 'UTF-8',
	);
	print $q->start_html(
		-title => "Manual Selector",
		-style => {'src'=>'/css/ruwido.css'},
	);
	print $q->start_table(
		-class => "three-col"
	);
	print $q->Tr($q->th(["Project", "Revision", "Date", "CodeManual", "BrandManual"]));

	my $sql = "SELECT * FROM code_meta WHERE project_name NOT LIKE '%text%' ORDER BY project_name, revision_name";
	$sql = "SELECT * FROM code_meta WHERE project_name NOT LIKE '%text%' ORDER BY date, project_name, revision_name" if ($param->{order} eq "date");

	my $sth = $dbh->prepare($sql);
	$sth->execute();

	my $sth_code = $dbh->prepare("SELECT DISTINCT type.id, type.name_short AS name FROM oem_to_code JOIN type ON type_id=type.id WHERE project_id=? AND revision_id=? ORDER BY type.id");
	my $sth_brand = $dbh->prepare("SELECT DISTINCT type.id, type.name_short AS name FROM brand_to_code JOIN type ON type_id=type.id WHERE project_id=? AND revision_id=? ORDER BY type.id");

	while(my $entry = $sth->fetchrow_hashref()) {
		my @code1;
		my @brand1;
		my @csv1;

		$sth_code->execute($entry->{project_id},$entry->{revision_id});
		while(my $entry2 = $sth_code->fetchrow_hashref()) {
			push @code1,  "<a href=\"/internal/".$param->{key}."/v2/codeManual/".$entry->{project_id}."/".$entry->{revision_id}."/$entry2->{id}?output=text\">$entry2->{name}</a>";
#			push @csv1,  "<a href=\"/internal/".$param->{key}."/v2/codeManual/".$entry->{project_id}."/".$entry->{revision_id}."/$entry2->{id}?output=csv\">CSV:$entry2->{name}</a>";
		}
		$sth_brand->execute($entry->{project_id},$entry->{revision_id});
		while(my $entry2 = $sth_brand->fetchrow_hashref()) {
			push @brand1, "<a href=\"/internal/".$param->{key}."/v2/brandManual/".$entry->{project_id}."/".$entry->{revision_id}."/$entry2->{id}?output=text\">$entry2->{name}</a>";
		}

		my $codes = join(" ", @code1);
		my $brands = join(" ", @brand1);
		$brands = "Brand: " . $brands if ($brands ne "");

		next if ($codes eq "");
		print $q->Tr($q->td([$entry->{project_name}, $entry->{revision_name}, $entry->{date}, $codes, $brands, join(" ", @csv1)]));
	}
	$sth->finish();

	print $q->end_table();
	print $q->end_html();
}

my $q = CGI->new;
my %param = $q->Vars;

$param{type_id} = 1 if (!defined $param{type_id});
$param{output} = "html" if (!defined $param{output});

#$param{fkt} = $signalList->db_get_func($param);

if ($db->checkAccess(\%param)) {
	select_code($q, \%param);
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
