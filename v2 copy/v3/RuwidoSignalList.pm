#!/usr/bin/perl

# debug=1	DISABLE CONTENT
# debug=2	descr
# debug=4	decoding
# debug=8	from_id

package RuwidoSignalList;

use strict;
use utf8;
use CGI;
use DBI;
use DataBase;
use RcSignalDecode;
use Data::Dumper;

sub new {
	my ($class, $db, $dbh) = @_;

	my $self = {
		db	=> $db,
		dbh	=> $dbh,
	};

	bless $self, $class;

	return $self;
}

sub isint{
	my ($self, $val) = @_;
	return ($val =~ m/^\d+$/);
}

sub find_match_part
{
	my ($self, $key, $items_ref, $param) = @_;

	foreach my $key_cmp (keys %{$items_ref}) {
		next if $key eq $key_cmp;

		my $found = 0;
		foreach my $key_btn (keys $items_ref->{$key}) {
			next if (!$self->isint($key_btn));	# for "num", "weight"
			next if (!exists $items_ref->{$key}{$key_btn} || !exists $items_ref->{$key_cmp}{$key_btn});	# button does exist in only one

#NOTE: the check for priorities is only performed if the content doesn't match, since content can match even for different priorities
			if ($items_ref->{$key}{$key_btn}{content} eq $items_ref->{$key_cmp}{$key_btn}{content}) {
				$found = 1;
			} else {
## FIXME: this needs to be checked - this returs wrong results...
#				next if ($param->{compress} > 1 && ($items_ref->{$key}{$key_btn}{priority} !=  1 || $items_ref->{$key_cmp}{$key_btn}{priority} != 1));	# ignore priorities > 1
#CHECKME
				next if ($param->{compress} > 1 && $items_ref->{$key_cmp}{$key_btn}{priority} > 1);	# ignore priorities > 1
			
				$found = 0;
				last;
			}
		}

		return $key_cmp if ($found != 0);
	}

	return 0;
}

sub do_compress
{
	my ($self, $item_ref, $param) = @_;

	foreach my $key (keys %{$item_ref}) {
#print $key . "\n";

		# find if the overlapping parts match
		my $key_cmp = $self->find_match_part($key, $item_ref, $param);

		if ($key_cmp) {
			# copy all keys
			foreach my $key_btn (keys $item_ref->{$key}) {
next if (!$self->isint($key_btn));	# for "num", "weight"
				if ($param->{compress} > 3) {
					next if (exists $item_ref->{$key}{$key_btn} && exists $item_ref->{$key_cmp}{$key_btn});	# button is already in both entries
				} else {
					next if (exists $item_ref->{$key}{$key_btn} && exists $item_ref->{$key_cmp}{$key_btn} && $item_ref->{$key}{$key_btn}{priority} >= $item_ref->{$key_cmp}{$key_btn}{priority});	# button is already in both entries
				}

				$item_ref->{$key_cmp}{$key_btn} = $item_ref->{$key}{$key_btn};
			}
			$item_ref->{$key_cmp}{num} += $item_ref->{$key}{num};
			$item_ref->{$key_cmp}{weight} += $item_ref->{$key}{weight};
			$item_ref->{$key_cmp}{oem_id} .= ", " . $item_ref->{$key}{oem_id};

			delete $item_ref->{$key};
		}
	}

	return $item_ref;
}

sub do_merge
{
	my ($self, $item_ref, $item_default, $param) = @_;

	foreach my $key (keys %{$item_ref}) {
		foreach my $key_btn (keys %{$item_default}) {
			next if (exists $item_ref->{$key}{$key_btn});	# button elready exists

			$item_ref->{$key}{$key_btn} = $item_default->{$key_btn};
			$item_ref->{$key}{$key_btn}{from_id} = "default" if ($param->{debug} & 0x08);
		}
	}

	return $item_ref;
}

