# Tests %TOPICCREATE%
# still more that could be written, including:
#   - recursive %TOPICCREATE%'s
package TopicCreateTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::Func;
use Foswiki::Plugins::TopicCreatePlugin;

my $simpleTemplate = "SimpleTemplateTopic";

sub new {
    my $self = shift()->SUPER::new(@_);
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

}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

# test the simplest use of %TOPICCREATE%
sub test_simple_create {
    my $this = shift;

    my $testTopic = "SimpleCreateTest";

    my $sampleText = <<"HERE";
%META:TOPICINFO{author="guest" date="1053267450" format="1.0" version="1.35"}%
%META:TOPICPARENT{name="WebHome"}%

%TOPICCREATE{template="$simpleTemplate" topic="$testTopic"}%

HERE

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    # child topic should now exist
    $this->assert( Foswiki::Func::topicExists( $this->{test_web}, $testTopic ),
        "$testTopic was not created" );

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $testTopic );

    # check the text from the template has been copied
    $this->assert_matches( "simple template topic",
        $text, "Template text does not appear in the new topic" );

 # parent of newly created topic should be same as the topic it was created from
    $this->assert_equals( $this->{test_topic}, $meta->getParent(),
        "Parent of new child topic is incorrect" );
}

# test the use of %TOPICCREATE{ parent="FooBar" }%
sub test_parent {
    my $this = shift;

    my $testTopic = "ParentTest";

    my $sampleText = <<"HERE";
%META:TOPICINFO{author="guest" date="1053267450" format="1.0" version="1.35"}%
%META:TOPICPARENT{name="WebHome"}%

%TOPICCREATE{template="$simpleTemplate" topic="$testTopic" parent="FooBar"}%

HERE

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    # child topic should now exist
    $this->assert( Foswiki::Func::topicExists( $this->{test_web}, $testTopic ),
        "$testTopic was not created" );

    # parent of newly created topic should be WebHome
    my ( $meta, undef ) =
      Foswiki::Func::readTopic( $this->{test_web}, $testTopic );
    $this->assert_equals( "FooBar", $meta->getParent(),
        "Parent of new child topic is incorrect" );
}

# test the use of %TOPICCREATE{ parent="%HOMETOPIC%" }%
sub test_parent_as_macro {
    my $this = shift;

    my $testTopic = "ParentTest2";

    my $sampleText = <<"HERE";
%META:TOPICINFO{author="guest" date="1053267450" format="1.0" version="1.35"}%
%META:TOPICPARENT{name="WebHome"}%

%TOPICCREATE{template="$simpleTemplate" topic="$testTopic" parent="%HOMETOPIC%"}%

HERE

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    # child topic should now exist
    $this->assert( Foswiki::Func::topicExists( $this->{test_web}, $testTopic ),
        "$testTopic was not created" );

    # parent of newly created topic should be WebHome
    my ( $meta, undef ) =
      Foswiki::Func::readTopic( $this->{test_web}, $testTopic );
    $this->assert_equals( "WebHome", $meta->getParent(),
"Parent of new child topic is incorrect. Should be the same as the current topic."
    );
}

# test the use of %TOPICCREATE{ parent="%TOPIC%" }%
sub test_parent_as_topic {
    my $this = shift;

    my $testTopic = "ParentTest2";

    my $sampleText = <<"HERE";
%META:TOPICINFO{author="guest" date="1053267450" format="1.0" version="1.35"}%
%META:TOPICPARENT{name="WebHome"}%

%TOPICCREATE{template="$simpleTemplate" topic="$testTopic" parent="%TOPIC%"}%

HERE

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    # child topic should now exist
    $this->assert( Foswiki::Func::topicExists( $this->{test_web}, $testTopic ),
        "$testTopic was not created" );

    # parent of newly created topic should be WebHome
    my ( $meta, undef ) =
      Foswiki::Func::readTopic( $this->{test_web}, $testTopic );
    $this->assert_equals( $this->{test_topic}, $meta->getParent(),
"Parent of new child topic is incorrect. Should be the same as the current topic."
    );
}

# test the use of %TOPICCREATE{ disable="ThisTopic" }%
sub test_disable {
    my $this = shift;

    my $testTopic = "DisableTest";

    # WebHome is the current topic when running tests
    my $sampleText = <<"HERE";
%META:TOPICINFO{author="guest" date="1053267450" format="1.0" version="1.35"}%
%META:TOPICPARENT{name="WebHome"}%

%TOPICCREATE{template="$simpleTemplate" topic="$testTopic" disable="$this->{test_topic}"}%

HERE

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    # child topic should not exist
    $this->assert(
        !Foswiki::Func::topicExists( $this->{test_web}, $testTopic ),
        "$testTopic was created, when it should not have been"
    );
}

# test creating a topic with parameters
sub test_parameters {
    my $this = shift;

    my $template  = "ParamsTemplateTopic";
    my $testTopic = "ParamsTest";

    # create a simple template topic
    Foswiki::Func::saveTopic( $this->{test_web}, $template, undef, <<'HERE');
---++ Template Topic
A template topic with parameters

   * Param1: %URLPARAM{"param1"}%
   * Param2: %URLPARAM{"param2"}%

HERE

    my $sampleText = <<"HERE";
%META:TOPICINFO{author="guest" date="1053267450" format="1.0" version="1.35"}%
%META:TOPICPARENT{name="WebHome"}%

%TOPICCREATE{template="$template" topic="$testTopic" param1="Bergkamp" param2="Henry"}%

HERE

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    # child topic should now exist
    $this->assert( Foswiki::Func::topicExists( $this->{test_web}, $testTopic ),
        "$testTopic was not created" );

 # parent of newly created topic should be same as the topic it was created from
    my ( undef, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $testTopic );

    $this->assert_matches( "Bergkamp", $text,
        "param1 does not appear in the new topic" );
    $this->assert_matches( "Henry", $text,
        "param2 does not appear in the new topic" );
}

# test creating a topic with parameters
sub test_legacy_parameters {
    my $this = shift;

    my $template  = "LegacyParamsTemplateTopic";
    my $testTopic = "LegacyParamsTest";

    # create a simple template topic
    Foswiki::Func::saveTopic( $this->{test_web}, $template, undef, <<'HERE');
---++ Template Topic
A template topic with parameters

   * Param1: %URLPARAM{"param1"}%
   * Param2: %URLPARAM{"param2"}%

HERE

    my $sampleText = <<"HERE";
%META:TOPICINFO{author="guest" date="1053267450" format="1.0" version="1.35"}%
%META:TOPICPARENT{name="WebHome"}%

%TOPICCREATE{template="$template" topic="$testTopic" parameters="param1=Bergkamp&param2=Henry"}%

HERE

    Foswiki::Plugins::TopicCreatePlugin::initPlugin( $this->{test_topic},
        $this->{test_web}, 'guest', $Foswiki::cfg{SystemWebName} );
    Foswiki::Plugins::TopicCreatePlugin::beforeSaveHandler( $sampleText,
        $this->{test_topic}, $this->{test_web} );

    # child topic should now exist
    $this->assert( Foswiki::Func::topicExists( $this->{test_web}, $testTopic ),
        "$testTopic was not created" );

 # parent of newly created topic should be same as the topic it was created from
    my ( undef, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $testTopic );

    $this->assert_matches( "Bergkamp", $text,
        "param1 does not appear in the new topic" );
    $this->assert_matches( "Henry", $text,
        "param2 does not appear in the new topic" );
}

1;
