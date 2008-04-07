# (C) 2005 The Honeynet Project.  All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
#
#----- Authors: Scott Buchan <sbuchan@hush.com>

package Walleye::Pager;

require Exporter;
our @ISA=("Exporter");

use diagnostics;
use strict;

use Template;
use Time::Local;
use Date::Format;

use POSIX qw(ceil floor);

use Walleye::AdminUtils;

sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);

	$self->init_vars();

	return $self;
}

sub init_vars {
	my $self = shift;

	# Initialize vars
	$self->{query} = "";
	$self->{query_params} = "";
	$self->{disp_rec} = 10;
	$self->{total_rec} = 1;
	$self->{curr_page} = 1;
	$self->{prev_page} = 1;
	$self->{next_page} = 1;
	$self->{start_rec} = 1;
	$self->{end_rec} = 1;
	$self->{total_page} = 1;

}
sub get_pager_vars {
	my $self = shift;
	my %var;

	$var{"query"} = $self->{query};
	$var{"query_params"} = $self->{query_params};
	$var{"disp_rec"} = $self->{disp_rec};
	$var{"total_rec"} = $self->{total_rec};
	$var{"curr_page"} = $self->{curr_page};
	$var{"prev_page"} = $self->{prev_page};
	$var{"next_page"} = $self->{next_page};
	$var{"start_rec"} = $self->{start_rec};
	$var{"end_rec"} = $self->{end_rec};
	$var{"total_page"} = $self->{total_page};

	return %var;

}

sub set_query {
	my $self = shift;
	$self->{query} = shift;
}

sub set_query_params {
	my $self = shift;
	$self->{query_params} = shift;
}


sub set_disp_rec {
	my $self = shift;
	$self->{disp_rec} = shift;
}

sub get_results {
	my $self = shift;
	my $query = "$self->{query} $self->{query_params}";
	my $limit; 
	my $count_query = $query;
	my @row;
	my @list;

	$count_query =~ s/^select\s*.+?\s*from/select count(*) from /i;

	
	ConnectToDatabase();
	SendSQL($count_query);

	@row = FetchSQLData();
	$self->{total_rec} = $row[0];

	$self->calc_start_rec();
	$self->calc_end_rec();
	$self->get_total_pages();

	if($self->{curr_page} < $self->{total_page}) {
		$self->set_next_page($self->{curr_page} + 1);
	} else {
		$self->set_next_page($self->{curr_page});
	}
	
	if($self->{disp_rec} != 0) {
		my $start_limit = $self->{start_rec} - 1;
		$limit = " limit $start_limit,$self->{disp_rec}";
		$query .= $limit;
	}

	SendSQL($query);

	while(MoreSQLData()) {
		@row = FetchSQLData();
		push @list, [@row];
	}

	return \@list;	
}

sub get_total_pages {
	my $self = shift;

	if($self->{disp_rec} == 0) {
		$self->{total_page} = 1;
	} else {
		$self->{total_page} = ceil($self->{total_rec} / $self->{disp_rec});
	}
}

sub set_start_rec {
	my $self = shift;
	my $record = shift;
	
	$self->{start_rec} = $record;
}

sub calc_start_rec {
	my $self = shift;
	
	if($self->{curr_page} == 1) {
		$self->{start_rec} = 1;
	} else {
		$self->{start_rec} = ($self->{curr_page} * $self->{disp_rec}) - ($self->{disp_rec} - 1);
	}
}

sub calc_end_rec {
	my $self = shift;
	my $end_rec;
	
	$end_rec = $self->{start_rec} + ($self->{disp_rec} - 1);

	if($end_rec > $self->{total_rec} || $self->{disp_rec} == 0) {
		$end_rec = $self->{total_rec};
	}

	$self->{end_rec} = $end_rec;
}

sub set_page_direction {
	my $self = shift;
	my $dir = shift;
	my $prev = $self->{prev_page};
	my $next = $self->{next_page};
	my $curr = $self->{curr_page};
	
	if($dir eq "prev") {
		$self->{curr_page} = $prev;
		$self->{next_page} = $curr;
		$self->{prev_page} = $prev - 1 unless ($prev == 1);
	} else {
		$self->{curr_page} = $next;
		$self->{prev_page} = $curr;
		$self->{next_page} = $next + 1 unless ($next == $self->{total_page});
	}
}

sub set_curr_page {
	my $self = shift;
	$self->{curr_page} = shift;
}

sub set_prev_page {
	my $self = shift;
	$self->{prev_page} = shift;
}

sub set_next_page {
	my $self = shift;
	$self->{next_page} = shift;
}

sub set_total_rec {
	my $self = shift;
	$self->{total_rec} = shift;
}

