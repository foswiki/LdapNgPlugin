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

package Foswiki::Plugins::LdapNgPlugin::Core;

use strict;
use warnings;

use Foswiki::Contrib::LdapContrib ();
use Digest::MD5 ();
use Cache::FileCache();
use Encode ();

use constant TRACE => 0;    # toggle me

###############################################################################
sub new {
  my ($class, $session) = @_;

  my $this = bless({ session => $session }, $class);

  $this->{cache} = new Cache::FileCache(
    {
      'namespace' => 'LdapNgPlugin',
      'cache_root' => Foswiki::Func::getWorkArea('LdapNgPlugin') . '/cache/',
      'cache_depth' => 3,
      'directory_umask' => 077,
    }
  );

  return $this;
}

###############################################################################
sub finish {
  my $this = shift;

  $this->{cache} = undef;
}

###############################################################################
sub writeDebug {

  # comment me in/out
  #Foswiki::Func::writeDebug('- LdapNgPlugin - '.$_[0]) if TRACE;
  print STDERR 'LdapNgPlugin - ' . $_[0] . "\n" if TRACE;
}

###############################################################################
sub handleLdap {
  my ($this, $params, $topic, $web) = @_;

  #writeDebug("called handleLdap($web, $topic)");
  my $fingerPrint = $params->stringify;
  $fingerPrint = Digest::MD5::md5_hex($fingerPrint);

  my $query = Foswiki::Func::getCgiQuery();
  my $theRefresh = $query->param('refresh') || '';
  $theRefresh = 1 if $theRefresh =~ /^(on|ldap)$/;

  my $theCache = $params->{cache};
  $theCache = $Foswiki::cfg{Ldap}{DefaultCacheExpire} unless defined $theCache;

  if ($theCache && !$theRefresh) {
    my $data = $this->{cache}->get($fingerPrint);
    if ($data) {
      writeDebug("found response in cache");
      return $data;
    }
  }

  # get args

  my $theFilter = $params->{'filter'} || $params->{_DEFAULT} || '';
  my $theBase = $params->{'base'} || $Foswiki::cfg{Ldap}{Base} || '';
  my $theHost = $params->{'host'} || $Foswiki::cfg{Ldap}{Host} || 'localhost';
  my $thePort = $params->{'port'} || $Foswiki::cfg{Ldap}{Port} || '389';
  my $theVersion = $params->{version} || $Foswiki::cfg{Ldap}{Version} || 3;
  my $theSSL = $params->{ssl} || $Foswiki::cfg{Ldap}{SSL} || 0;
  my $theScope = $params->{scope} || 'sub';
  my $theFormat = $params->{format} || '$dn';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSort = $params->{sort} || '';
  my $theReverse = Foswiki::Func::isTrue($params->{reverse}, 0);
  my $theLimit = $params->{limit} || 0;
  my $theSkip = $params->{skip} || 0;
  my $theHideNull = Foswiki::Func::isTrue($params->{hidenull}, 0);
  my $theClear = $params->{clear} || '';
  my $theExclude = $params->{exclude} || '';
  my $theInclude = $params->{include} || '';
  my $theCasesensitive = Foswiki::Func::isTrue($params->{casesensitive}, 1);
  my $theBlobAttrs = $params->{blob} || '';

  my %blobAttrs = map {$_ => 1} split(/\s*,\s*/, $theBlobAttrs);

  # backwards compatibility. note that you won't be able to have a jpegPhoto attribute
  # in your ldap that is _not_ to be handled as a blob 
  $blobAttrs{jpegPhoto} = 1; 

  my $theSep = $params->{separator};
  $theSep = $params->{sep} unless defined $theSep;
  $theSep = '$n' unless defined $theSep;


  # fix args
  $theSkip =~ s/[^\d]//go;
  $theLimit =~ s/[^\d]//go;
  my @theSort = split(/[\s,]+/, $theSort);
  $theBase = $1 . ',' . $Foswiki::cfg{Ldap}{Base} if $theBase =~ /^\((.*)\)$/;

  writeDebug("base=$theBase");
  writeDebug("filter=$theFilter");
  #writeDebug("format=$theFormat");

  # new connection
  my $ldap = new Foswiki::Contrib::LdapContrib(
    $this->{session},
    base => $theBase,
    host => $theHost,
    port => $thePort,
    version => $theVersion,
    ssl => $theSSL,
  );

  # search
  my @entries = ();
  my $search = $ldap->search(
    filter => $theFilter,
    base => $theBase,
    scope => $theScope,
    sizelimit => $theReverse ? 0 : $theLimit,
    callback => sub {
      push @entries, $_[1];
    }
  );
  unless (defined $search) {
    return inlineError('ERROR: ' . $ldap->getError());
  }

  # DISABLED: as it destroys the @entries array colleced while following references etc
  # TODO: use our own sorting or borrow from Net::LDAP::Search
  #@entries = $search->sorted(@theSort); 

  @entries = reverse @entries if $theReverse;
  my $index = 0;
  my @results = ();
  foreach my $entry (@entries) {
    my $dn = $entry->dn();
    if ($theCasesensitive) {
      next if $theExclude && $dn =~ /$theExclude/;
      next if $theInclude && $dn !~ /$theInclude/;
    } else {
      next if $theExclude && $dn =~ /$theExclude/i;
      next if $theInclude && $dn !~ /$theInclude/i;
    }

    $index++;
    next if $index <= $theSkip;

    my %data;
    $data{dn} = $dn;
    $data{index} = $index;
    foreach my $attr ($entry->attributes()) {
      if ($blobAttrs{$attr}) { 
        $data{$attr} = $ldap->cacheBlob($entry, $attr, $theRefresh);
      } else {
        $data{$attr} = $ldap->fromLdapCharSet($entry->get_value($attr));
      }
    }
    push @results, expandVars($theFormat, %data);
    last if $index == $theLimit;
  }
  $ldap->finish();

  my $count = scalar(@results);
  return '' if $theHideNull && !$count;

  my $result = expandVars($theHeader . join($theSep, @results) . $theFooter, count => $count);

  #writeDebug("result=$result");

  if ($theClear) {
    $theClear =~ s/\$/\\\$/g;
    my $regex = join('|', split(/[\s,]+/, $theClear));
    $result =~ s/$regex//g;
  }

  $result = decodeFormatTokens($result);

  if ($theCache) {
    $this->{cache}->set($fingerPrint, $result, $theCache);
  }

  writeDebug("done handleLdap()");
  return $result;
}

