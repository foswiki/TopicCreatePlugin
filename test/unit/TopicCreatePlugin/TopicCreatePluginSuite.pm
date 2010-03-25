package TopicCreatePluginSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'TopicCreatePluginSuite' }

sub include_tests { qw(TopicCreateTests) }

1;
