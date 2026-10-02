#!/usr/bin/env perl
# Read ASAR metadata and package.json without running the bundled application.
use strict;
use warnings;
use JSON::PP;

@ARGV == 1 or die "Usage: perl $0 app.asar\n";
open my $archive, '<:raw', $ARGV[0] or die "$ARGV[0]: $!";
read($archive, my $prefix, 16) == 16 or die "Truncated ASAR prefix\n";
my ($size_pickle, $header_size, $header_payload, $json_size) = unpack('V4', $prefix);
$size_pickle == 4 && $json_size <= $header_size && $header_size <= 64 * 1024 * 1024
  or die "Unexpected ASAR header\n";
read($archive, my $json, $json_size) == $json_size or die "Truncated ASAR header\n";
my $header = decode_json($json);
my $data_offset = 8 + $header_size;

if (my $package = $header->{files}{'package.json'}) {
  if (!$package->{unpacked} && defined $package->{offset}) {
    seek($archive, $data_offset + $package->{offset}, 0) or die "ASAR seek failed\n";
    read($archive, my $contents, $package->{size}) == $package->{size}
      or die "Truncated package.json\n";
    print "Root package.json:\n", JSON::PP->new->pretty->canonical->encode(decode_json($contents));
  }
}

print "\nNative modules / shared libraries / unpacked entries:\n";
sub walk {
  my ($files, $prefix) = @_;
  for my $name (sort keys %$files) {
    my $entry = $files->{$name};
    my $path = length($prefix) ? "$prefix/$name" : $name;
    if ($entry->{files}) {
      walk($entry->{files}, $path);
    } elsif ($entry->{unpacked} || $path =~ /\.(?:node|so(?:\.\d+)*)$/) {
      print "$path\t", ($entry->{unpacked} ? 'unpacked' : 'packed'), "\n";
    }
  }
}
walk($header->{files}, '');
