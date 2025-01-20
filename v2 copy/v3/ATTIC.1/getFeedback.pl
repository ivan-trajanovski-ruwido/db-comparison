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
	my $sql = "SELECT result, ts AS Time, type.name AS 'Type', brand.name AS 'Brand Name', model_name AS 'Model Name', rc_name AS 'RemoteControl', code AS 'Code Used', project_id AS Project_ID, revision_id AS Revision_ID, comment AS Comment FROM feedback JOIN ruwido_rc.brand ON brand_id = brand.id JOIN ruwido_rc.type ON type_id = type.id";
        $sql .= $db->bind_and("type.id = ?", $param->{type_id}, \@bind_values) if (defined $param->{type_id});
        $sql .= $db->bind_and("client_key = ?", $param->{key}, \@bind_values) if ($param->{key} ne "9385807aba71");	#master key

	$sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);

	my $items = [];

	my $html = "";

	$html .= $q->header(-charset=>'utf-8');
	$html .= $q->start_html(
		-title => "Feedback",
		-style => {'src'=>'/css/ruwido.css'},
	);
	$html .= $q->start_table({-width => "100%"});
	$html .= $q->Tr($q->th($sth->{NAME}));

	while(my $row = $sth->fetchrow_arrayref()) {
		if ($row->[0] eq "FAILED") {
#			shift @{$row};
			$html .= $q->Tr({-class => "orange"}, $q->td($row));
		} else {
#			shift @{$row};
			$html .= $q->Tr($q->td($row));
		}
	}
	$html .= $q->end_table();
	$html .= $q->end_html();

	print $html;

	$sth->finish();

#	$db->print($q, $total, {codes => {total => $total, code => $items}, type=>"brandcode"}, {-vary => "Accept"});
}

my $q = CGI->new;
my %param = $q->Vars;

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