sub db_get_oem_ids
{
	my ($self, $param) = @_;

	my $sth;
	my @bind_values = ();

	my $db = $self->{db};
	my $dbh = $self->{dbh};

$param->{age} = 20 unless ($param->{age} > 0);	#DENT: FIXME

	my $sql = "SELECT DISTINCT rc_oem_id FROM mv_union JOIN mv_union_to_oem ON mv_union.id = mv_union_to_oem.mv_union_id WHERE 1 = 1";
$sql .= $db->bind_and("mv_union.date >= DATE_SUB(CURDATE(), INTERVAL ? YEAR)", $param->{age}, \@bind_values);
$sql .= " AND from_table NOT LIKE 'model_series'";	#TM 20170224
	if ($param->{type_id}) {
		if ($param->{type_id} == 1) {	#FIXME_TV
        		$sql .= $db->bind_and("mv_union.type_id = ?", $db->cleanTypeId($param->{type_id}), \@bind_values);
		} else {
        		$sql .= $db->bind_and("mv_union.type_set & ?", 2**($db->cleanTypeId($param->{type_id})-1), \@bind_values);
		}
	}
        $sql .= $db->bind_and("FIND_IN_SET(?, mv_union.type_set)", $param->{type_name}, \@bind_values) if ($param->{type_name});
	if (defined $param->{brand_id}) {
		$sql .= $db->bind_and("brand_id = ?", $param->{brand_id}, \@bind_values);
	} elsif (defined $param->{brand_name}) {
#		$sql .= $db->bind_and("brand_id IN (SELECT id FROM brand WHERE name REGEXP ?)", $param->{brand_name}, \@bind_values);
		$sql .= $db->bind_and("brand_id IN (SELECT id FROM brand WHERE name_search REGEXP ?)", $db->createSearch($param->{brand_name}), \@bind_values);
	}
	if (defined $param->{model_id}) {
		$sql .= $self->{db}->bind_and("id = ?", $param->{model_id}, \@bind_values);
	} elsif (defined $param->{model_name}) {
		$sql .= $db->bind_and("name REGEXP ?", $db->createSearch($param->{model_name}), \@bind_values);
	}
	$sql .= " AND name != 'default'";

	$sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);

	my $oems = "";
	while(my ($oem) = $sth->fetchrow_array()) {
		$oems .= $oem.",";
	}
	$sth->finish();

	$oems =~ s/,$//g;
	return $oems;
}

sub _sql_func
{
	my ($self, $str) = @_;
	$str =~ tr/='"//;
	$str = join ",", map { qq!"$_"! } (split (/,/, $str));	#quote

	return "(func.name IN ($str) OR func.id IN ($str))";
}

sub _func_expand
{
	my ($self, $fkt) = @_;
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

sub db_get_func
{
	my ($self, $param) = @_;

	my $sth;
	my $sql;
	my @bind_values = ();
	my $fkt = $param->{fkt};

	my $db = $self->{db};
	my $dbh = $self->{dbh};

	$fkt = $self->_func_expand($fkt);

### cleanup functions
	$fkt = $db->cleanList($fkt) if (defined $fkt && $fkt ne '');

### check permissions
	my $fkt_allowed = "*";

if (1) {
	$sql = "SELECT GROUP_CONCAT(functions) FROM permission WHERE 1 = 1";
	$sql .= $db->bind_and("permission_key = ?", $param->{key}, \@bind_values);
	$sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);

	($fkt_allowed) = $sth->fetchrow_array();
	$sth->finish();

	$fkt_allowed = $self->_func_expand($fkt_allowed);
}
	$sql = "SELECT GROUP_CONCAT(id) FROM func_to_name AS func WHERE 1=1";
	$sql .= " AND ".$self->_sql_func($fkt) if ($fkt ne "");
	$sql .= " AND ".$self->_sql_func($fkt_allowed) if ($fkt_allowed ne "" && $fkt_allowed !~ /\*/);

	$sth = $self->{dbh}->prepare($sql);
	$sth->execute();
	my ($funcs) = $sth->fetchrow_array();
	$sth->finish();

	return $funcs;
}

