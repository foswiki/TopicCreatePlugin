# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2015 - Foswiki contributors
# Copyright (C) 2009 - 2012 Andrew Jones, http://andrew-jones.com
# Copyright (C) 2005 - 2006 Peter Thoeny, peter@thoeny.org
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
#
# =========================
#
# The code below is kept out of the main plugin module for
# performance reasons, so it doesn't get compiled until it
# is actually used.

package Foswiki::Plugins::TopicCreatePlugin::Func;

use strict;

# =========================
use vars qw(
  $debug
);

# =========================
sub init {
    ($debug) = @_;
    return 1;
}

# =========================
sub handleTopicCreate {
    my ( $theArgs, $theWeb, $theTopic ) = @_;

    my $errVar = "%<nop>TOPICCREATE{$theArgs}%";

    my %parameters = Foswiki::Func::extractParameters($theArgs);

    if ( $parameters{disable} && $parameters{disable} eq $theTopic ) {

        #  saving the outer template itself should not invoke the create
        return "%TOPICCREATE{$theArgs}% ";
    }

    unless ( exists $parameters{template} ) {
        return _errorMsg( $errVar,
            "Parameter =template= is missing or empty." );
    }

    unless ( exists $parameters{topic} || exists $parameters{name} ) {
        return _errorMsg( $errVar, "Parameter =topic= is missing or empty." );
    }

    # support legacy parameters, like
    # parameters="param1=Bergkamp&param2=Henry"
    if ( $parameters{parameters} ) {

# need to parse into a format which extractParameters expects (i.e add double quotes)
        $parameters{parameters} =~ s/=/="/g;
        $parameters{parameters} =~ s/&/" /g;
        $parameters{parameters} .= '"';

        %parameters = (
            %parameters,
            Foswiki::Func::extractParameters( $parameters{parameters} )
        );

        delete( $parameters{parameters} );
    }

    # expand Foswiki Macros
    for my $key ( keys %parameters ) {
        $parameters{$key} =
          Foswiki::Func::expandCommonVariables( $parameters{$key}, $theTopic,
            $theWeb );
    }

    my $template  = $parameters{template};
    my $topicName = $parameters{topic} || $parameters{name};
    my $parent    = $parameters{parent} || $theTopic;

    my $topicWeb = $theWeb;
    if ( $topicName =~ /^([^\.]+)\.(.*)$/ ) {
        $topicWeb  = $1;
        $topicName = $2;
    }

    if ( Foswiki::Func::topicExists( $topicWeb, $topicName ) ) {

        #  Silently fail
        return "";
    }

    # check if template exists
    my $templateWeb = $theWeb;
    if ( $template =~ /^([^\.]+)\.(.*)$/ ) {
        $templateWeb = $1;
        $template    = $2;
    }

    # Error, Warn user
    unless ( Foswiki::Func::topicExists( $templateWeb, $template ) ) {
        return _errorMsg( $errVar,
            "Template <nop>$templateWeb.$template does not exist." );
    }

    my ( $meta, $text ) = Foswiki::Func::readTopic( $templateWeb, $template );

    # see if we have any form fields that match our parameters
    # if we do, set the value of the field
    for my $field ( $meta->find('FIELD') ) {
        if ( my $value = $parameters{ $field->{name} } ) {
            $field->{value} = $value;
            $meta->putKeyed( 'FIELD', $field );
        }
    }

    # Set topic parent
    $meta->putAll( 'TOPICPARENT', { name => $parent } );

    # SMELL: replace with expandVariablesOnTopicCreation( $text );
    # but then we seem to loose our parameters... Leaving it as it is for now
    #$text = Foswiki::Func::expandVariablesOnTopicCreation( $text );

    my $localDate =
      Foswiki::Time::formatTime( time(), $Foswiki::cfg{DefaultDateFormat} );

    my $wikiUserName = Foswiki::Func::getWikiUserName();
    $text =~ s/%NOP\{.*?\}%//gs
      ;    # Remove filler: Use it to remove access control at time of
    $text =~ s/%NOP%//go
      ;    # topic instantiation or to prevent search from hitting a template
    $text =~ s/%DATE%/$localDate/g;
    $text =~ s/%WIKIUSERNAME%/$wikiUserName/g;

   # SMELL: see above - expandVariablesOnTopicCreation() also handles URLPARAM's
    my @param = ();
    my $temp  = "";
    while (1) {
        last unless ( $text =~ m/%URLPARAM\{(.*?)\}%/gs );
        $temp = $1 || "";
        $temp =~ s/\"//g;
        push @param, ($temp);
    }

    my $ptemp = join ", ", @param;
    Foswiki::Func::writeDebug(
            "- Foswiki::Plugins::TopicCreatePlugin::topicCreate "
          . "$topicName $ptemp" )
      if $debug;

    my $passedPar = "";
    foreach my $par (@param) {
        next unless ( $parameters{$par} );
        $text =~ s/%URLPARAM\{\"?$par\"?\}%/$parameters{$par}/g;
    }

    # END SMELL

    # Copy all Attachments over
    my @attachments = $meta->find('FILEATTACHMENT');
    foreach my $attachment (@attachments) {

        Foswiki::Func::copyAttachment( $templateWeb, $template,
            $attachment->{'name'}, $topicWeb, $topicName,
            $attachment->{'name'} );
    }

    # Recursively handle TOPICCREATE and TOPICATTCH
    $text =~
s/%TOPICCREATE\{(.*)\}%[\n\r]*/handleTopicCreate( $1, $theWeb, $topicName )/ge;
    $text =~
s/%TOPICATTCH\{(.*)\}%[\n\r]*/handleTopicAttach( $1, $theWeb, $topicName )/ge;

    Foswiki::Func::saveTopic( $topicWeb, $topicName, $meta, $text,
        { minor => 1 } );

    return "";
}

# =========================
# Untested and Undocumented, comes from this plugins TWiki days
# Feel free to complete and test this if you need it
# sub handleTopicPatch {
#     my ( $theArgs, $theWeb, $theTopic, $theTopicText ) = @_;
#
#     my $errVar = "%<nop>TOPICPATCH{$theArgs}%";
#     my $topicName = Foswiki::Func::extractNameValuePair( $theArgs, "topic" )
#       || return "";    #  Silently fail if not specified
#     my $action = Foswiki::Func::extractNameValuePair( $theArgs, "action" )
#       || return _errorMsg( $errVar, "Missing =action= parameter" );
#     unless ( $action =~ /^(append|replace)$/ ) {
#         return _errorMsg( $errVar, "Unsupported =action= parameter" );
#     }
#     my $formfield = Foswiki::Func::extractNameValuePair( $theArgs, "formfield" )
#       || return _errorMsg( $errVar, "Missing =formfield= parameter" );
#     my $value = Foswiki::Func::extractNameValuePair( $theArgs, "value" ) || "";
#
#     # expand relevant Foswiki Variables
#     $topicName =~ s/%TOPIC%/$theTopic/go;
#     $topicName =~ s/%WEB%/$theWeb/go;
#     $topicName =~ s/.*\.//go;    # cut web for security (only current web)
#
#     my $text = Foswiki::Func::readTopicText( $theWeb, $topicName );
#
#     if ( $text =~ /^http/ ) {
#         return _errorMsg( $errVar, "No permission to update '$topicName'" );
#     }
#     elsif ( $text eq "" ) {
#         return _errorMsg( $errVar,
#             "Can't update '$topicName' because it does not exist" );
#     }
#
#     $text = _setMetaData( $text, "FIELD", $value, $formfield );
#
#     #$meta->putKeyed( 'FIELD', {
#     #        name => $formfield,
#     #        value => $value
#     #});
#
#     my $error = Foswiki::Func::saveTopicText( $theWeb, $topicName, $text, "",
#         "dont notify" );
#
#     if ($error) {
#         return _errorMsg( $errVar,
#             "Can't update '$topicName' due to permissions" );
#     }
#
#     return "";
# }

# =========================
sub handleTopicAttach {
    my ( $theArgs, $theWeb, $theTopic ) = @_;

    my $errVar = "%<nop>TOPICATTACH{$theArgs}%";
    my $fromTopic = Foswiki::Func::extractNameValuePair( $theArgs, "fromtopic" )
      || return _errorMsg( $errVar, "Missing =fromtopic= parameter" );
    my $fromFile = Foswiki::Func::extractNameValuePair( $theArgs, "fromfile" )
      || return _errorMsg( $errVar, "Missing =fromfile= parameter" );
    my $attachComment =
      Foswiki::Func::extractNameValuePair( $theArgs, "comment" );
    my $disable = Foswiki::Func::extractNameValuePair( $theArgs, "disable" )
      || "";
    my $name = Foswiki::Func::extractNameValuePair( $theArgs, "name" )
      || $fromFile;

    if ( $disable eq $theTopic ) {

        #  saving the outer template itself should not invoke the create
        return "%TOPICATTACH{$theArgs}% ";
    }

    $name =~ s/%TOPIC%/$theTopic/g;
    $name =~ s/%WEB%/$theWeb/g;

    my $fromTopicWeb = $theWeb;
    if ( $fromTopic =~ /^([^\.]+)\.(.*)$/ ) {
        $fromTopicWeb = $1;
        $fromTopic    = $2;
    }

    if ( Foswiki::Func::attachmentExists( $theWeb, $theTopic, $name ) ) {
        return _errorMsg( $errVar,
"Attachment =$name= already exists in destination topic $theWeb.$theTopic"
        );
    }

    # Copy attachment over
    if ( Foswiki::Func::attachmentExists( $fromTopicWeb, $fromTopic, $fromFile )
      )
    {

        Foswiki::Func::copyAttachment( $fromTopicWeb, $fromTopic, $fromFile,
            $theWeb, $theTopic, $name );

        if ($attachComment) {
            my ( $toTopicMeta, $toTopicText ) =
              Foswiki::Func::readTopic( $theWeb, $theTopic );
            my $attachment = $toTopicMeta->get( 'FILEATTACHMENT', $fromFile );
            $attachment->{comment} = $attachComment;
            $toTopicMeta->putKeyed( 'FILEATTACHMENT', $attachment );
            $toTopicMeta->save();
        }
    }
    else {
        Foswiki::Func::writeDebug(
"- Foswiki::Plugins::TopicCreatePlugin::handleTopicAttach:: $fromFile does not exist in $fromTopicWeb/$fromTopic"
        ) if $debug;
        return _errorMsg( $errVar,
"Attachment =$fromFile= does not exist in source topic $fromTopicWeb.$fromTopic"
        );
    }
    return "";
}

# =========================
sub _errorMsg {
    my ( $theVar, $theText ) = @_;
    return "%RED% Error in $theVar: $theText %ENDCOLOR% ";
}

1;

#EOF
