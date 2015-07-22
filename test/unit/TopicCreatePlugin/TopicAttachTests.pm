# Tests %TOPICATTACH%
use strict;

package TopicAttachTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use utf8;
use strict;
use Foswiki;
use Foswiki::Func;
use Foswiki::Plugins::TopicCreatePlugin;

my $simpleTemplate = "SimpleTemplateAśčÁŠŤśěž";
my $attachedTopic  = "AttachedAśčÁŠŤśěž";
my $attachedFile   = "simpleAśčÁŠŤśěž.txt";
my $attachedName   = "SimplesAśčÁŠŤśěž";

sub new {
    my $self = shift()->SUPER::new(@_);

    # try and guess where our test attachments are
    $self->{attachmentDir} =
"$Foswiki::cfg{WorkingDir}/../../TopicCreatePlugin/test/unit/TopicCreatePlugin/resources/";
    if ( !-e $self->{attachmentDir} ) {
        die
"Can't find attachment_examples directory (tried $self->{attachmentDir})";
    }

    return $self;
}

sub loadExtraConfig {
    my $this = shift;

    $Foswiki::cfg{Plugins}{TopicCreatePlugin}{Enabled} = 1;
    $this->SUPER::loadExtraConfig();
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    # create a simple template topic
    Foswiki::Func::saveTopic( $this->{test_web}, $simpleTemplate, undef,
        <<'HERE');
---++ Template Topic
A simple template topic
HERE

    Foswiki::Func::saveTopic( $this->{test_web}, $attachedTopic, undef,
        <<'HERE');
---++ Attached Topic
A topic with an attachment
HERE

    Foswiki::Func::saveAttachment( $this->{test_web}, $attachedTopic,
        $attachedName, { file => $this->{attachmentDir} . $attachedFile } );
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_simple_attach {
    my $this = shift;

    my $sampleText = <<"HERE";
%META:TOPICINFO{author="guest" date="1053267450" format="1.0" version="1.35"}%
%META:TOPICPARENT{name="WebHome"}%

%TOPICATTACH{fromtopic="$attachedTopic" fromfile="$attachedName"}%

HERE

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, $attachedName
        ),
        "attachment was not attached"
    );
}

sub test_attachment_rename {
    my $this = shift;

    my $newAttachedName = "newname.txt";

    my $sampleText = <<"HERE";
%META:TOPICINFO{author="guest" date="1053267450" format="1.0" version="1.35"}%
%META:TOPICPARENT{name="WebHome"}%

%TOPICATTACH{fromtopic="$attachedTopic" fromfile="$attachedName" name="$newAttachedName"}%

HERE

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, $newAttachedName
        ),
        "attachment was not attached with new name"
    );
}

sub test_attachment_comment {
    my $this = shift;

    my $newComment = "New comment!";

    my $sampleText = <<"HERE";
%META:TOPICINFO{author="guest" date="1053267450" format="1.0" version="1.35"}%
%META:TOPICPARENT{name="WebHome"}%

%TOPICATTACH{fromtopic="$attachedTopic" fromfile="$attachedName" comment="$newComment"}%

HERE

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    $this->assert(
        Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, $attachedName
        ),
        "attachment was not attached"
    );

    my ( $meta, $topic ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $attachment = $meta->get( 'FILEATTACHMENT', $attachedName );
    $this->assert_str_equals( $attachment->{comment},
        $newComment, "Attachment did not have new comment" );
}

sub test_disable {
    my $this = shift;

    # WebHome is the current topic when running tests
    my $sampleText = <<"HERE";
%META:TOPICINFO{author="guest" date="1053267450" format="1.0" version="1.35"}%
%META:TOPICPARENT{name="WebHome"}%

%TOPICATTACH{fromtopic="$attachedTopic" fromfile="$attachedName" disable="$this->{test_topic}"}%

HERE

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    $this->assert(
        !Foswiki::Func::attachmentExists(
            $this->{test_web}, $this->{test_topic}, $attachedName
        ),
        "attachment was attached, when it should have been disabled"
    );
}

sub test_attachment_exists {
    my $this = shift;

    my $testComment = "I overwrote...";

    my $sampleText = <<"HERE";
---++ Test topic

%TOPICATTACH{fromtopic="$attachedTopic" fromfile="$attachedName" comment="$testComment"}%

HERE

    Foswiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $sampleText );

    Foswiki::Func::saveAttachment( $this->{test_web}, $this->{test_topic},
        $attachedName, { file => $this->{attachmentDir} . $attachedFile } );

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    my ( $meta, $topic ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $attachment = $meta->get( 'FILEATTACHMENT', $attachedName );
    $this->assert_str_not_equals( $attachment->{comment},
        $testComment, "Attachment overwritten" );
}

1;
