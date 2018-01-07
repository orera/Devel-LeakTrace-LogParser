{
  use 5.010;
  use strict;
  use warnings;

  use Data::Dumper qw(Dumper);
  use Readonly     qw(Readonly);

  use Moose;
  with 'MooseX::Getopt';

  Readonly my $LEAKED_RE       => qr/^leaked [A-Z][A-Z]\([^)]+\) from (.*?) line (\d+)$/i;
  Readonly my $POSITIVE_INT_RE => qr/^[1-9]\d*$/;

  has 'filename' => (is => 'ro', isa => 'Str' );
  has 'context'  => (is => 'ro', isa => 'Int', default => 3 );

  has 'module_filter' => ( is => 'rw', isa => 'Str|RegexpRef', default => '^\(eval' );
  has 'source_filter' => ( is => 'rw', isa => 'Str|RegexpRef', default => '' );

  exit __PACKAGE__->new_with_options->main unless caller 0;

  sub BUILD {
    my ($self) = @_;

    REGEXP:
    foreach my $re_attribute ( qw(module_filter source_filter) ) {
      my $re = $self->$re_attribute;
      $self->$re_attribute( qr/$re/ )
        if defined $re and length $re;
    } # END foreach REGEXP:
  } # END sub

  sub main {
    my ($self) = @_;
#die Dumper $self;

    # Read the logfile and build hash of leaks
    my $leaks = $self->parse_logfile;
#die Dumper sort keys %$leaks;

    MODULE:
    foreach my $module (sort { lc($a) cmp lc($b) } keys %{ $leaks }) {
      next MODULE
        if  length $self->module_filter
        and $module =~ $self->module_filter;

      LINE_NUM:
      foreach my $line_num (sort { $a <=> $b } keys %{ $leaks->{$module} }) {
        my @source_lines = @{ $self->get_offending_line($module, $line_num) };
        next LINE_NUM unless scalar @source_lines;

        my ($line_content) = grep { $_->[0] == $line_num } @source_lines;
        next LINE_NUM
          if  length $self->source_filter
          and $line_content->[1] =~ $self->source_filter;
#die Dumper \@source_lines;

        my $count = $leaks->{$module}->{$line_num};
        say '*' x 50;
        say '*' x  1, " File: $module";
        say '*' x  1, " Line: $line_num, Calls: $count";
        SOURCE_LINE:
        foreach my $source_line (@source_lines) {
          say sprintf "line%s%s: %s",
            ($source_line->[0] == $line_num ? '=' : ' '), # Marking
            $source_line->[0], # Line number
            $source_line->[1]; # Line content
        } # END foreach SOURCE_LINE
      } #  END foreach LINE_NUM
    } # END foreach MODULE

    exit '0 but true';
  } # END sub main

  sub get_offending_line {
    die "wrong number of arguments to function get_offending_lines"
      unless scalar @_ == 3;
    my ($self, $filename, $line_num) = @_;

    die "filename is required"
      unless defined $filename
         and length  $filename;

    die "line_num is required"
      unless defined $line_num
         and length  $line_num
         and $line_num =~ $POSITIVE_INT_RE;

    my $min_line = $self->context > $line_num ? 1 : $line_num - $self->context;
    my $max_line = $self->context + $line_num;

    do {
      warn "'$filename' is not a readable file";
      return [];
    } unless -e $filename and -f $filename and -r $filename;
    
    my @lines;
    open my $fh, '<', $filename
      or die "failed to open $filename for reading";

    my $line_count = 0;
    LINE:
    while (my $line = <$fh>) {
      $line_count++;

      # Skip lines until the minimum line number
      next LINE unless $line_count >= $min_line;

      chomp $line;
      push  @lines, [$line_count, $line];

      # Shortcut the loop until max line has been processed.
      # after that exit the loop early
      next LINE if $line_count < $max_line;
      last LINE;
    } # END while LINE:
    close $fh;

    return \@lines;
  } # END sub get_offending_line

  sub parse_logfile {
    my ($self) = @_;
    my %leaks;

    # TODO: do we really need an if statement for this?
    my $fh;
    if (defined $self->filename and length $self->filename) {
      open $fh, '<', $self->filename
        or die sprintf "failed to open logfile: %s", $self->filename;
    }
    else {
      $fh = 'STDIN';
    }

    LINE:
    while (my $line = <$fh>) {
      next LINE unless $line =~ $LEAKED_RE;
      my $module   = $1;
      my $line_num = $2;
      $leaks{$module}{$line_num}++;
    } # END while <STDIN>
    close $fh;
    
    return \%leaks;
  } # END sub parse_logfile
}

__END__

=pod

=encoding UTF-8

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 AUTHOR

Tore Andersson <tore.andersson@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright 2018 Tore Andersson.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