sub db_get_signal
{
	my ($self, $q, $param) = @_;

	my $db = $self->{db};
	my $dbh = $self->{dbh};
	my $sth;
	my $sql;
	my @bind_values = ();

	my $func_ids = $self->db_get_func($param);
	$func_ids = "0" if ($func_ids eq "");

	if (exists $param->{oem_id}) {
		$param->{oem_id_layer} = 1;
 		if ($param->{oem_id} =~ /\./) {
			($param->{oem_id}, $param->{oem_id_layer}) = ($param->{oem_id} =~ /^([0-9]+).([0-9]+)/);
			$param->{oem_id_layer}++;
		}
	}
			
	$param->{oem_id} = $db->cleanListNum($param->{oem_id}) if (exists $param->{oem_id});

	### speed up selection if we have not specified any OEM ids
	my $sql_rc_oem_ids = "1=1";
	if (!exists $param->{model_id} && !exists $param->{model_name} && !exists $param->{brand_id} && !exists $param->{brand_name}) {
# only check for oem_id
		$sql_rc_oem_ids = " oem_to_signal.rc_oem_id =" . $param->{oem_id} if (exists $param->{oem_id});
		$sql_rc_oem_ids .= " AND oem_to_signal.type_layer =" . $param->{oem_id_layer} if (exists $param->{oem_id_layer});
	} else {
		my $rc_oem_ids = exists $param->{oem_id} ? $param->{oem_id} : $self->db_get_oem_ids($param);

		if ($rc_oem_ids eq "") {
			$db->print($q, 0, {remotes => {total => 0, num => 0}}, {-vary => "Accept"});
			return;
		}

		$sql_rc_oem_ids = " oem_to_signal.rc_oem_id IN ($rc_oem_ids)";
	}

	my $sql_rc_oem_num_weight = "";

	my $weight_select = "(SELECT COALESCE(SUM(weight), 0) FROM weight_oem WHERE weight_oem.rc_oem_id=oem_to_signal.rc_oem_id) AS weight";
	$sql_rc_oem_num_weight = "SELECT rc_oem_id, type_layer, 1 AS rc_oem_num, weight AS weight FROM (SELECT rc_oem_id, type_layer, $weight_select FROM oem_to_signal";
	$sql_rc_oem_num_weight .= " WHERE $sql_rc_oem_ids";
	if (defined $param->{type_id}) {
		$sql_rc_oem_num_weight .= $db->bind_and("type_id = ?", $db->cleanTypeId($param->{type_id}), \@bind_values);
		$sql_rc_oem_num_weight .= " GROUP BY rc_oem_id, type_layer) AS tbl1";
	} else {
		$sql_rc_oem_num_weight .= " GROUP BY rc_oem_id, type_id, type_layer) AS tbl1";
	}

	my $param_descr = ($db->checkAccessDebug($param)) ? ", descr AS description, prio AS priority" : "";

	$sql = "SELECT ";
	$sql .= "IF(oem_to_signal.type_layer=1, oem_to_signal.rc_oem_id, CONCAT(CAST(oem_to_signal.rc_oem_id AS CHAR), '.', CAST(oem_to_signal.type_layer-1 AS CHAR))) AS oem_id, ";
	$sql .= "tbl2.rc_oem_num AS oem_num, tbl2.weight AS weight, func.id AS id, func.name AS name, data AS content $param_descr FROM oem_to_signal";
        $sql .= " JOIN ($sql_rc_oem_num_weight) AS tbl2 ON oem_to_signal.rc_oem_id = tbl2.rc_oem_id AND oem_to_signal.type_layer = tbl2.type_layer";
	$sql .= " JOIN func_to_name AS func ON func_id = func.id";
	$sql .= " WHERE func_id IN ($func_ids)";
	$sql .= " AND prio = 1" if (defined $param->{nofallback});
	$sql .= $db->bind_and("prio = ?", $param->{priority}, \@bind_values) if (defined $param->{priority});
	$sql .= $db->bind_and("type_id = ?", $db->cleanTypeId($param->{type_id}), \@bind_values) if (defined $param->{type_id});
$sql .= " ORDER BY weight DESC, oem_num DESC, oem_id ASC, id DESC, prio DESC";

	$sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);

	$self->{sql} = $sql;
	return $sth;
}

