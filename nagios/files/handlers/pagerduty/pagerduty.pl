#!/usr/bin/env perl
# The MIT License (MIT)
# 
# Copyright (c) 2014 Jeff Walter
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

use warnings;
use strict;

use JSON;
use LWP::UserAgent;
use Getopt::Long qw/:config no_ignore_case bundling auto_abbrev/;

# =============================================================================

sub loadEnvironment {
	my (%env) = @_;
	my ($return, $key, @entry);

	$return = {};

	foreach $key (keys (%env)) {
		@entry = ($key);

		next unless ($entry [0] =~ /^NAGIOS_(\S+)$/i) || ($entry[0] =~ /^ICINGA_(\S+)$/i);

		$entry [1] = lc ($1);

		if ($entry [1] =~ /^(ADMIN|MAX|NOTIFICATION)(\S+)$/i) {
			$entry [1] = $1;
			$entry [2] = $2;

			if (! defined ($return->{$entry [1]})) {
				$return->{$entry [1]} = {};
			}
			$return->{$entry [1]}->{$entry [2]} = $env {$entry [0]};

		} elsif ($entry [1] =~ /^(ARG)(\d+)$/i) {
			$entry [1] = $1;
			$entry [2] = $2;

			if (! defined ($return->{$entry [1]})) {
				$return->{$entry [1]} = [];
			}
			$return->{$entry [1]}->[$entry [2] - 1] = $env {$entry [0]};

		} elsif ($entry [1] =~ /^(CONTACT)(\S+)$/i) {
			$entry [1] = $1;
			$entry [2] = $2;

			if (! defined ($return->{$entry [1]})) {
				$return->{$entry [1]} = {};
			}

			if ($entry [2] =~ /^(ADDRESS)(\d+)$/i) {
				$entry [2] = $1;
				$entry [3] = $2;

				if (! defined ($return->{$entry [1]}->{$entry [2]})) {
					$return->{$entry [1]}->{$entry [2]} = [];
				}
				$return->{$entry [1]}->{$entry [2]}->[$entry [3]] = $env {$entry [0]};

			} elsif ($entry [2] =~ /^(GROUP)(\S+)$/i) {
				$entry [2] = $1;
				$entry [3] = $2;

				if (! defined ($return->{$entry [1]}->{$entry [2]})) {
					$return->{$entry [1]}->{$entry [2]} = {};
				}
				$return->{$entry [1]}->{$entry [2]}->{$entry [3]} = $env {$entry [0]};

			} else {
				$return->{$entry [1]}->{$entry [2]} = $env {$entry [0]};
			}

		} elsif ($entry [1] =~ /^(HOST|SERVICE)(\S+)$/i) {
			$entry [1] = $1;
			$entry [2] = $2;

			if (! defined ($return->{$entry [1]})) {
				$return->{$entry [1]} = {};
			}

			if ($entry [2] =~ /^(ACK|GROUP|CHECK|NOTIFICATION)(\S+)$/i) {
				$entry [2] = $1;
				$entry [3] = $2;

				if (! defined ($return->{$entry [1]}->{$entry [2]})) {
					$return->{$entry [1]}->{$entry [2]} = {};
				}
				$return->{$entry [1]}->{$entry [2]}->{$entry [3]} = $env {$entry [0]};

			} else {
				$return->{$entry [1]}->{$entry [2]} = $env {$entry [0]};
			}

		} elsif ($entry [1] =~ /^(LAST)(\S+)$/i) {
			$entry [1] = $1;
			$entry [2] = $2;

			if (! defined ($return->{$entry [1]})) {
				$return->{$entry [1]} = {};
			}

			if ($entry [2] =~ /^(HOST|SERVICE)(\S+)$/i) {
				$entry [2] = $1;
				$entry [3] = $2;

				if (! defined ($return->{$entry [1]}->{$entry [2]})) {
					$return->{$entry [1]}->{$entry [2]} = {};
				}
				$return->{$entry [1]}->{$entry [2]}->{$entry [3]} = $env {$entry [0]};

			} else {
				$return->{$entry [1]}->{$entry [2]} = $env {$entry [0]};
			}

		} elsif ($entry [1] =~ /^(TOTAL)(\S+)$/i) {
			$entry [1] = $1;
			$entry [2] = $2;

			if (! defined ($return->{$entry [1]})) {
				$return->{$entry [1]} = {};
			}

			if ($entry [2] =~ /^(HOSTS|HOST|SERVICES|SERVICE)(\S+)$/i) {
				$entry [2] = $1;
				$entry [3] = $2;

				if (! defined ($return->{$entry [1]}->{$entry [2]})) {
					$return->{$entry [1]}->{$entry [2]} = {};
				}
				$return->{$entry [1]}->{$entry [2]}->{$entry [3]} = $env {$entry [0]};

			} else {
				$return->{$entry [1]}->{$entry [2]} = $env {$entry [0]};
			}

		} else {
			$return->{lc ($entry [1])} = $env {$entry [0]};
		}
	}

	$return->{'type'} = 'host';
	if ($return->{'last'} && $return->{'last'}->{'service'} && $return->{'last'}->{'service'}->{'check'}) {
		$return->{'type'} = 'service';
	}

	return ($return);
}

