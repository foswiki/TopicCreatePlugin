# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Andrew Jones, andrewjones86@gmail.com
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
        $web $topic $user $debug
    );

# =========================
sub init
{
    ( $web, $topic, $user, $debug ) = @_;

    # initialize variables, once per page view

    # Module initialized
    Foswiki::Func::writeDebug( "- Foswiki::Plugins::TopicCreatePlugin::Func::init( $web.$topic )" ) if $debug;
    return 1;
}

# =========================
sub handleTopicCreate
{
    my( $theArgs, $theWeb, $theTopic, $theTopicText ) = @_;

    unless( defined( $theTopic ) ) {
        $theTopic = $topic;
    }
    my $errVar = "%<nop>TOPICCREATE{$theArgs}%";

    my $template = Foswiki::Func::extractNameValuePair( $theArgs, "template" ) ||
        return _errorMsg( $errVar, "Parameter =templatete= is missing or empty." );
    my $parameters = Foswiki::Func::extractNameValuePair( $theArgs, "parameters" ) || "";
    my $topicName = Foswiki::Func::extractNameValuePair( $theArgs, "topic" ) ||
                    Foswiki::Func::extractNameValuePair( $theArgs, "name" ) ||
        return _errorMsg( $errVar, "Parameter =topic= is missing or empty." );
    my $disable = Foswiki::Func::extractNameValuePair( $theArgs, "disable" ) || "";

    if($disable eq $topic) {
	#  saving the outer template itself should not invoke the create
        return "%TOPICCREATE{$theArgs}% ";
    }
    
    # expand relevant Foswiki Macros
    $topicName = Foswiki::Func::expandCommonVariables( $topicName, $theTopic, $theWeb );
    $template = Foswiki::Func::expandCommonVariables( $template, $theTopic, $theWeb );

    my $topicWeb = $theWeb;
    if( $topicName =~ /^([^\.]+)\.(.*)$/ ) {
        $topicWeb = $1;
        $topicName = $2;
    }

    if( Foswiki::Func::topicExists( $topicWeb, $topicName ) ) {
      #  Silently fail
      return "";
    }

    # check if template exists
    my $templateWeb = $theWeb;
    if( $template =~ /^([^\.]+)\.(.*)$/ ) {
        $templateWeb = $1;
        $template = $2;
    }

    # Error, Warn user
    unless( &Foswiki::Func::topicExists( $templateWeb, $template ) ) {
        return _errorMsg( $errVar, "Template <nop>$templateWeb.$template does not exist.");
    }
    
    my ($meta, $text) = &Foswiki::Func::readTopic($templateWeb, $template);

    # Set topic parent
    $meta->putKeyed( 'TOPICPARENT', { name => $theTopic } );

    # SMELL: replace with expandVariablesOnTopicCreation( $text );
    # but then we seem to loose our parameters... Leaving it as it is for now
    #$text = Foswiki::Func::expandVariablesOnTopicCreation( $text );

    my $localDate = &Foswiki::Time::formatTime( time(), $Foswiki::cfg{DefaultDateFormat} );

    my $wikiUserName = &Foswiki::Func::userToWikiName( $user );
    $text =~ s/%NOP{.*?}%//gos;  # Remove filler: Use it to remove access control at time of
    $text =~ s/%NOP%//go;        # topic instantiation or to prevent search from hitting a template
    $text =~ s/%DATE%/$localDate/go;
    $text =~ s/%WIKIUSERNAME%/$wikiUserName/go;

    # SMELL: see above - expandVariablesOnTopicCreation() also handles URLPARAM's
    my @param = ();
    my $temp = "";
    while (1) {
        last unless ( $text =~ m/%URLPARAM\{(.*?)\}%/gs );
        $temp = $1 || "";
        $temp =~ s/\"//g;
        push @param, ($temp);
    }

    my $ptemp = join  ", ", @param;
    &Foswiki::Func::writeDebug( "- Foswiki::Plugins::TopicCreatePlugin::topicCreate "
       . "$topicName $ptemp $parameters") if $debug;

    my $passedPar = "";
    foreach my $par (@param) {
        next unless ( $parameters =~ m/$par=(.*?)($|&)/ );
        $passedPar = $1 || "";
        $text =~ s/%URLPARAM\{\"?$par\"?\}%/$passedPar/g;
    }
    # END SMELL

    # Copy all Attachments over
    my @attachments = $meta->find( 'FILEATTACHMENT' );
    foreach my $attach ( @attachments ){
        my $fileName = $attach->{ 'path' } || $attach->{ 'attachment' } || $attach->{ 'name' };
        # TODO: We could keep the comment, date of upload, etc
        _copyAttachment( $templateWeb, $template, $fileName, $topicWeb, $topicName, $fileName );
    }

    # Recursively handle TOPICCREATE and TOPICATTCH
    $text =~ s/%TOPICCREATE{(.*)}%[\n\r]*/handleTopicCreate( $1, $theWeb, $topicName )/geo;
    $text =~ s/%TOPICATTCH{(.*)}%[\n\r]*/handleTopicAttach( $1, $theWeb, $topicName )/geo;

    #my $error = &Foswiki::Func::saveTopicText( $topicWeb, $topicName, $text, 1, "dont notify" );
    &Foswiki::Func::saveTopic( $topicWeb, $topicName, $meta, $text, { minor => 1 } );

    return "";
}

# =========================
# Untested and Undocumented, comes from this plugins TWiki days
# Feel free to complete and test this if you need it
sub handleTopicPatch
{
    my( $theArgs, $theWeb, $theTopic, $theTopicText ) = @_;

    my $errVar = "%<nop>TOPICPATCH{$theArgs}%";
    my $topicName = Foswiki::Func::extractNameValuePair( $theArgs, "topic" ) ||
        return "";   #  Silently fail if not specified
    my $action = Foswiki::Func::extractNameValuePair( $theArgs, "action" ) ||
        return _errorMsg( $errVar, "Missing =action= parameter" );
    unless( $action =~ /^(append|replace)$/ ) {
        return _errorMsg( $errVar, "Unsupported =action= parameter" );
    }
    my $formfield = Foswiki::Func::extractNameValuePair( $theArgs, "formfield" ) ||
        return _errorMsg( $errVar, "Missing =formfield= parameter" );
    my $value = Foswiki::Func::extractNameValuePair( $theArgs, "value" ) || "";

    # expand relevant Foswiki Variables
    $topicName =~ s/%TOPIC%/$theTopic/go;
    $topicName =~ s/%WEB%/$theWeb/go;
    $topicName =~ s/.*\.//go;  # cut web for security (only current web)

    my $text = Foswiki::Func::readTopicText( $theWeb, $topicName );

    if( $text =~ /^http/ ) {
        return _errorMsg( $errVar, "No permission to update '$topicName'" );
    } elsif( $text eq "" ) {
        return _errorMsg( $errVar, "Can't update '$topicName' because it does not exist" );
    }

    $text = _setMetaData( $text, "FIELD", $value, $formfield );
    #$meta->putKeyed( 'FIELD', {
    #        name => $formfield,
    #        value => $value
    #});

    my $error = Foswiki::Func::saveTopicText( $theWeb, $topicName, $text, "", "dont notify" );

    if( $error ) {
        return _errorMsg( $errVar, "Can't update '$topicName' due to permissions" );
    }

    return "";
}

# =========================
sub handleTopicAttach
{
    my( $theArgs, $theWeb, $theTopic, $theTopicText ) = @_;
    my( $theArgs, $attachMetaDataRef ) = @_;

    my $errVar = "%<nop>TOPICATTACH{$theArgs}%";
    my $fromTopic = Foswiki::Func::extractNameValuePair( $theArgs, "fromtopic" ) ||
        return _errorMsg( $errVar, "Missing =fromtopic= parameter" );
    my $fromFile = Foswiki::Func::extractNameValuePair( $theArgs, "fromfile" ) ||
        return _errorMsg( $errVar, "Missing =fromfile= parameter" );
    my $attachComment = Foswiki::Func::extractNameValuePair( $theArgs, "comment" );
    my $disable = Foswiki::Func::extractNameValuePair( $theArgs, "disable" ) || "";

    ## 11/18/05: override of attachment name not yet supported, requires messing with meta info
    ## my $name = Foswiki::Func::extractNameValuePair( $theArgs, "name" ) || $fromFile;
    my $name = $fromFile;

    if($disable eq $topic) {
	#  saving the outer template itself should not invoke the create
        return "%TOPICATTACH{$theArgs}% ";
    }

    $name =~ s/%TOPIC%/$topic/go;
    $name =~ s/%WEB%/$web/go;

    my $fromTopicWeb = $web;
    if( $fromTopic =~ /^([^\.]+)\.(.*)$/ ) {
        $fromTopicWeb = $1;
        $fromTopic = $2;
    }

    if( _existAttachment( $web, $topic, $name ) ) {
        return _errorMsg( $errVar, "Attachment =$name= already exists in destination topic $web.$topic" );
    }

    # Copy attachment over
    if( _existAttachment( $fromTopicWeb, $fromTopic, $fromFile ) ) {
        _copyAttachment( $fromTopicWeb, $fromTopic, $fromFile, $web, $topic, $name );
        # FIXME: use Foswiki::Func::readTopic( $web, $topic, $rev ) -> ( $meta, $text );
        # then use the Meta object
        my $fromTopicText = &Foswiki::Func::readTopicText( $fromTopicWeb, $fromTopic, "", 1 );
        $fromTopicText =~ m/(%META:FILEATTACHMENT\{name=\"$fromFile.*?\}%)/;
        my $attachInfo = $1;
        $attachInfo =~ s/attr="h"/attr=""/;
        $attachInfo =~ s/name=".*" /name="$name" /;
        if ($attachComment) {
            $attachInfo =~ s/comment=".*" /comment="$attachComment" /;
        }
        push @$attachMetaDataRef, ($attachInfo);
    } else {
        &Foswiki::Func::writeDebug( "- Foswiki::Plugins::TopicCreatePlugin::handleTopicAttach:: $fromFile does not exist in $fromTopicWeb/$fromTopic" ) if $debug;
        return _errorMsg( $errVar, "Attachment =$fromFile= does not exist in source topic $fromTopicWeb.$fromTopic" );
    }
    return "";
}

# =========================
sub _errorMsg
{
    my ( $theVar, $theText ) = @_;
    return "%RED% Error in $theVar: $theText %ENDCOLOR% ";
}

# =========================
sub _getAttachmentList
{
    my ( $theWeb, $theTopic ) = @_;
}

# =========================
sub _existAttachment
{
    my ( $theWeb, $theTopic, $theFile ) = @_;
    
    return Foswiki::Func::attachmentExists( $theWeb, $theTopic, $theFile );
}

# =========================
sub _copyAttachment
{
    my ( $fromWeb, $fromTopic, $fromFile, $toWeb, $toTopic, $toFile ) = @_;
    
    my $pubDir = $Foswiki::cfg{PubDir};
    
    my $filePath = "$pubDir/$fromWeb/$fromTopic/$fromFile";
   
    Foswiki::Func::saveAttachment( $toWeb, $toTopic, $toFile, { file => $filePath } );
    
    &Foswiki::Func::writeDebug( "- Foswiki::Plugins::TopicCreatePlugin::copyAttachment from $fromWeb/$fromTopic/$fromFile to $toWeb/$toTopic/$toFile") if $debug;
}

1;

#EOF