###############################################################################
sub handleLdapUsers {
  my ($this, $params, $topic, $web) = @_;

  #writeDebug("called handleLdapUsers($web, $topic)");

  my $ldap = Foswiki::Contrib::LdapContrib::getLdapContrib($this->{session});
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theLimit = $params->{limit} || 0;
  my $theSkip = $params->{skip} || 0;
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theCasesensitive = Foswiki::Func::isTrue($params->{casesensitive}, 1);
  my $theHideUnknownUsers = Foswiki::Func::isTrue($params->{hideunknown}, 1);

  my $theFormat = $params->{format};
  $theFormat = '   1 $displayName' unless defined $theFormat;

  my $theSep = $params->{separator};
  $theSep = $params->{sep} unless defined $theSep;
  $theSep = '$n' unless defined $theSep;

  my $usersWeb = $Foswiki::cfg{UsersWebName};
  my $wikiNames = $ldap->getAllWikiNames();
  $theSkip =~ s/[^\d]//go;
  $theLimit =~ s/[^\d]//go;

  my $index = 0;
  my @result = ();
  foreach my $wikiName (sort @$wikiNames) {
    if ($theCasesensitive) {
      next if $theExclude && $wikiName =~ /$theExclude/;
      next if $theInclude && $wikiName !~ /$theInclude/;
    } else {
      next if $theExclude && $wikiName =~ /$theExclude/i;
      next if $theInclude && $wikiName !~ /$theInclude/i;
    }
    my $loginName = $ldap->getLoginOfWikiName($wikiName);
    my $emailAddrs = $ldap->getEmails($loginName);
    my $distinguishedName = $ldap->getDnOfLogin($loginName) || '';
    my $displayName;

    if (Foswiki::Func::topicExists($usersWeb, $wikiName)) {
      $displayName = "[[$usersWeb.$wikiName]]";
    } else {
      next if $theHideUnknownUsers;
      $displayName = "<nop>$wikiName";
    }
    $index++;
    next if $index <= $theSkip;
    push @result, expandVars(
      $theFormat,
      index => $index,
      wikiName => $wikiName,
      displayName => $displayName,
      dn => $distinguishedName,
      loginName => $loginName,
      emails => $emailAddrs
    );
    last if $index == $theLimit;
  }

  my $result = $theHeader. join($theSep, @result) . $theFooter;
  $result = expandVars($result, count => scalar(@result));

  return decodeFormatTokens($result);
}

###############################################################################
sub handleEmailToWikiName {
  my ($this, $params, $topic, $web) = @_;

  my $theFormat = $params->{format} || '$wikiname';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator};
  my $theEmail = $params->{_DEFAULT} || $params->{email} || '';

  $theSep = ', ' unless defined $theSep;

  my @wikiNames = Foswiki::Func::emailToWikiNames($theEmail, 1);
  my $usersWeb = $Foswiki::cfg{UsersWebName};
  my @result = ();
  my $count = scalar(@wikiNames);
  my $index = 0;
  foreach my $wikiName (sort @wikiNames) {
    $index++;
    my $line = $theFormat;
    my $wikiUserName = $usersWeb . '.' . $wikiName;
    $line =~ s/\$wikiname/$wikiName/g;
    $line =~ s/\$wikiusername/$wikiUserName/g;
    $line =~ s/\$index/$index/g;
    $line =~ s/\$count/$count/g;
    push @result, $line;
  }
  return '' unless @result;

  $theHeader =~ s/\$count/$count/g;
  $theFooter =~ s/\$count/$count/g;

  return $theHeader . join($theSep, @result) . $theFooter;
}

###############################################################################
sub inlineError {
  return "<div class=\"foswikiAlert\">$_[0]</div>";
}

