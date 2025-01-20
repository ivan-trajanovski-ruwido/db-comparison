#!/usr/bin/perl -w

package RuwidoManual;

use warnings;
use strict;
use utf8;
use POSIX;

use CGI;
use DBI;
use DataBase;

use constant MAX_CODES_PER_LINE => 6;

sub new {
	my ($class) = @_;

	my $self = {
		dbh             => undef,
	};

	bless $self, $class;

	return $self;
}

sub get_type_name
{
	my ($self, $type_id) = @_;

	my $sql = "SELECT name FROM type WHERE id = ?";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute($type_id);

	my $row = $sth->fetchrow_hashref();
	$sth->finish();

	return $row->{name};
}

sub get_proj_meta
{
	my ($self, $project_id, $revision_id) = @_;

	my $sql = "SELECT * FROM code_meta WHERE project_id = ? AND revision_id = ?";
	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute($project_id, $revision_id);

	my $row = $sth->fetchrow_hashref();
	$sth->finish();

	return $row;
}

sub get_header
{
	my ($self, $hdr, $param) = @_;

	my $meta = $self->get_proj_meta($param->{project_id}, $param->{revision_id});
	my $name = (defined $param->{type_id}) ? $self->get_type_name($param->{type_id}) : "UNDEFINED";

	my $txt = "\n";
	$txt .= "---\n";
	$txt .= sprintf ("%s %s/%s (%s) %s",
		$hdr,
		$meta->{project_name},
		$meta->{revision_name},
		$meta->{date},
		$name);
	$txt .= "\n---\n";

	$txt .= sprintf("Product Type:\t%s\n", "TYPE");
	$txt .= sprintf("Project ID:\t%s\n", $param->{project_id});
	$txt .= sprintf("Revision ID:\t%s\n", $param->{revision_id});
	$txt .= sprintf("Database ID:\t%04d%02d\n", $param->{project_id}, $meta->{revision_number});
	$txt .= sprintf("RCU Database Version:\t%s\n", $meta->{revision_name});
	$txt .= sprintf("RCU Database Timestamp:\t%s\n", $meta->{date});
	$txt .= sprintf("Online Database Timestamp:\t%s\n", strftime("%Y-%m-%d %H:%M:%S UTC", localtime));
	$txt .= "---\n";

	return $txt;
}

1;
