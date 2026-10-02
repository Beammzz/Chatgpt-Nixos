#!/usr/bin/env bash
# Extract and inspect an official .deb without executing its contents.
set -euo pipefail
export LC_ALL=C

if [[ $# != 2 ]]; then
  printf 'Usage: bash %s PACKAGE.deb OUTPUT_DIRECTORY\n' "$0" >&2
  exit 2
fi

package=$(realpath "$1")
output=$(realpath -m "$2")
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for tool in ar tar readelf perl sha256sum find sort; do
  command -v "$tool" >/dev/null || { printf 'Missing tool: %s\n' "$tool" >&2; exit 1; }
done

mkdir -p "$output/control" "$output/root" "$output/reports"
ar t "$package" > "$output/reports/ar-members.txt"
[[ $(ar p "$package" debian-binary) == 2.0 ]] || { printf 'Unsupported .deb format\n' >&2; exit 1; }

# Use a fresh output directory for a different package version: extraction does
# not remove files left by an earlier version.
for component in control data; do
  member=$(awk -v component="$component" '$0 ~ ("^" component "\\.tar(\\.|$)") { print; exit }' "$output/reports/ar-members.txt")
  [[ -n $member ]] || { printf 'Missing %s archive\n' "$component" >&2; exit 1; }
  case "$member" in
    *.xz) compression=(-J) ;;
    *.gz) compression=(-z) ;;
    *.zst) compression=(--zstd) ;;
    *.tar) compression=() ;;
    *) printf 'Unsupported compression: %s\n' "$member" >&2; exit 1 ;;
  esac
  target="$output/root"
  [[ $component != control ]] || target="$output/control"
  ar p "$package" "$member" | tar "${compression[@]}" -xf - --no-same-owner --no-same-permissions -C "$target"
done

sha256sum "$package" > "$output/reports/sha256.txt"
find "$output/root" -type f -printf '%P\t%s bytes\n' | sort > "$output/reports/files.txt"
find "$output/root" -type l -printf '%P -> %l\n' | sort > "$output/reports/symlinks.txt"
find "$output/root" -perm /6000 -printf '%P\n' > "$output/reports/special-permissions.txt"

# Identify ELF files by magic rather than filename, including native modules and
# executables nested under the bundled Node runtime. Never use ldd here.
perl -MFile::Find -e '
  find({no_chdir => 1, wanted => sub {
    return unless -f $_ && !-l $_;
    open my $file, "<:raw", $_ or die "$_: $!";
    read($file, my $magic, 4);
    print "$_\0" if $magic eq "\x7fELF";
  }}, $ARGV[0]);
' "$output/root" > "$output/reports/elf-paths.nul"

: > "$output/reports/elf.txt"
: > "$output/reports/needed-libraries.txt"
while IFS= read -r -d '' binary; do
  {
    printf '\nFILE: %s\n' "${binary#"$output/root/"}"
    readelf --wide -h -l -d -V "$binary"
  } >> "$output/reports/elf.txt"
  readelf --wide -d "$binary" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' >> "$output/reports/needed-libraries.txt"
done < "$output/reports/elf-paths.nul"
sort -u -o "$output/reports/needed-libraries.txt" "$output/reports/needed-libraries.txt"

# The library union above includes foreign-platform prebuilds. Preserve machine
# and path information so a packaging derivation can select the correct files.
perl -0777 -e '
  my $text = <>;
  my @files = split /\nFILE: /, $text;
  shift @files;
  print "file\tmachine\tinterpreter\tneeded\n";
  for my $entry (@files) {
    my ($path) = $entry =~ /^([^\n]+)/;
    my ($machine) = $entry =~ /Machine:\s*([^\n]+)/;
    my ($interpreter) = $entry =~ /Requesting program interpreter: ([^\]]+)/;
    my @needed = $entry =~ /Shared library: \[([^\]]+)\]/g;
    print join("\t", $path, $machine, $interpreter // "none", join(",", @needed)), "\n";
  }
' "$output/reports/elf.txt" > "$output/reports/elf-summary.tsv"

asar="$output/root/usr/lib/chatgpt/resources/app.asar"
if [[ -f $asar ]]; then
  perl "$script_dir/inspect-asar.pl" "$asar" > "$output/reports/asar.txt"
fi

printf 'Inspection complete: %s\n' "$output/reports"
cat "$output/control/control"