sub get_signal
{
	my ($self, $q, $param) = @_;

	my $sth = $self->db_get_signal($q, $param);
	my $db = $self->{db};
	my $dbh = $self->{dbh};
	my $param_descr = ($db->checkAccessDebug($param)) ? ", descr AS description, prio AS priority" : "";
#	my $param_descr = $param->{debug} ? ", descr AS description, prio AS priority" : "";
#	my $param_descr = ", descr AS description, prio AS priority";

	my %items = ();
	my $decode = new RcSignalDecode();

#	$decode->{use_ms} = 1 if ($param->{use_ms});

	### decode description and create hash
	while(my $row = $sth->fetchrow_hashref()) {
		# add debug data
		if ($param->{debug} & 0x04) {
			$decode->decode_binary($row->{content});

			foreach my $key (sort keys $decode->{result}) {
				$row->{$key} = $decode->{result}->{$key};
			}
		}

#print $row->{oem_id} . "\t=\n";
		my $oem_id = $row->{oem_id};
		delete $row->{oem_id};

		$items{$oem_id}{num} = $row->{oem_num};
		$items{$oem_id}{weight} = $row->{weight};

		delete $row->{oem_num};
		delete $row->{weight};
#		delete $row->{name} unless ($param->{debug});	#FIMXE

		$items{$oem_id}{$row->{id}} = $row;
	}
	$sth->finish();

	### compression step 2
	%items = %{$self->do_compress(\%items, $param)} unless (defined $param->{compress} && $param->{compress} == 0);

	### find & merge default 
	if (defined $param->{merge} && defined $param->{brand_id} && $param->{brand_id} ne "") {
		my @bind_values = ();
		my $func_ids = $self->db_get_func($param);
		$func_ids = "0" if ($func_ids eq "");

		my $sql = "SELECT oem_to_signal.rc_oem_id AS oem_id, func_id AS id, func.name AS name, data AS content $param_descr FROM oem_to_signal";
		$sql .= " JOIN func_to_name AS func ON func_id = func.id";
		$sql .= " JOIN (";
		$sql .= "SELECT DISTINCT rc_oem_id FROM mv_union JOIN mv_union_to_oem ON mv_union.id = mv_union_to_oem.mv_union_id WHERE mv_union.name = 'default'";
		$sql .= $db->bind_and("mv_union.type_id = ?", $db->cleanTypeId($param->{type_id}), \@bind_values) if (defined $param->{type_id});
		$sql .= $db->bind_and("mv_union.brand_id = ?", $param->{brand_id}, \@bind_values);
		$sql .= "LIMIT 1) AS tbl2 ON oem_to_signal.rc_oem_id = tbl2.rc_oem_id";
		$sql .= " WHERE func_id IN ($func_ids)";
		$sql .= " AND prio = 1" if (defined $param->{nofallback});
$sql .= " ORDER BY weight DESC, oem_num DESC, id ASC, priority DESC";

		$sth = $dbh->prepare($sql);
		$sth->execute(@bind_values);

		my %item_default = ();
		while(my $row = $sth->fetchrow_hashref()) {
			delete $row->{oem_id};
			$item_default{$row->{id}} = $row;
		}
		$sth->finish();

		%items = %{$self->do_merge(\%items, \%item_default, $param)};
	}

	### filter remote controls not including required functions
	if ($param->{fkt_required}) {
		foreach my $key (split (',',$param->{fkt_required})) {
			foreach my $oem_id (keys %items) {
				my $found = 0;
				foreach my $fkt_id (keys $items{$oem_id}) {
					next unless ($self->isint($fkt_id));
					if ($items{$oem_id}{$fkt_id}{name} eq $key) {
						$found = 1;
						last;
					}
				}

				delete $items{$oem_id} if ($found != 1);
			}
		}
	}

	### create final datastructure for output in different formats
	$self->db_create_output($param, \%items);
}

sub _lcp {	# longest_common_prefix
	return '' unless @_;
	my $prefix = shift;
	for (@_) {
		chop $prefix while (! /^\Q$prefix\E/);
	}
	return $prefix;
}

sub db_create_output {
	my ($self, $param, $_items) = @_;

	my %items = %{$_items};
	my $items_arr = [];
	my $total = 0;
	my $num = 0;
	my $virtual_remote = [];


	foreach my $oem_id (sort { $items{$b}{weight} <=> $items{$a}{weight} or $items{$b}{num} <=> $items{$a}{num} or int($b) <=> int($a) or ($a-int($a)) <=> ($b-int($b))} keys %items) {
		$virtual_remote = [];

		foreach my $btn_id (sort { $a <=> $b } keys $items{$oem_id}) {
			next if !$self->isint($btn_id);

			if (defined $param->{debug} && $param->{debug} & 0x01) {
				delete $items{$oem_id}{$btn_id}{content};
			} else {
				$items{$oem_id}{$btn_id}{content} = join ",", unpack ('H2' x length($items{$oem_id}{$btn_id}{content}), $items{$oem_id}{$btn_id}{content});
			}
#			delete $items{$oem_id}{$btn_id}{name} unless ($param->{debug});

			push @$virtual_remote, $items{$oem_id}{$btn_id};
		}

		next if (exists $param->{weight} && $items{$oem_id}{weight} == 0);

		$num += $items{$oem_id}{num};
		if (exists $param->{debug} && $param->{debug} != 0) {
			my $num = $items{$oem_id}{num};
			my $weight = int($items{$oem_id}{weight});

			delete $items{$oem_id}{num};
			delete $items{$oem_id}{weight};

			push @$items_arr, {id => $oem_id, weight => $weight, num => $num, signal => $virtual_remote};
		} else {
			delete $items{$oem_id}{num};
			delete $items{$oem_id}{weight};
#			delete $items{$oem_id}{name};

			push @$items_arr, {id => $oem_id, signal => $virtual_remote};
		}

		$num += $items{$oem_id}{num};
		$total++;
	}

	$self->{num} = $num;
	$self->{total} = $total;
	$self->{remote} = $items_arr;
}

1;
