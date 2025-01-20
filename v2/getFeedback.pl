#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI  qw(-utf8);
use DBI;
use DataBase;

use open IO => ":utf8",":std";

my $db = new DataBase();
$db->{db} = $db->{db_schema_feedback};
my $dbh = $db->connect();
$dbh->do(qq{SET NAMES 'utf8';});

sub select_feedback
{
	my ($q, $param) = @_;
	my @bind_values = ();

	my $is_hdr = 1;

	my $sth;

	my $items = "";
	$items .= "status AS Status, " if (!$param->{status});
	$items .= "ts AS 'Oldest Entry', brand_name AS Brand, model_name AS Model, GROUP_CONCAT(DISTINCT(project_id) ORDER BY project_id) AS Projects ";

	my $items2 = "";
	$items2 .= "result AS status, " if (!$param->{status});
	$items2 .= "ts, brand_name, UPPER(model_name) AS model_name, project_id ";

	my $sql = "SELECT $items FROM (SELECT $items2 FROM feedback WHERE 1=1 ";
        $sql .= $db->bind_and("result = ?", $param->{status}, \@bind_values) if (defined $param->{status});
        $sql .= $db->bind_and("ts > NOW() - INTERVAL ? WEEK", $param->{weeks}, \@bind_values) if (defined $param->{weeks});
	$sql .= "ORDER BY ts) t1 GROUP BY Brand, Model;";


	$sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);

#	my $items = [];

	my $html = "";

	$html .= $q->header(-charset=>'utf-8');
	$html .= $q->start_html(
		-title => "Feedback",
		-style => {'src'=>'/shared/css/ruwido.css'},
	);
	$html .= "<div class=\"orange\">using STATUS: \"FAILED\"</div><br/>" if ($param->{status} eq "FAILED");
	$html .= $q->start_table({-width => "100%"});
	$html .= $q->Tr($q->th($sth->{NAME}));

	while(my $row = $sth->fetchrow_arrayref()) {
		if (!$param->{status} && $row->[0] eq "FAILED") {
			$html .= $q->Tr({-class => "orange"}, $q->td($row));
		}
		$html .= $q->Tr($q->td($row));
	}
	$html .= $q->end_table();
	$html .= $q->end_html();

	print $html;

	$sth->finish();

#	$db->print($q, $total, {codes => {total => $total, code => $items}, type=>"brandcode"}, {-vary => "Accept"});
}

my $q = CGI->new;
my %param = $q->Vars;

delete $param{status} if (defined $param{status} && $param{status} eq "");
select_feedback($q, \%param);
$db->disconnect();
exit 0;

if ($db->checkAccess(\%param)) {
	select_feedback($q, \%param);
} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;
