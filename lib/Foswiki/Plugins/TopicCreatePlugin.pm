# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 - 2010 Andrew Jones, http://andrew-jones.com
# Copyright (C) 2005-2006 Peter Thoeny, peter@thoeny.org
#
# For licensing info read LICENSE file in the Foswiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.

package Foswiki::Plugins::TopicCreatePlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $debug $doInit $VERSION $RELEASE $SHORTDESCRIPTION $pluginName $NO_PREFS_IN_TOPIC
);

our $VERSION = '$Rev$';
our $RELEASE = '1.2';
our $SHORTDESCRIPTION =
  'Automatically create a set of topics and attachments at topic save time';
our $NO_PREFS_IN_TOPIC = 0;
our $pluginName        = 'TopicCreatePlugin';

our $doInit = 0;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # Get plugin debug flag
    $debug = Foswiki::Func::getPluginPreferencesFlag("DEBUG");

    # Plugin correctly initialized
    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::TopicCreatePlugin::initPlugin( $web.$topic ) is OK"
    ) if $debug;
    $doInit = 1;
    return 1;
}

# =========================
sub beforeSaveHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    Foswiki::Func::writeDebug(
        "- TopicCreatePlugin::beforeSaveHandler( $_[2].$_[1] )")
      if $debug;

    unless ( $_[0] =~ /%TOPIC(CREATE|ATTACH)\{.*?\}%/ ) {

        # nothing to do
        return 1;
    }

    require Foswiki::Plugins::TopicCreatePlugin::Func;

    if ($doInit) {
        $doInit = 0;
        Foswiki::Plugins::TopicCreatePlugin::Func::init( $web, $topic, $user,
            $debug );
    }

    $_[0] =~
s/%TOPICCREATE{(.*)}%[\n\r]*/Foswiki::Plugins::TopicCreatePlugin::Func::handleTopicCreate($1, $_[2], $_[1], $_[0] )/geo;

# To be completed, tested and documented
# $_[0] =~ s/%TOPICPATCH{(.*)}%[\n\r]*/Foswiki::Plugins::TopicCreatePlugin::Func::handleTopicPatch($1, $_[2], $_[1], $_[0] )/geo;

    if ( $_[0] =~ /%TOPICATTACH/ ) {
        my @attachMetaData = ();
        $_[0] =~
s/%TOPICATTACH{(.*)}%[\n\r]*/Foswiki::Plugins::TopicCreatePlugin::Func::handleTopicAttach($1, \@attachMetaData)/geo;
        my $fileName = "";
        foreach my $fileMeta (@attachMetaData) {
            $fileMeta =~ m/META:FILEATTACHMENT\{name\=\"(.*?)\"/;
            $fileName = $1;
            unless ( $_[0] =~ m/META:FILEATTACHMENT\{name\=\"$fileName/ ) {
                &Foswiki::Func::writeDebug(
                    "handleTopicAttach:: in unless $fileMeta")
                  if $debug;
                $_[0] .= "\n$fileMeta";
            }
            else {
                &Foswiki::Func::writeDebug(
                    "handleTopicAttach:: in else $fileMeta")
                  if $debug;
                $_[0] =~
                  s/(%META:FILEATTACHMENT\{name=\"$fileName.*?\}%)/$fileMeta/;
            }
        }
    }
}

1;

# EOF
