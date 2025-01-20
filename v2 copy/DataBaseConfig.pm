#!/usr/bin/perl -w

package DataBaseConfig;

$CFG = {
	db		=> "DBI:mysql:ruwido_rc;host=10.11.101.41",
	db_user		=> "toast",
	db_pass		=> "geheim",
	dbh		=> undef,
	_default_limit	=> 50,
	_default_type_id=> 1,
};

1;
