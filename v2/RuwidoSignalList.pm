#!/usr/bin/perl

# debug=1	DISABLE CONTENT
# debug=2	descr
# debug=4	decoding
# debug=8	from_id

package RuwidoSignalList;

use strict;
use warnings;
use utf8;

use CGI;
use DBI;
use DataBase;
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

sub find_match_part
{
	my ($self, $rcu, $rcus_ref, $param) = @_;

	foreach my $rcu_cmp (sort { $b <=> $a } keys %{$rcus_ref}) {
		next if $rcu eq $rcu_cmp;

		my $found = 0;
		foreach my $fkt (keys %{$rcus_ref->{$rcu}{fkts}}) {
			next if (!exists $rcus_ref->{$rcu}{fkts}{$fkt} || !exists $rcus_ref->{$rcu_cmp}{fkts}{$fkt});	# button does exist in only one

			if ($rcus_ref->{$rcu}{fkts}{$fkt}{content} eq $rcus_ref->{$rcu_cmp}{fkts}{$fkt}{content}) {
				$found = 1;
			} else {
				next if ($param->{compress} > 1 && !$rcus_ref->{$rcu_cmp}{fkts}{$fkt}{is_fallback});	# ignore fallbacks
			
				$found = 0;
				last;
			}
		}

		return $rcu_cmp if ($found != 0);
	}

	return 0;
}

sub do_compress
{
	my ($self, $rcus, $param) = @_;

	foreach my $rcu (sort { $b <=> $a } keys %{$rcus}) {
		# find if the overlapping parts match
		my $rcu_cmp = $self->find_match_part($rcu, $rcus, $param);

		if ($rcu_cmp) {
			# copy all keys
			foreach my $fkt (keys %{$rcus->{$rcu}{fkts}}) {
				next if (exists $rcus->{$rcu_cmp}{fkts}{$fkt});	# button is already in both entries
#				next if (exists $rcus->{$rcu}{fkts}{$fkt} && exists $rcus->{$rcu_cmp}{fkts}{$fkt}); # button is already in both entries

				if (!exists $rcus->{$rcu_cmp}{fkts}{$fkt}) {
					$rcus->{$rcu_cmp}{fkts}{$fkt} = $rcus->{$rcu}{fkts}{$fkt};
				} elsif (exists $rcus->{$rcu}{fkts}{$fkt} && !$rcus->{$rcu}{fkts}{$fkt}{is_fallback}) {
					$rcus->{$rcu_cmp}{fkts}{$fkt} = $rcus->{$rcu}{fkts}{$fkt};
				}

#				$rcus->{$rcu_cmp}{fkts}{$fkt} = $rcus->{$rcu}{fkts}{$fkt};
			}

			$rcus->{$rcu_cmp}{rcu_num} += $rcus->{$rcu}{rcu_num};
			$rcus->{$rcu_cmp}{rcu_ids} .= "," . $rcus->{$rcu}{rcu_ids};

			$rcus->{$rcu_cmp}{model_num} += $rcus->{$rcu}{model_num};
			$rcus->{$rcu_cmp}{weight} += $rcus->{$rcu}{weight};

			$rcus->{$rcu_cmp}{date} = $rcus->{$rcu}{date} if ($rcus->{$rcu}{date} gt $rcus->{$rcu_cmp}{date});

			delete $rcus->{$rcu};
		}
	}

	return $rcus;
}

