#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use DataBase;

my $db = new DataBase();
$db->{db} = "DBI:mysql:ruwido_rc_feedback";
my $dbh = $db->connect();

sub eval_feedback
{
	my ($q, $param) = @_;
	my $limit = $param->{limit};

	my $sth;

	my $items = [];

	my $feedback = "";
	my $txt = "";
	my $html = "";

	if (1) {
		my $sql;
		$sql = "SELECT count(*) AS brand_count, name AS brand_name FROM feedback JOIN ruwido_rc.brand ON brand_id = brand.id GROUP BY brand_id ORDER BY brand_count DESC";
		$sth = $dbh->prepare($sql);
		$sth->execute();

		while(my $ref = $sth->fetchrow_hashref()) {
			$txt .= "<tr><td>$ref->{brand_count}</td><td>$ref->{brand_name}</td></tr>\n";
		}

		$html = qq'
        <h1 class="headline">Feedback Evaluation</h1>
        <table width="100%">
                <tr><th>Brand Count</th><th>Brand</th></tr>
$txt
        </table>
';
	}
	$sth->finish();

	$feedback .= $html;

	#$db->print($q, $total, {codes => {total => $total, code => $items}}, {-vary => "Accept"});
	$html = qq'
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <link rel="StyleSheet" href="http://svn.ruwido.com/email.css" type="text/css" media="screen"/>
</head>
<body>
        <img align="right" src="http://svn.ruwido.com/img/ruwido_research_logo.png" width="156">
        <br/><br/>

        $feedback
</body>
</html>
';

	print $q->header(-type  =>  'text/html');
	print $html;
}

my $q = CGI->new;
my %param = $q->Vars;
eval_feedback($q, \%param);

$db->disconnect();
exit 0;
