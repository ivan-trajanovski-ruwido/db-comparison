#!/usr/bin/perl -w

package DataBase;

use strict;
use DBI;

use CGI::Fast;
use JSON;
use XML::Simple qw(:strict);

use Data::Dumper;
use DataBaseConfig;

use open IO => ":utf8",":std";
#binmode(STDOUT, 'utf8:');

use constant xml_hdr => "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";

sub new {
	my ($class) = @_;

	my $self = $DataBaseConfig::CFG;
	bless $self, $class;

	return $self;
}

sub connect {
	my ($self) = @_;

	$self->{dbh} = DBI->connect($self->{db}, $self->{db_user}, $self->{db_pass},
	{
		RaiseError		=> 1,
		AutoCommit		=> 0,
		PrintError		=> 0,
		ShowErrorStatement	=> 0
	});

	$self->{dbh}->do(qq{SET NAMES 'utf8';});

	$self->{dbh}->{HandleError} = sub {
		my $errormsg = shift;
		my $handle   = shift;
#		$self->print_error(442, $errormsg);
		print "+++++++++ $errormsg\n";
		exit;
	};

	$self->{dbh}->{mysql_enable_utf8} = 1;

	return $self->{dbh};
}

sub disconnect {
	my ($self) = @_;

	$self->{dbh}->disconnect();
}

sub fetchall_total_array_hashref {
	my ($self, $sth) = @_;

	my $total = $self->{dbh}->selectrow_array("SELECT FOUND_ROWS()");

	my $items = [];
        while(my $row = $sth->fetchrow_hashref()) {
                push @$items, $row;
        }

	return ($total, $items);
}

sub checkAccess
{
	my ($self, $param) = @_;

	my @bind_values = ();
	my $sql = "SELECT COUNT(*) FROM permission WHERE 1 = 1";
	$sql .= $self->bind_and("permission_key = ?", ${$param}{key}, \@bind_values);
	$sql .= $self->bind_and("type_set & ?", 2**($param->{type_id}-1), \@bind_values) if (${$param}{type_id});
	$sql .= $self->bind_and("(projects = ? OR projects = -1)", ${$param}{project_id}, \@bind_values) if (${$param}{project_id});
	$sql .= $self->bind_and("(revisions = ? OR revisions = -1)", ${$param}{revision_id}, \@bind_values) if (${$param}{revision_id});

	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute(@bind_values);

	my ($ret) = $sth->fetchrow_array();
	$sth->finish();

	return $ret;
}

sub checkAccessDebug
{
	my ($self, $param) = @_;

	return 0 if (!${$param}{debug});

	my @bind_values = ();
	my $sql = "SELECT COUNT(*) FROM permission WHERE projects=-1";
	$sql .= $self->bind_and("permission_key = ?", ${$param}{key}, \@bind_values);

	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute(@bind_values);

	my ($ret) = $sth->fetchrow_array();
	$sth->finish();

	return $ret;
}

sub encode
{
	my ($self, $str) = @_;

	$str =~ s/&/&amp;/g;
	$str =~ s/</&lt;/g;
	$str =~ s/>/&gt;/g;
	$str =~ s/\"/&quot;/g;
	$str =~ s/\'/&apos;/g;

	return $str;
}

sub cleanLimit
{
	my ($self, $limit, $max) = @_;

	$max = $max ? $max : $self->{_default_limit};
        return $max if (!$limit);

	$limit =~ s/[^0-9,]//g; 

	if ($limit =~ /,/) {
		my @arr = split(/,/, $limit);
		$arr[1] = $max if ($arr[1] > $max);
		return $arr[0] . "," . $arr[1];
	}

	return $limit < $max ? $limit : $max;
}

sub cleanTypeId
{
	my ($self, $type_id) = @_;

#	my $sql = "SELECT FROM permission WHERE 1=1";
#	$sql .= $self->bind_and("type_set & ?", 2**($param->{type_id}-1), \@bind_values);
#	$sql .= $self->bind_and("permission_key = ?", ${$param}{key}, \@bind_values);
#	my $sth = $self->{dbh}->prepare($sql);
#	$sth->execute(@bind_values);

#	my ($ret) = $sth->fetchrow_array();
#	$sth->finish();

	return $type_id ? $type_id : $self->{_default_type_id};
}

#only allow alphanum and commas
sub cleanList
{
	my ($self, $list) = @_;

	$list =~ s/[^0-9,a-z_]*//g;
	$list =~ s/,+/,/g;
	$list =~ s/,$//g;

	return $list;
}

sub cleanListNum
{
	my ($self, $list) = @_;

	$list =~ s/[^0-9,]*//g;
	$list =~ s/,+/,/g;
	$list =~ s/,$//g;

	return $list;
}

sub createSearch
{
	my ($self, $str) = @_;

	$str =~ s/\ //g;
	$str =~ s/\&//g;
#	$str =~ s/[^0-9a-zA-Z]//g;		#FIXME
	$str =~ s/[^0-9a-zA-Z\.\+\*\]\[\<\>:\^\$]+//g; 

	return $str;
}

sub bind_and
{
	my ($self, $str, $val, $bind_values) = @_;

	push(@{$bind_values}, $val);

	return " AND $str ";
}

sub bind
{
	my ($self, $str, $val, $bind_values) = @_;

	push(@{$bind_values}, $val);

	return " $str ";
}

sub printHeader
{
	my ($self, $q) = @_;

	if ($q->Accept('application/xml') > 0) {
		print $q->header(
			-type  =>  'application/xml');

		print (DataBase::xml_hdr);
	}
}

sub print_json
{
	my ($self, $q, $total, $data, $hdr) = @_;

	print $q->header(
		-type  =>  'application/json',
		-charset => 'UTF-8',
		%{$hdr}
	);

	print JSON::to_json($data);
}

sub print_xml
{
	my ($self, $q, $total, $data, $hdr) = @_;

	print $q->header(
		-status => 200,	#$total ? 200 : 442,
		-type  =>  'application/xml',
		-charset => 'UTF-8',
		%{$hdr},
	);
	print (DataBase::xml_hdr);
	my $xs = XML::Simple->new(ForceArray => 1, KeepRoot => 1, NoIndent => 0, NoSort => 0);
	print $xs->XMLout({data => $data}, KeyAttr => {signal => 'descr'});
}

sub print
{
	my ($self, $q, $total, $data, $hdr) = @_;

	my $use_xml = $q->Accept('application/xml');
	my $use_json = $q->Accept('application/json');
	my $use_jsonp = $q->Accept('application/jsonp');

#	$use_xml = 1 if ($q->Accept('application/xml') eq "");

	if ($use_xml <= $use_json && $use_xml <= $use_jsonp) {
		my %param = $q->Vars;
		if ($param{jsonp}) {
			print $param{jsonp} . "(";
			$self->print_json($q, $total, $data, $hdr);
			print ");";
		} else {
			$self->print_json($q, $total, $data, $hdr);
		}
	} else {
		$self->print_xml($q, $total, $data, $hdr);
	}
}

sub print_error
{
	my ($self, $q, $id, $msg) = @_;

	print $q->header(
		-status => $id,
		-type  =>  'application/xml',
		-charset => 'UTF-8',
	);
	print (xml_hdr);
	print "<error data=\"1.0\" code=\"$id\">";
	print "<msg>$msg</msg>";
	print "</error>";
}

1;