sub get_signal
{
	my ($self, $q, $param) = @_;

	my $db = $self->{db};
	my $dbh = $self->{dbh};
#	my $param_descr = ($db->{__debug}) ? ", descr AS description" : "";
	my @bind_values = ();

	my $sql = "";

	if ($self->{db}->{__debug}) {
		$sql .= "SELECT MIN(global_code.id) AS rcu_id, function_id AS id, function.name AS fkt_name, is_fallback, descr, data AS content, SUM(weight) as weight, COUNT(*) AS model_num, MAX(date) AS date  FROM crossref ";
		$sql .= "JOIN crossref_to_global_code ON crossref.id = crossref_id ";
		$sql .= "JOIN global_code ON global_code.id = crossref_to_global_code.global_code_id ";
		$sql .= "JOIN function ON function.id = global_code.function_id ";
		$sql .= $db->bind("LEFT JOIN weight_global_code ON (weight_global_code.global_code_id = global_code.id AND weight_global_code.permission_key = ?)", $param->{key}, \@bind_values);
		$sql .= "WHERE 1=1";
	} else {
		$sql .= "SELECT MIN(global_code.id) AS rcu_id, function_id AS id, is_fallback, descr, data AS content, SUM(weight) as weight, COUNT(*) AS model_num, MAX(date) AS date  FROM crossref ";
		$sql .= "JOIN crossref_to_global_code ON crossref.id = crossref_id ";
		$sql .= "JOIN global_code ON global_code.id = crossref_to_global_code.global_code_id ";
		$sql .= $db->bind("LEFT JOIN weight_global_code ON (weight_global_code.global_code_id = global_code.id AND weight_global_code.permission_key = ?)", $param->{key}, \@bind_values);
		$sql .= "WHERE 1=1";
	}

#	$sql .= $db->bind("AND crossref.source <> ?", 'model_series', \@bind_values);
#	$sql .= $db->bind("AND crossref.source = ?", 'model_name', \@bind_values);

	$sql .= $db->bind("AND crossref.name_search REGEXP ?", $param->{model_name}, \@bind_values) if ($param->{model_name});
	$sql .= $db->bind("AND crossref.type_set & ?", $db->{__types}, \@bind_values);
	$sql .= $db->bind("AND crossref.date >= DATE_SUB(CURDATE(), INTERVAL ? YEAR)", $param->{age}, \@bind_values) if ($param->{age});

	$sql .= $db->bind("AND crossref.brand_id = ?", $param->{brand_id}, \@bind_values) if ($param->{brand_id});
	$sql .= $db->bind("AND crossref.brand_id IN (SELECT id FROM brand WHERE name_search REGEXP ?)", $param->{brand_name}, \@bind_values) if ($param->{brand_name});

	$sql .= $db->bind("AND 1<<(crossref_to_global_code.type_id-1) & ?", $db->{__types},  \@bind_values) if ($db->{__types});
#	$sql .= $db->bind("AND BIT_AND(POW(2, crossref_to_global_code.type_id-1), ?)", $db->{__types},  \@bind_values) if ($db->{__types});

	$sql .= $db->bind("AND global_code.id = ?", $param->{oem_id}, \@bind_values) if ($param->{oem_id});
	$sql .= "AND global_code.function_id IN (" . $db->{__fkt} . ") ";
	$sql .= "GROUP BY global_code.id, global_code.function_id ";
	$sql .= "ORDER BY weight DESC, model_num DESC, date DESC";

	my $sth = $dbh->prepare($sql);
	$sth->execute(@bind_values);
	$self->{sql} = $sql;

	my %rcus = ();

	### decode description and create hash
	while (my $row = $sth->fetchrow_hashref()) {
		$row->{weight} = 0 if (!defined $row->{weight});

		$rcus{$row->{rcu_id}}{rcu_num} = 1;
		$rcus{$row->{rcu_id}}{rcu_ids} = $row->{rcu_id};

		$rcus{$row->{rcu_id}}{model_num} = $row->{model_num};
		$rcus{$row->{rcu_id}}{weight} = $row->{weight};
		$rcus{$row->{rcu_id}}{date} = $row->{date};
		$rcus{$row->{rcu_id}}{fkts}{$row->{id}} = $row;

		if ($self->{db}->{__debug}) {
			$rcus{$row->{rcu_id}}{fkt_name} = $row->{fkt_name};
		}

		delete $row->{weight};
		delete $row->{model_num};
		delete $row->{date};
		delete $row->{rcu_id};
#		delete $row->{id};
	}
	$sth->finish();

	### compression
	%rcus = %{$self->do_compress(\%rcus, $param)} if ($param->{compress} > 0);

	### create final datastructure for output in different formats
	$self->db_create_output($param, \%rcus);

	### perform LIMIT() operation
	if (defined $self->{remote}) {
		splice(@{$self->{remote}}, 0, $param->{limit_min});
		splice(@{$self->{remote}}, $param->{limit_len}) if (defined $param->{limit_len});
	}
}

sub db_create_output {
	my ($self, $param, $_rcus) = @_;

	my %rcus = %{$_rcus};
	my $virtual_remotes = [];
	my $total = 0;
	my $num = 0;
	my $virtual_remote = [];

	foreach my $rcu_id (sort { $rcus{$b}{weight} <=> $rcus{$a}{weight} or $rcus{$b}{model_num} <=> $rcus{$a}{model_num} or $rcus{$b}{date} cmp $rcus{$a}{date}} keys %rcus) {
		$virtual_remote = [];

		foreach my $fkt (sort { $a <=> $b } keys %{$rcus{$rcu_id}{fkts}}) {
			$rcus{$rcu_id}{fkts}{$fkt}{content} = join ",", unpack ('H2' x length($rcus{$rcu_id}{fkts}{$fkt}{content}), $rcus{$rcu_id}{fkts}{$fkt}{content});

			if ($self->{db}->{__debug} & 0x04) {
				delete $rcus{$rcu_id}{fkts}{$fkt}{content};
			}
			if ($self->{db}->{__debug}) {
#				delete $rcus{$rcu_id}{fkts}{$fkt}{content};
#				delete $rcus{$rcu_id}{fkts}{$fkt}{is_fallback} if ($rcus{$rcu_id}{fkts}{$fkt}{is_fallback} == 0);
			} else {
				delete $rcus{$rcu_id}{fkts}{$fkt}{is_fallback};
			}

			push @$virtual_remote, $rcus{$rcu_id}{fkts}{$fkt};
		}

#		next if (exists $param->{weight} && $rcus{$rcu_id}{weight} == 0);
#		push @$virtual_remotes, {id => $rcu_id, signal => $virtual_remote};

		if ($self->{db}->{__debug}) {
			push @$virtual_remotes, {id => $rcu_id, rcu_ids => $rcus{$rcu_id}{rcu_ids}, weight => $rcus{$rcu_id}{weight}, date => $rcus{$rcu_id}{date}, model_num => $rcus{$rcu_id}{model_num}, rcu_num => $rcus{$rcu_id}{rcu_num}, signal => $virtual_remote};
		} else {
			push @$virtual_remotes, {id => $rcu_id, signal => $virtual_remote};
		}

		$num += $rcus{$rcu_id}{rcu_num};
		$total++;
	}

	$self->{num} = $num;
	$self->{total} = $total;
	$self->{remote} = $virtual_remotes;
}

1;
