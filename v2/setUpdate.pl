#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use DataBase;

my $db = new DataBase();
$db->{db} = $db->{db_schema_feedback};
my $dbh = $db->connect();

sub set_usage
{
        my ($q, $param) = @_;

        my @bind_values = ();
        my $sth;

        $sth = $dbh->prepare("INSERT INTO ruwido_rc_feedback.usage (client_key, edid, nr_successful) VALUES (?,?,?)");
        $sth->execute($param->{key}, $param->{edid}, $param->{nr_successful});
        $dbh->commit();

        $db->printHeader($q);
        print '<data/>';
}

my $q = CGI->new;
my %param = $q->Vars;

foreach my $item (("key", "nr_successful")) {
        $param{$item} = $q->url_param($item) if (!defined $param{$item});
}

set_usage($q, \%param);

$db->disconnect();
exit 0;
