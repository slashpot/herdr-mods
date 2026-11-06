# Loads libnowplaying.dylib into /usr/bin/perl, which macOS entitles to use
# MediaRemote, and runs it. See nowplaying.m.
#
#   /usr/bin/perl nowplaying.pl <dylib> get [art-dir]
#   /usr/bin/perl nowplaying.pl <dylib> send <command-id> [bundle]
use strict;
use warnings;
use DynaLoader;

my ($lib, $cmd, $arg, $bundle) = @ARGV;
die "usage: nowplaying.pl <dylib> get [art-dir] | send <id> [bundle]\n" unless $lib && $cmd;

$ENV{NP_CMD} = $cmd;
if ($cmd eq 'get') { $ENV{NP_ART_DIR} = $arg // ''; }
else               { $ENV{NP_ARG} = $arg // ''; $ENV{NP_BUNDLE} = $bundle // ''; }

my $handle = DynaLoader::dl_load_file($lib, 0)
  or die "cannot load $lib: " . DynaLoader::dl_error() . "\n";
my $symbol = DynaLoader::dl_find_symbol($handle, 'nowplaying_main')
  or die "nowplaying_main not found in $lib\n";
DynaLoader::dl_install_xsub('main::nowplaying_main', $symbol);
nowplaying_main();
