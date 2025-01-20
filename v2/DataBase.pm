#!/usr/bin/perl -w

package DataBase;

use warnings;
use strict;
use DBI;
use JSON;
use XML::Simple qw(:strict);

use DataBaseConfig;

use open IO => ":utf8",":std";

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

		$self->print_error(442, $errormsg);
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
	$sql .= $self->bind("AND permission_key = ?", ${$param}{key}, \@bind_values);

	if ($param->{type_id}) {
		my @types = split(/,/, $param->{type_id});
		my $num = 0;
		foreach my $type_id (@types) {
			$num = 2**($type_id-1);
		}
		$sql .= $self->bind("AND type_set & ?", $num, \@bind_values);
	}

#FIXME - calculate offline_db_id by using revision_id
#	$sql .= $self->bind("AND (projects = ? OR projects = -1)", ${$param}{project_id}, \@bind_values) if (${$param}{project_id});
#	$sql .= $self->bind("AND (projects = ? OR projects = -1)", ${$param}{project_id}, \@bind_values) if (${$param}{project_id});
#	$sql .= $self->bind("AND (revisions = ? OR revisions = -1)", ${$param}{revision_id}, \@bind_values) if (${$param}{revision_id});

	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute(@bind_values);

	my ($ret) = $sth->fetchrow_array();
	$sth->finish();

	return $ret;
}

sub checkAccessDebug
{
	my ($self, $param) = @_;

	return 0 if (!$param->{debug});

	my @bind_values = ();
	my $sql = "SELECT COUNT(*) FROM permission WHERE offline_db_id IS NULL";
	$sql .= $self->bind("AND permission_key = ?", ${$param}{key}, \@bind_values);

	my $sth = $self->{dbh}->prepare($sql);
	$sth->execute(@bind_values);

	my ($ret) = $sth->fetchrow_array();
	$sth->finish();

	return $ret;
}

sub getPermissionTypes
{
	my ($self, $param) = @_;

	return "" unless ($param->{key});
        return "" unless ($param->{type_id} || $param->{type_name});

	#FIXME: if type_id=1 or type_name=tv add 13 or proj
	if (defined $param->{type_id}) {
		my @types = split(/,/, $param->{type_id});
		foreach my $type (@types) {
			$param->{type_id} .= ",13" if ($type == 1);	# tv + proj
		}
	}

	if (defined $param->{type_name}) {
		my @types = split(/,/, $param->{type_name});
		foreach my $type (@types) {
			$param->{type_name} .= ",'proj'" if ($type eq "'tv'");	# tv + proj
		}
	}

        my @bind_values = ();
	my $sql = "SELECT have.types & want.types AS types FROM ";
	$sql .= "(SELECT BIT_OR(type_set) AS types FROM permission WHERE 1=1 ";
        $sql .= $self->bind("AND permission.permission_key = ?", $param->{key}, \@bind_values);

        if (defined $param->{db_id}) {
                $sql .= $self->bind("AND permission.offline_db_id = ?", $param->{db_id}, \@bind_values);
        } else {
                $sql .= " AND permission.functions IS NOT NULL";
        }

	$sql .= ") AS have, ";

	$sql .= "(SELECT BIT_OR(POW(2, id-1)) AS types FROM type WHERE name_short IN (" . $param->{type_name} . ")) AS want" if ($param->{type_name});
	$sql .= "(SELECT BIT_OR(POW(2, id-1)) AS types FROM type WHERE id IN (" . $param->{type_id} . ")) AS want" if ($param->{type_id});

#	my $sql = "SELECT BIT_OR(type_set) AS type_set FROM permission WHERE 1=1";
#        $sql .= $self->bind("AND permission.permission_key = ?", $param->{key}, \@bind_values);
#        $sql .= $self->bind("AND permission.type_set & ?", $param->{type_id}, \@bind_values) if ($param->{type_id});
#        $sql .= $self->bind("AND FIND_IN_SET(?, permission.type_set)", $param->{type_name}, \@bind_values) if ($param->{type_name});
#        $sql .= "AND FIND_IN_SET(" . $param->{type_name} . ", permission.type_set)" if ($param->{type_name});

	#$param->{sql} = $sql;
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute(@bind_values);

        my ($ret) = $sth->fetchrow_array();
	$sth->finish();

        return $ret;
}

