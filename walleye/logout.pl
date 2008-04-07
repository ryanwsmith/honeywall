#!/usr/bin/perl -w

use strict;
use warnings;
use Template;

use DBI;
use DBD::mysql;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard fatalsToBrowser);

use Walleye::Login;

Walleye::Login::remove_session();
Walleye::Login::display_login_page();
