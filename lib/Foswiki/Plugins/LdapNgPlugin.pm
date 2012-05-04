# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2011 Michael Daum http://michaeldaumconsulting.com
# Portions Copyright (C) 2006 Spanlink Communications
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Foswiki::Plugins::LdapNgPlugin;

use strict;
use vars qw($VERSION $RELEASE $core $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION);

$VERSION           = '$Rev: 20110106 (2011-01-06) $';
$RELEASE           = '4.00';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION  = 'Query and display data from an LDAP directory';

###############################################################################
sub initPlugin {

    Foswiki::Func::registerTagHandler(
        'LDAP',
        sub {
            return getCore(shift)->handleLdap(@_);
        }
    );

    Foswiki::Func::registerTagHandler(
        'LDAPUSERS',
        sub {
            return getCore(shift)->handleLdapUsers(@_);
        }
    );

    Foswiki::Func::registerTagHandler(
        'EMAIL2WIKINAME',
        sub {
            return getCore(shift)->handleEmailToWikiName(@_);
        }
    );

    $core = undef;

    return 1;
}

###############################################################################
sub getCore {

    unless ( defined $core ) {
        require Foswiki::Plugins::LdapNgPlugin::Core;
        $core = Foswiki::Plugins::LdapNgPlugin::Core->new(@_);
    }

    return $core;
}

1;