sub _func_expand
{
	my ($self, $fkt) = @_;

	return "" if (!defined $fkt);

	$fkt =~ s/%5d/[/gi;	# this is for copy/paste producing artifacts ...

	$fkt =~ s/\[\[BASIC\]\]/power,[[VOLUME]]/gi;

	$fkt =~ s/\[\[SYSTEM\]\]/[[TV]],[[NAVIGATION]],[[NUMBER]]/gi;
#	$fkt =~ s/\[\[INPUT_TV\]\]/power,[[VOLUME]],input,[[NAVIGATION]]/gi;
	$fkt =~ s/\[\[TV_INPUT\]\]/power,[[VOLUME]],input,[[NAVIGATION]]/gi;
	$fkt =~ s/\[\[TV\]\]/[[POWER]],channel_up,channel_down,[[VOLUME]]/gi;
	$fkt =~ s/\[\[NAVIGATION\]\]/[[CURSOR]],ok,enter,back/gi;

	$fkt =~ s/\[\[POWER\]\]/power,power_on,power_off/gi;
	$fkt =~ s/\[\[CURSOR\]\]/cursor_up,cursor_down,cursor_left,cursor_right,ok/gi;
	$fkt =~ s/\[\[NUMBER\]\]/number_0,number_1,number_2,number_3,number_4,number_5,number_6,number_7,number_8,number_9/gi;
	$fkt =~ s/\[\[VOLUME\]\]/volume_up,volume_down,mute/gi;
	$fkt =~ s/\[\[COLOR\]\]/red,green,yellow,blue/gi;
	$fkt =~ s/\[\[TRICKPLAY\]\]/[[PVR]]/gi;
	$fkt =~ s/\[\[PVR\]\]/play,stop,pause,play_pause,fast_rewind,fast_forward,skip_back,skip_forward/gi;
	$fkt =~ s/\[\[INPUT\]\]/input,input_next,input_previous,input_hdmi_1,input_hdmi_2,input_hdmi_3,input_av_1,input_av_2,input_av_3,input_av_s,input_pc,input_component,input_vcr,input_dvd,input_dtv,input_tv/gi;

	return $fkt;
}

sub _sql_func
{
        my ($self, $str) = @_;
        $str =~ tr/='"//;
        $str = join ",", map { qq!"$_"! } (split (/,/, $str));  #quote

        return "(func.name IN ($str) OR func.id IN ($str))";
}

sub getFkt
{
	my ($self, $param) = @_;

	my $sth;
	my $sql;
	my @bind_values = ();
	my $fkt = $param->{fkt};

	$fkt = $self->_func_expand($fkt);

### cleanup functions
	$fkt = $self->cleanList($fkt) if (defined $fkt && $fkt ne '');

### check permissions
	my $fkt_allowed = "*";

	$sql = "SELECT GROUP_CONCAT(functions) FROM permission WHERE 1 = 1";
	$sql .= $self->bind("AND permission_key = ?", $param->{key}, \@bind_values);
	$sth = $self->{dbh}->prepare($sql);
	$sth->execute(@bind_values);

	($fkt_allowed) = $sth->fetchrow_array();
	$sth->finish();

	$fkt_allowed = $self->_func_expand($fkt_allowed);

	$sql = "SELECT GROUP_CONCAT(id) FROM function AS func WHERE 1=1";
	$sql .= " AND ".$self->_sql_func($fkt) if ($fkt ne "");
	$sql .= " AND ".$self->_sql_func($fkt_allowed) if ($fkt_allowed ne "" && $fkt_allowed !~ /\*/);

	$sth = $self->{dbh}->prepare($sql);
	$sth->execute();
	my ($funcs) = $sth->fetchrow_array();
	$sth->finish();

	return "0" if ($funcs eq "");
	return $funcs;
}

sub cleanupParam
{
	my ($self, $param) = @_;

	delete $param->{brand_id} if (defined $param->{brand_id} && $param->{brand_id} eq '');
	delete $param->{brand_name} if (defined $param->{brand_name} && $param->{brand_name} eq '');

	delete $param->{model_id} if (defined $param->{model_id} && $param->{model_id} eq "true");              # HACK for jquery
	delete $param->{model_name} if (defined $param->{model_name} && $param->{model_name} eq "true");        # HACK for jquery
	delete $param->{model_id} if (defined $param->{model_id} && $param->{model_id} eq '');
	delete $param->{model_name} if (defined $param->{model_id} && $param->{model_name} eq '');

	$param->{project_id} = $param->{reference} if (!defined $param->{project_id});
	$param->{project_id} = $param->{project} if (!defined $param->{project_id});
	$param->{revision_id} = $param->{revision} if (!defined $param->{revision_id});
#FIXME: create db_id

#       $param->{type_id} = 1 if ($param->{type_id} == 0);      #20160428
	delete $param->{type_id} if (defined $param->{type_id} && $param->{type_id} <= 0);
	delete $param->{type_id} if (defined $param->{type_id} && $param->{type_id} eq '');

	if ($param->{type_name}) {
		$param->{type_name}  =~ s/[^a-zA-Z,]//g;
		$param->{type_name}  =~ s/,/','/g;
		$param->{type_name}  = "'" .  $param->{type_name} . "'";
	}

	$self->{__types} = $self->getPermissionTypes($param);
	$self->{__fkt} = $self->getFkt($param);
	$self->{__debug} = $param->{debug};
	$self->{__debug} = 0 if (!$self->checkAccessDebug($param));
	$self->{__permission} = $self->checkAccess($param);

	if ($param->{key} eq "0afdfc10668a") {                    # leaf rcu
		$param->{compress} = 2;
		$param->{age} = 7 if (!exists $param->{age});
		$param->{__debug} = 0;
	}
	elsif ($param->{key} eq "6de1abc60f4a") {                 # flirc rcu
		$param->{age} = 3;
		$param->{__debug} = 0;
	}
	elsif ($param->{key} eq "8ae3858e41e8") {                 # astro
		$param->{age} = 13;                               #20180919
		$param->{__debug} = 0;
	}
	elsif (defined $param->{key} && $param->{key} ne "9385807aba71" && !exists $param->{revision}) {
		$param->{age} = 7 if (!defined $param->{age} || $param->{age} > 7 || $param->{age} <= 0);
		$param->{__debug} = 0;
	}

	# ignore age if we know what we want
	if (defined $param->{model_id} || defined $param->{model_name} && $param->{model_name} ne "") {
		delete $param->{age};
	}

#	delete $param->{age} if (defined $param->{age} && $param->{age} <= 0);

	$param->{limit} = $self->cleanLimit($param->{limit}) if ($param->{limit});
	$param->{compress} = 1 if (!defined $param->{compress});

#	$param->{fkt_required} = $signalList->_func_expand($param->{fkt_required}) if (defined $param->{fkt_required});
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
	$str =~ s/[^0-9a-zA-Z\.\+\*\]\[\<\>:\^\$]+//g; 

	return $str;
}

sub bind
{
	my ($self, $str, $val, $bind_values) = @_;

	push(@{$bind_values}, $val);

	return " $str ";
}

sub print_json
{
	my ($self, $q, $total, $data, $hdr) = @_;

	print $q->header(
		-type  =>  'application/json',
		-charset => 'UTF-8',
		%{$hdr}
	);

#	print $q->Accept() . "\n";
#	print $q->Accept('application/xml') . "\n";
#	print $q->Accept('application/json') . "\n";
#	print $q->Accept('application/jsonp') . "\n";

	my @out;
	my @arr;

### FIXME: the following lines are ugly...
	@arr = @{$data->{types}->{item}} if (defined $data->{types});
	@arr = @{$data->{brands}->{item}} if (defined $data->{brands});
	@arr = @{$data->{models}->{item}} if (defined $data->{models});
	@arr = @{$data->{codes}->{code}} if (defined $data->{codes});

	if (defined $data->{remotes}) {
		@arr = @{$data->{remotes}->{remote}};
		foreach (@arr) {
			my %hash = %$_;
			push @out, $hash{base64}{content};
		}

		$data = \@out;
	} elsif (@arr) {
		foreach (@arr) {
			my %hash = %$_;
			push @out, {id => $hash{id}, label => $hash{content}};
		}

		$data = \@out;
	} else { $data = []; }

	if ($q->Vars->{jsonp}) {
		printf "%s(%s);", $q->Vars->{jsonp}, JSON::to_json($data);
	} else {
		print JSON::to_json($data);
	}
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
	print $xs->XMLout({data => $data}, KeyAttr => {signal => 'id'});
}

sub print
{
	my ($self, $q, $total, $data, $hdr) = @_;

	my $use_xml = $q->Accept('application/xml');
	my $use_json = $q->Accept('application/json');
	my $use_jsonp = $q->Accept('application/jsonp');

	$use_json = 0 if ($use_xml > $use_json);
	$use_jsonp = 0 if ($use_xml > $use_jsonp);
	$use_xml = 0 if ($use_json > $use_xml);
	$use_jsonp = 0 if ($use_json > $use_jsonp);
	$use_xml = 0 if ($use_jsonp > $use_xml);
	$use_json = 0 if ($use_jsonp > $use_json);

	if ($use_json > 0) { 
		$self->print_json($q, $total, $data, $hdr);
	} elsif ($use_jsonp > 0) {
		$self->print_json($q, $total, $data, $hdr);
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