###############################################################################
sub decodeFormatTokens {
  my $text = shift;

  $text =~ s/\$nop//g;
  $text =~ s/\$n/\n/g;
  $text =~ s/\$quot/\"/g;
  $text =~ s/\$perce?nt/\%/g;
  $text =~ s/\$dollar/\$/g;

  return $text;
}

###############################################################################
sub expandVars {
  my ($format, %data) = @_;

  #writeDebug("called expandVars($format, '".join(',',keys %data).")");

  foreach my $key (keys %data) {
    my $value = $data{$key};
    next unless defined $value;
    $value = join(', ', sort @$value) if ref($data{$key}) eq 'ARRAY';

    # format list values using the '$' delimiter in multiple lines; see rfc4517
    # The only attribute I've seen so far where this rule should be used is in in postalAddress.
    # In most other cases this hurts a lot more than anything else.
    if ($key =~ /^(postalAddress)$/) { # TODO: make this rule configurable
      $value =~ s/([^\\])\$/$1<br \/>/go;
      $value =~ s/\\\$/\$/go;
      $value =~ s/\\\\/\\/go;
    }

    $format =~ s/\$$key\b/$value/gi;

    #writeDebug("$key=$value");
  }

  #writeDebug("done expandVars()");
  return $format;
}

###############################################################################
sub indexTopicHandler {
  my ($this, $indexer, $doc, $web, $topic, $meta, $text) = @_;

  my $personAttributes = $Foswiki::cfg{Ldap}{PersonAttribures};
  return unless $personAttributes && keys %$personAttributes;

  #print STDERR "personAttributes=".join(", ", keys %{$personAttributes})."\n";

  ($meta) = Foswiki::Func::readTopic($web, $topic) unless $meta;

  my $personDataForm = $Foswiki::cfg{Ldap}{PersonDataForm} || 'UserForm';
  my $formName = $meta->getFormName;
  return unless $formName && $formName =~ /$personDataForm/;

  #print STDERR "found form $formName\n";

  my $wikiName = $topic;
  my $loginName = Foswiki::Func::wikiToUserName($wikiName);

  unless ($loginName) {
    print STDERR "WARNING: can't find loginName for $wikiName in user database ... trying LDAP directy\n";
    my $ldap = Foswiki::Contrib::LdapContrib::getLdapContrib($this->{session});
    $loginName = $ldap->getLoginOfWikiName($wikiName);
  }

  unless ($loginName) {
    print STDERR "WARNING: can't find loginName for $wikiName in user database ... alumni?\n";
    return;
  }

  my @emails = Foswiki::Func::wikinameToEmails($wikiName);

  #print STDERR "wikiName='$wikiName', loginName=$loginName, emails=" . join(", ", @emails) . "\n";

  if ($Foswiki::cfg{Ldap}{IndexEmails}) {
    my $email = shift @emails;    # SMELL: taking only the first known one
    if ($email) {
      _set_field($doc, 'field_Email_s', $email);
      _set_field($doc, 'field_Email_search', $email);
    }
  }

  my $ldap = new Foswiki::Contrib::LdapContrib($this->{session});
  my $filter = "$ldap->{loginAttribute}=$loginName";

  #print STDERR "filter='$filter'\n";
  my $entry;
  
  my $search = $ldap->search(
    filter => $filter,
    limit => 1,
    attrs => [ keys %$personAttributes ],
    callback => sub {
      my (undef, $result) = @_;
      return unless defined $result;
      $entry = $result;
    },
  );

  unless ($entry) {
    #print STDERR "$loginName not found in LDAP directory\n";
    return;
  }

  foreach my $attr ($entry->attributes()) {
    my $value = $entry->get_value($attr);
    next unless defined $value && $value ne '';

    $value = $ldap->fromLdapCharSet($value);

    my $label = $personAttributes->{$attr};

    if ($label eq 'thumbnail') {
      my $value = $ldap->cacheBlob($entry, $attr);
      next unless defined $value && $value ne '';

      $doc->add_fields($label => $value);
    } else {
      my $value = $entry->get_value($attr);
      next unless defined $value && $value ne '';

      $value = $ldap->fromLdapCharSet($value);

      _set_field($doc, 'field_' . $label . '_s', $value);
      _set_field($doc, 'field_' . $label . '_search', $value);
    }
  }

  if ($Foswiki::cfg{Ldap}{IgnoreViewRightsInSearch}) {
    writeDebug("ignoring access in search for $web.$topic");
    $doc->add_fields('access_granted' => 'all');
  }

  $ldap->finish();
}

sub _set_field {
  my ($doc, $name, $val) = @_;

  foreach my $field ($doc->fields) {
    if ($field->{name} eq $name) {
      if ($Foswiki::cfg{Ldap}{PreferLocalSettings} && $field->{value}) {
        #print STDERR "keeping field $name = $val from local settings\n";
      } else {
        #print STDERR "setting field $name to $val (was '$field->{value}')\n";
        $field->{value} = $val;
      }
      return;
    }
  }

  $doc->add_fields($name => $val);
}

1;