# =============================================================================

my (%OPTIONS);

%OPTIONS = (
	'api_url' => 'https://events.pagerduty.com/generic/2010-04-15/create_event.json',
);

GetOptions (
	'a|apiurl=s' => \$OPTIONS {'api_url'},
) || (
	exit (1)
);

# =============================================================================

my ($event, $nagios);

$nagios = loadEnvironment (%ENV);
$event = {
	'service_key' => $nagios->{'contact'}->{'pager'},
	'incident_key' => undef,
	'event_type' => undef,
	'description' => undef,
	'details' => $nagios,
};

if (! defined ($event->{'client_url'})) {
	delete ($event->{'client_url'});
}

## Make sure PagerDuty has the hostname to display on an incident from a Nagios-based service integration
$nagios->{'HOSTNAME'} = $nagios->{'host'}->{'name'};

if ($nagios->{'type'} eq 'host') {
	$event->{'incident_key'} = "event_source=host;host_name=" . $nagios->{'host'}->{'name'};
} elsif ($nagios->{'type'} eq 'service') {
	$event->{'incident_key'} = "event_source=service;host_name=" . $nagios->{'host'}->{'name'} . ";service_desc=" . $nagios->{'service'}->{'desc'};
	## Make sure PagerDuty has the service information to display on an incident from a Nagios-based service integration
	$nagios->{'SERVICEDESC'} = $nagios->{'service'}->{'desc'};
	$nagios->{'SERVICESTATE'} = $nagios->{'service'}->{'state'};
}

if (($nagios->{'notification'}->{'type'} eq 'PROBLEM') || ($nagios->{'notification'}->{'type'} eq 'RECOVERY')) {
	$event->{'event_type'} = ($nagios->{'notification'}->{'type'} eq 'PROBLEM' ? 'trigger' : 'resolve');

	if ($nagios->{'type'} eq 'host') {
		$event->{'description'} =
			$nagios->{'host'}->{'state'} .
			': ' .
			$nagios->{'host'}->{'name'} .
			' reports ' .
			$nagios->{'host'}->{'output'} .
			' (' .
			$nagios->{'host'}->{'check'}->{'command'} .
			')';

	} elsif ($nagios->{'type'} eq 'service') {
		$event->{'description'} =
			$nagios->{'service'}->{'state'} .
			': ' .
			($nagios->{'service'}->{'displayname'} ? $nagios->{'service'}->{'displayname'} : $nagios->{'service'}->{'desc'}) .
			' on ' .
			$nagios->{'host'}->{'name'} .
			' reports ' .
			$nagios->{'service'}->{'output'} .
			' (' .
			$nagios->{'service'}->{'check'}->{'command'} .
			')';
	}

} elsif ($nagios->{'notification'}->{'type'} eq 'ACKNOWLEDGEMENT') {
	$event->{'event_type'} = 'acknowledge';

	if ($nagios->{'type'} eq 'host') {
		$event->{'description'} =
			$nagios->{'host'}->{'state'} .
			' for ' .
			$nagios->{'host'}->{'name'} .
			' acknowledged by ' .
			$nagios->{'notification'}->{'author'} .
			' saying ' .
			$nagios->{'notification'}->{'comment'};

	} elsif ($nagios->{'type'} eq 'service') {
		$event->{'description'} =
			$nagios->{'service'}->{'state'} .
			' for ' .
			($nagios->{'service'}->{'displayname'} ? $nagios->{'service'}->{'displayname'} : $nagios->{'service'}->{'desc'}) .
			' on ' .
			$nagios->{'host'}->{'name'} .
			' acknowledged by ' .
			$nagios->{'notification'}->{'author'} .
			' saying ' .
			$nagios->{'notification'}->{'comment'};
	}

} else {
	exit (0);
}

# =============================================================================

my ($time, $host, $service) = @_;
my ($useragent, $response);

$useragent = LWP::UserAgent->new ();
$response = $useragent->post (
	$OPTIONS {'api_url'},
	'Content_Type' => 'application/json',
	'Content' => JSON->new ()->utf8 ()->encode ($event)
);

if (! $response->is_success ()) {
	exit (1);
}

exit (0);
