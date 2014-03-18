# ---+ Extensions
# ---++ LDAP 

# ---+++ Indexing settings
# These settings are used in combination with SolrPlugin when indexing user topics. It allows you to fetch information from an LDAP directory
# in addition to a user profile page being indexed.

# **STRING**
# Name of the Foswiki DataForm that will identify the currently being indexed topic as a user profile page.
$Foswiki::cfg{Ldap}{PersonDataForm} = 'UserForm';

# **PERL**
# This is a map of LDAP attributes to be added to the solr document when the current is a user profile page. These attributes are
# added to the profile page as if they where formfield values of the given name. Each entry in this map has got the format
# <pre>attributeName => 'fieldName'</pre>
# where <code>fieldName</code> is a valid formfield name and <code>attributeName</code> is an LDAP attribute name to be fetched from the LDAP directory.
# In those cases where an formfield of the same name as the LDAP attribute is found, the formfield value takes higher precedence.
# Note that you might map multiple LDAP attributes onto the same field name. This will help in those cases where user records might follow different
# conventions across all of your LDAP directory.
$Foswiki::cfg{Ldap}{PersonAttribures} = {
  givenName => 'FirstName',
  sn => 'LastName',
  company => 'OrganisationName',
  department => 'Department',
  division => 'Division',
  title => 'Profession',
  c => 'Country',
  physicalDeliveryOfficeName => 'Address',
  postalAddress => 'Address',
  streetAddress => 'Address',
  facsimileTelephoneNumber => 'Telefax',
  l => 'Location',
  mail => 'Email',
  manager => 'Manager',
  mobile => 'Mobile',
  telephoneNumber => 'Telephone',
  title => 'Title',
  uid => 'LoginName',
  sAMAccountName => 'LoginName',
};

# **BOOLEAN**
# Enable this to index emails known to foswiki as well. 
$Foswiki::cfg{Ldap}{IndexEmails} = 1;

# **BOOLEAN**
# Enable this flag to let users override LDAP data in the DataForm attached to the user profile page.
$Foswiki::cfg{Ldap}{PreferLocalSettings} = 1;

# **STRING**
# Default cache expiry in seconds until data retrieved by an %LDAP query will be erased and/or fetched again from the directory server. 
# Setting this to 0 will disable default caching. You might enable caching per <code>%LDAP{cache="..."</code> again as required.
$Foswiki::cfg{Ldap}{DefaultCacheExpire} = 0;

# **BOOLEAN**
# Enable this to make all user topics findable no matter which view access rights they have. This comes in handy in cases where an employee search
# application is supposed to find all user profiles no matter what.
$Foswiki::cfg{Ldap}{IgnoreViewRightsInSearch} = 0;

1;
