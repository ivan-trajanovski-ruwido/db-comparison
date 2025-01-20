#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use CGI;
use DBI;
use DataBase;

my $db = new DataBase();
$db->{db} = $db->{db_schema_feedback};
#"DBI:mysql:ruwido_rc_feedback";
my $dbh = $db->connect();

sub set_feedback
{
	my ($q, $param) = @_;

	my @bind_values = ();
	my $sth;

	my $remote_addr = $ENV{REMOTE_ADDR};
	$remote_addr = "undefined" if (!defined $remote_addr);
	$remote_addr = $ENV{HTTP_X_FORWARDED_FOR} if ($remote_addr eq "127.0.0.1" && $ENV{HTTP_X_FORWARDED_FOR});
	$param->{key} = "undefined" if (!defined $param->{key});

        $sth = $dbh->prepare("INSERT INTO feedback (result, client, client_key, meta_id, brand_id, brand_name, model_id, model_name, rc_id, rc_name, code, data, comment, project_id, revision_id, type_id, type_name, meta_type, meta_data, reference, reference_url) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
        $sth->execute($param->{result}, $remote_addr, $param->{key}, $param->{meta_id}, $param->{brand_id}, $param->{brand_name}, $param->{model_id}, $param->{model_name}, $param->{rc_id}, $param->{rc_name}, $param->{code_id}, $param->{data}, $param->{comment}, $param->{project_id}, $param->{revision_id}, $param->{type_id}, $param->{type_name}, $param->{meta_type}, $param->{meta_data}, $param->{reference}, $param->{reference_url});
        $dbh->commit();

        $db->printHeader($q);
        print '<data/>';
}

my $q = CGI->new;
my %param = $q->Vars;

$param{project_id} = $param{proj} if (!exists $param{project_id} && defined $param{proj});
$param{revision_id} = $param{rev} if (!exists $param{revision_id} && defined $param{rev});

$param{key} = $q->url_param('key');
$param{type_name} = $q->url_param('type_name');
$param{type_id} = $q->url_param('type_id');
$param{brand_name} = $q->url_param('brand_name');
$param{brand_id} = $q->url_param('brand_id');
$param{model_name} = $q->url_param('model_name');
$param{result} = $q->url_param('result');

set_feedback($q, \%param);

$db->disconnect();
exit 0;
