kre#!/usr/bin/perl

use CGI;
use DBI;
use MIME::Base64;
use Data::Dumper;
use String::CRC32;

use DataBase;
use RuwidoSignalList;

use RcSignal2Pronto;
use RcSignal2GlobalCache;
use RcSignal2Lirc;
use RcSignalDecode;

my $q = CGI->new;
my %param = $q->Vars;

my $db = new DataBase();
my $dbh = $db->connect();

my $signalList = new RuwidoSignalList($db, $dbh);

$db->cleanupParam(\%param);
if ($param{limit}) {
	my $limit = $param{limit};      #db->cleanLimit($param{limit});

	$limit =~ s/[^0-9,]//g;
	if ($limit =~ /,/) {
		($param{limit_min}, $param{limit_len}) = split(/,/, $limit);
	} else {
		$param{limit_len} = $limit;
	}
}


if ($db->{__permission}) {
	if ($param{output} eq "base64_blob") {
		$db->{__debug} = 3;
		$signalList->get_signal($q, \%param);
		output_to_base64();
	} elsif ($param{output} eq "pronto") {
		$db->{__debug} = 3;
		$signalList->get_signal($q, \%param);
		output_to_pronto();
	} elsif ($param{output} eq "globalcache") {
		$db->{__debug} = 3;
		$signalList->get_signal($q, \%param);
		output_to_globalcache();
	} elsif ($param{output} eq "lirc") {
		$db->{__debug} = 3;
		$signalList->get_signal($q, \%param);
		output_to_lirc();
	} else {
		$signalList->get_signal($q, \%param);
	}

	my $sth = $dbh->prepare("SELECT value from meta where name='last_update';");
	$sth->execute();
	my $row = $sth->fetchrow_hashref();

	$db->print($q, $signalList->{total}, {remotes => {last_update => $row->{value}, total => $signalList->{total}, num => $signalList->{num}, remote => $signalList->{remote}}}, {-vary => "Accept",
		-access_control_allow_origin => '*',
		-access_control_allow_headers => 'content-type,X-Requested-With',
		-access_control_allow_methods => 'GET,POST,OPTIONS',
		-access_control_allow_credentials => 'true'
	});

#print (Dumper \%param);

} else {
	$db->print_error($q, 401, "Unauthorized");
}

$db->disconnect();
exit 0;

sub output_to_base64
{
	my $txt = "";
	my $id = 0;

	return if (!defined $signalList->{remote});

	foreach my $remote (@{$signalList->{remote}}) {
		$txt .= pack("C", 0x01);	# version
		$txt .= pack("C", scalar @{$remote->{signal}});	# number of entries

		foreach my $signal (@{$remote->{signal}}) {
			my @arr = split (/,/, $signal->{content});
			my $fkt = pack("S", $signal->{id});
			my $len_sig = pack("C", scalar @arr);
			my $sig = pack("H*", join "", @arr);

			if ($param{key} eq "4f5f6683e2ed" ||    #hotwire
			    $param{key} eq "b16e7704eafc"       #telus hostpitality
			) {
				if ($param{type_id} == 9) {
					$fkt |= 1 << 12;
				}
			}
			elsif (defined $param{type_id} && $param{output} eq "base64_blob_layer") {
				$fkt |= ($param{type_id} & 0x1f) << 11;
			}

			$txt .= $fkt . $len_sig . $sig;
		}

		delete $signalList->{remote}[$id];
		$txt .= pack("L", crc32($txt));
		$txt = encode_base64($txt);
		$txt =~ s/[\r\n ]+//g;
		$signalList->{remote}[$id]->{base64}->{content} = $txt;
		$txt = "";

		$id++;
	}
}

sub output_to_pronto
{
	my $txt = "";

	my $decode = new RcSignalDecode();
	my $pronto = new RcSignal2Pronto();
	my $id = 0;

	return if (!defined $signalList->{remote});

	foreach my $remote (@{$signalList->{remote}}) {
		foreach my $signal (@{$remote->{signal}}) {
			$decode->decode_hex_with_comma($signal->{content});
			$signal->{content} = $pronto->convert($decode->{result}, $signal->{description});

			delete $signal->{descr};
			delete $signal->{is_fallback};
			$id++;
		}
	}
}

sub output_to_globalcache
{
	my $txt = "";

	my $decode = new RcSignalDecode();
	my $globalcache = new RcSignal2GlobalCache();
	my $id = 0;

	return if (!defined $signalList->{remote});

	foreach my $remote (@{$signalList->{remote}}) {
		foreach my $signal (@{$remote->{signal}}) {
			$decode->decode_hex_with_comma($signal->{content});
			$decode->{result}->{id} = $signal->{id};
			$signal->{content} = $globalcache->convert($decode->{result}, $signal->{description});

			delete $signal->{descr};
			delete $signal->{is_fallback};
			$id++;
		}
	}
}

sub output_to_lirc
{
	my $txt = "";

	my $decode = new RcSignalDecode();
	my $lirc = new RcSignal2Lirc();

print Dumper($signalList);
#print Dumper($signalList->{remote});

	return if (!defined $signalList->{remote});

	foreach my $remote ($signalList->{remote}) {
print Dumper($remote);
#		foreach my $foo (keys $remote->{signal}) {
#print Dumper($foo);
#		foreach my $foo (keys $signalList->{remote}[$id]->{signal}) {
#print Dumper($signalList->{remote});
#			$decode->decode_hex_with_comma($signalList->{remote}[$id]->{signal}[$foo]->{content});
#			$decode->{result}->{id} = $signalList->{remote}[$id]->{signal}[$foo]->{id};

#print Dumper($foo);
#			$signalList->{remote}[$id]->{signal}[$foo]->{content} = $lirc->convert($decode->{result}, $signalList->{remote}[$id]->{signal}[$foo]->{description});
#		}
	}
}
