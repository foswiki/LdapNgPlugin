# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2015 Michael Daum http://michaeldaumconsulting.com
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
use warnings;

our $core;
our $VERSION = '6.10';
our $RELEASE = '31 Aug 2015';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Query and display data from an LDAP directory';

###############################################################################
sub initPlugin { 

  Foswiki::Func::registerTagHandler('LDAP', sub {
    return getCore(shift)->handleLdap(@_);
  });

  Foswiki::Func::registerTagHandler('LDAPUSERS', sub {
    return getCore(shift)->handleLdapUsers(@_);
  });

  Foswiki::Func::registerTagHandler('EMAIL2WIKINAME', sub {
    return getCore(shift)->handleEmailToWikiName(@_);
  });

  if ($Foswiki::cfg{Plugins}{SolrPlugin}{Enabled}) {
    require Foswiki::Plugins::SolrPlugin;
    Foswiki::Plugins::SolrPlugin::registerIndexTopicHandler(\&indexTopicHandler);
  }

  $core = undef;

  push @{$Foswiki::cfg{AccessibleCFG}},
    '{Ldap}{UserBase}',
    '{Ldap}{GroupBase}',
    '{Ldap}{LoginAttribute}',
    '{Ldap}{GroupAttribute}',
    '{Ldap}{WikiNameAttribute}',
    '{Ldap}{PersonDataForm}';

  return 1; 
}

###############################################################################
sub indexTopicHandler {
  my $session = $Foswiki::Plugins::SESSION;
  return getCore($session)->indexTopicHandler(@_);
}

###############################################################################
sub finishPlugin {
  if (defined $core) {
    $core->finish;
    $core = undef;
  }
}

###############################################################################
sub getCore {

  unless (defined $core) {
    require Foswiki::Plugins::LdapNgPlugin::Core;
    $core = Foswiki::Plugins::LdapNgPlugin::Core->new(@_);
  }

  return $core;
}

1;
