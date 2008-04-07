#!/usr/bin/perl
# 
# $Id: Rule.pm,v 1.21 2004/05/19 18:41:55 bmc Exp $
#
# Copyright (C) 2003 Brian Caswell <bmc@shmoo.com>
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#       This product includes software developed by Brian Caswell.
# 4. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

=head1 NAME

Net::Snort::Parser::Rule - Perl interface to parsing snort rules

=head1 SYNOPSIS

use Net::Snort::Parser::Rule;

my $parser = Net::Snort::Parser::Rule->new();
my $rule = $parser->parse_rule($ruletext);

=head1 DESCRIPTION

Net::Snort::Parser::File is a module that provides a mechanism for parsing snort rules, handling most of the "isms" that the snort parser forces on application developers.

Programmers that use this module should be familar with the snort rules format, since many requirements of the rules language are implied by this module.

=head1 NOTES

This module does not handle multiline rules.  That should be handled before passing the rule to the parser.

=head1 AUTHOR

Brian Caswell <bmc@shmoo.com>

=head1 REPORTING BUGS

Report bugs to <bmc@shmoo.com>

=head1 THANKS

Thanks to The Honeynet Project

=head1 COPYRIGHT

Copyright (c) 2003 Brian Caswell 

=head1 SEE ALSO

L<snort(8)>

=cut

#package Net::Snort::Parser::Rule;
package Walleye::Rule;

use Walleye::AdminUtils;

use Exporter;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT);

$VERSION = (qw($Revision: 1.21 $))[1];
@ISA    = qw(Exporter);
@EXPORT = qw(parse_rule test_rule make_replace build_rule);

my $DEBUG = 0;

my $rule = '# alert tcp $EXTERNAL_NET any -> $HOME_NET 32771:34000 (msg:"RPC kcms_server directory traversal attempt"; flow:to_server,established; content:"|00 00 00 00|"; offset:8; depth:4; content:"|00 01 87 7D|"; offset:16; depth:4; byte_jump:4,20,relative,align; byte_jump:4,4,relative,align; content:"/../"; distance:0; reference:cve,CAN-2003-0027; reference:url,www.kb.cert.org/vuls/id/850785; classtype:misc-attack; sid:2007; rev:5;)';

my @actions   = qw(alert drop log pass reject sdrop);
my @protocols = qw(ip tcp udp icmp);

my $ACTION_RE = join ("|", @actions);
my $PROTO_RE  = join ("|", @protocols);

my $PORT_RE     = "[:\\d]+";
my $VARIABLE_RE = '\$[\w_]+';
my $IP_RE       = '\d+\.\d+\.\d+\.\d+(?:\/\d+)*|\[[^\]]*\]';

my $VAR_RE = "!??" . join ("|", $PORT_RE, $VARIABLE_RE, $IP_RE, 'any');
my $DIR_RE = "->|<>";
my $CONTENT_RE = "\\((.*)\\)\\s*\$";

my $RULE_RE =
  "^\\s*[#]??\\s*($ACTION_RE)\\s+($PROTO_RE)\\s+"
  . "($VAR_RE)\\s+($VAR_RE)\\s+($DIR_RE)\\s+($VAR_RE)\\s+($VAR_RE)"
  . "\\s+$CONTENT_RE\\s*\$";

my %fields = (
    rule => undef,
);

my %options;
#$options{'random'} = "true";

my %optomizable = map { $_, 1} qw (dsize flags flow fragbits icmp_id icmp_seq icode id ipopts ip_proto itype seq session tos ttl ack window resp sameip stateless);

sub new {
    my $that  = shift;
    my $class = ref($that) || $that;
    my $self  = {
#        _permitted => \%fields,
        %fields,
    };

    bless $self, $class;

    if (@_) {
        my %conf = @_;
        while (my ($k, $v) = each %conf) {
            $self->$k($v);
        }
    }

    return $self;
}

sub AUTOLOAD {
    my $self = shift;
#    my $type = ref($self) || die "$self is not an object";
    my $name = $AUTOLOAD;

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

sub self_or_default {
    return @_ if defined($_[0]) && (!ref($_[0])) && ($_[0] eq 'Walleye::Rule');

    # slightly optimized for common case
    unless (defined($_[0])
        && (ref($_[0]) eq 'Walleye::Rule' || UNIVERSAL::isa($_[0], 'Walleye::Rule')))
    {
        my $q = Walleye::Rule->new;
        unshift (@_, $q);
    }
    return wantarray ? @_ : $q;
}

#sub self_or_default {
#    return @_ if defined($_[0]) && (!ref($_[0])) && ($_[0] eq 'Net::Snort::Parser::Rule');

    # slightly optimized for common case
#    unless (defined($_[0])
#        && (ref($_[0]) eq 'Net::Snort::Parser::Rule' || UNIVERSAL::isa($_[0], 'Net::Snort::Parser::Rule')))
#    {
#        my $q = Net::Snort::Parser::Rule->new;
#        unshift (@_, $q);
#    }
#    return wantarray ? @_ : $q;
#}

sub parse_rule {
    my ($self, @p) = self_or_default(@_);
    my ($rule) = (@p);

    my $original = $rule;
    my %rule;

    if ($rule =~ s/^\s*\#\s*//) {
        $rule{'state'} = 0;
    } else {
        $rule{'state'} = 1;
    }

    if ($rule =~ /$RULE_RE/i) {
        $rule{'action'}    = $1;
        $rule{'protocol'}  = $2;
        $rule{'src'}       = $3;
        $rule{'srcport'}   = $4;
        $rule{'direction'} = $5;
        $rule{'dst'}       = $6;
        $rule{'dstport'}   = $7;
        $rule{'_rest'}     = $8;
    } else {
        warn "base rule failure\n" if ($DEBUG);
        return undef;
    }

    my $contentid = 0;
    my $optionid  = 0;
    my $flow;
    my $options = parse_options($rule{'_rest'});
    # if rule option parsing failed, then pass the bitch up.
    if ($rule{'_rest'} && !defined($options)) {
        return (failed("parse options failed"));
    }
    $rule{'minimum_version'} = 200;
    foreach my $o (@$options) {
        my $option = $o->{'keyword'};
        my $args = $o->{'value'};
        if (!defined($option)) {
            return (failed("parse options failed, no option"));
        }
        if ($option eq 'msg') {
            if (defined($rule{'name'})) {
                return (failed("duplicate msg"));
            }
            $args =~ s/^\s*"(.*)"\s*$/$1/;
            if ($args =~ /[();:]/) {
                return (failed("using (, ), :, or \" in msg, not suggested"));
            }
            $rule{'name'} = $args;
        } elsif ($option eq 'reference') {
            my ($type, $value) = split(/,/,$args,2);
            if (defined($rule{'references'}{$type}{$value})) {
                return (failed("duplicate reference"));
            }
            $rule{'references'}{$type}{$value}++;
        } elsif ($option eq 'classtype') {
            if (defined($rule{'classification'})) {
                return (failed("duplicate classtype"));
            }
            $rule{'classification'} = $args;
        } elsif ($option eq 'sid') {
            if (defined($rule{'sid'})) {
                return (failed("duplicate sid"));
            }
            if ($args !~ /^\d+$/) {
                return (failed("invalid sid"));
            }
            $rule{'sid'} = $args;
        } elsif ($option eq 'rev') {
            if (defined($rule{'revision'})) {
                return (failed("duplicate rev"));
            }
            if ($args !~ /^\d+$/) {
                return (failed("invalid rev"));
            }
            $rule{'revision'} = $args;
        } elsif ($option eq 'content' || $option eq 'uricontent') {
            $optionid++;
            $contentid = $optionid;
            
            if ($args =~ s/^\s*!//) {
                $rule{'options'}{$optionid}{'not'} = 1;
            }

            $args =~ s/^"(.*)"$/$1/;
            my $content = parse_content($args);
            if (!defined($content) || !length($content)) {
                return (failed("invalid content"));
            }
            
            $rule{'options'}{$optionid}{'original'} = $args;
            $rule{'options'}{$optionid}{'string'} = $content;
            #$rule{'options'}{$optionid}{'optomized'} = make_optomize($content);
            $rule{'options'}{$optionid}{'optomized'} = $args;
            #warn "GOT  " . make_optomize($content);
            #warn "GOT2 " . $content;
            $rule{'options'}{$optionid}{'type'} = $option;
        } elsif ($option =~ /^(depth|offset)$/) {
            if ($contentid eq 0) {
                return (failed("$option specified before content"));
            }
            if (defined($rule{'options'}{$contentid}{'relative'})
                && $rule{'options'}{$contentid}{'relative'} eq 1) {
                return (failed("relative & non-relative content at the same time"));
            }
            if ($option eq 'depth') {
                if ($args < length($rule{'options'}{$contentid}{'string'})) {
                    return (failed("content won't fit in space defined"));
                    return undef;
                }
                $rule{'options'}{$contentid}{'depth'} = $args;
            } else {
                $rule{'options'}{$contentid}{'offset'} = $args;
            }
            $rule{'options'}{$contentid}{'relative'} = 0;
        } elsif ($option =~ /^(distance|within)$/) {
            if ($contentid eq 0) {
                return (failed("$option specified before content"));
            }
            if (defined($rule{'options'}{$contentid}{'relative'})
                && $rule{'options'}{$contentid}{'relative'} eq 0) {
                return (failed("relative & non-relative content at the same time"));
            }

            if ($option eq 'within') {
                if ($args < length($rule{'options'}{$contentid}{'string'})) {
                    return (failed("content won't fit in space defined"));
                    return undef;
                }
                $rule{'options'}{$contentid}{'depth'} = $args;
            } else {
                $rule{'options'}{$contentid}{'offset'} = $args;
            }
            $rule{'options'}{$contentid}{'relative'} = 1;
        } elsif ($option eq 'nocase') {
            if ($contentid eq 0) {
                return (failed("$option specified before content"));
            }
            $rule{'options'}{$contentid}{'nocase'} = 1;
        } elsif ($option =~ /^(byte_test|byte_jump)$/) {
            $optionid++;
            $rule{'options'}{$optionid}{'args'} = $args;
            $rule{'options'}{$optionid}{'type'} = $option;
        } elsif ($option =~ /^flow$/) {
            if ($flow) {
                return(failed("flow being used with stateless"));
            }
            $optionid++;
            if ($rule{'protocol'} !~ /tcp/) {
                return (failed("flow on non-tcp rule"));
            }
            $rule{'options'}{$optionid}{'original'} = $args;
            foreach my $opt (
                qw(to_server from_server to_client from_client established no_stream stateless only_stream)
            ) {
                if ($args =~ s/$opt//i) {
                    $rule{'options'}{$optionid}{'args'}{$opt} = 1;
                }
            }
            $rule{'options'}{$optionid}{'type'} = 'flow';
            $flow++;
        } elsif ($option =~ /^(itype|icode)$/) {
            $optionid++;
            $rule{'options'}{$optionid}{'args'} = $args;
            $rule{'options'}{$optionid}{'type'} = $option;
            if ($args =~ /(<|>)/) {
                minimum_version(\%rule, 210);
            }
        } elsif ($option =~ /^stateless$/) {
            $optionid++;
            if ($flow) {
                return(failed("stateless being used with flow"));
            }
            $rule{'options'}{$optionid}{'type'} = 'flow';
            $rule{'options'}{$optionid}{'original'} = 'stateless';
            $rule{'options'}{$optionid}{'args'}{'stateless'}++;
            minimum_version(\%rule, 200);
            $flow++;
        } else {
            $optionid++;
            $rule{'options'}{$optionid}{'args'} = $args;
            $rule{'options'}{$optionid}{'type'} = $option;
            if ($option =~ /^(flowbits)$/) {
                minimum_version(\%rule, 211);
            } elsif ($option =~ /^(threshold|pcre|isdataat)$/) {
                minimum_version(\%rule, 210);
            }
        }
    }
    if ($rule{'protocol'} =~ /^tcp$/i & !$flow) {
        return (failed("tcp rules must have flow or stateless"));
    }
    delete($rule{'_rest'});
    $rule{'original'} = $original;
    return (\%rule);
}

sub minimum_version {
    my ($rule, $version) = @_;
   
    if (defined($rule->{'minimum_version'})) {
        $rule->{'minimum_version'} = $version if ($rule->{'minimum_version'} < $version);
    } else {
        $rule->{'minimum_version'} = $version;
    }
}

# lets emulate the bad juju that snort's parser implements!
sub parse_content {
    my ($content) = @_;
    my $end   = "";
    my $hex2a = "";

    my $hexmode = 0;
    my (@content) = unpack("c*", $content);
    my $string;
    while (@content) {
        my $s = chr(shift (@content));

        if ($s eq "|" && $hexmode eq 0) {
            $hexmode++;
            next;
        }

        if ($s eq "|" && $hexmode eq 1) {
            $hexmode = 0;
            next;
        }

        # if I'm backticked...
        $s = chr(shift (@content)) if ($s eq '\\');

        if ($hexmode) {

            # skip spaces in hexmode
            $s = chr(shift (@content)) while ($s eq ' ');
            my $hex = $s;

            if ($s eq '|') {
                $hexmode = 0;
                next;
            }

            #grab the next one...
            $s = chr(shift (@content));

            # skip spaces in hexmode
            $s = chr(shift (@content)) while ($s eq ' ');

            warn "specified hex foo is too short\n" if ($DEBUG && $s eq '|');
            return undef if ($s eq '|');

            # die "Invalid rule..." if ($s eq '|');

            $hex .= $s;

            $s = chr(hex($hex));
        }
        $string .= $s;
    }

    # if we are still in hexmode, then the content string isn't valid...
    warn "hexmode isn't closed at end of content\n" if ($DEBUG && $hexmode);
    return undef if ($hexmode);
    return ($string);
}

sub parse_options {
    my ($option) = @_;
    my $quoted = 0;
    my $keyword = 1;

    my $keyword_string = "";
    my $option_string = "";

    my (@content) = unpack("c*", $option);
    my (@options);

    while (@content) {
        my $s = chr(shift (@content));
            
        if ($s eq ':') {
            $keyword = 0;
            while (1) {
                $s = chr(shift (@content));
                last if ($s ne ' ');
                last if (!@content);
            }
        }
        
        if ($keyword) {
            next if ($s eq ' ');

            if ($s eq ";") {
                push (@options,{keyword => $keyword_string});
                $keyword_string = "";
                $keyword = 1;
                next;
            }

            if ($keyword !~ /\w/) {
                warn "KEYWORD NOT ALPHA!" if ($DEBUG);
                return undef;
            }

            $keyword_string .= $s;
        } else {

            if ($s eq '"' && $quoted eq 0) {
                $quoted = 1;
            } elsif ($s eq '"' && $quoted eq 1) {
                $quoted = 0;
            } elsif ($s eq '\\') {
                $option_string .= $s; # if ($quoted);
                $s = chr(shift (@content));
            } elsif (!$quoted && $s eq ";") {
                push (@options,{keyword => $keyword_string, value => $option_string});
                $keyword_string = undef;
                $option_string = undef;

                $keyword = 1;
                next;
            }

            # if I'm not in quote mode, undo backticks.
            $option_string .= $s;
        }
    }

    # if we are still in quoted mode, then the options arn't valid...
    warn "quoted string didn't end ($option)\n" if ($DEBUG && $quoted);
    return undef if ($quoted);
    return (\@options);
}

sub test_rule {
    require Data::Dumper;
    print Data::Dumper::Dumper(parse_rule($rule));
}

sub make_hex {
    my ($string) = @_;
    my @contents;
    foreach my $c (unpack('C*', $string)) {
        push (@contents, sprintf('%2.2X', $c));
    }
    return (join (" ", @contents));
}

# yes, I know... the misspeeling is done on purpose.  its just a thing you see.
sub make_optomize {
    my ($string) = @_;

    my @hex;
    my $output;
    while (1) {
        my $c = substr($string,0,1,"");
        last if (!length($c));
        if ($c =~ /[\0-\37\42-\44\050\051\134\174\072\073\177-\377]/) {
            push (@hex, sprintf('%2.2X', unpack("C",$c)));
        } else {
            if (@hex) {
                $output .= "|" . join(" ",@hex) . "|";;
                @hex = ();
            }
            $output .= $c;
        }
    }
    if (@hex) {
        $output .= "|" . join(" ",@hex) . "|";;
    }
    return ($output);
}

sub failed {
    my ($string) = @_;
    my %rule = ( failed => $string);
    return (\%rule);
}

sub make_generic {
	my ($self, @p) = self_or_default(@_);
   my ($type, $rule) = @p;
   $rule->{'action'} = $type;
   return ($rule);
}

sub make_replace {
	my ($self, @p) = self_or_default(@_);
   my ($type, $rule) = @p;

   my $did;
   foreach my $id (sort { $a <=> $b } keys %{$rule->{'options'}}) {
       if ($rule->{'options'}->{$id}->{'type'} eq 'content') {
           my $string;
           for (my $i = 0 ; $i < length($rule->{'options'}->{$id}->{'string'}) ; $i++) {
               if (!defined($options{'random'})) {
                   $string .= chr(int(rand(255)));
               } else {
                   $string .= "\xff";
               }
           }

           $rule->{'options'}->{$id}->{'replace'} = $string;
           $did++;
       }
   }

   warn "Tried adding replace to $rule->{'sid'}.  No contents\n"
     if (!$did && $options{'verbose'});

   return ($rule);
}

sub build_rule {
	my ($self, @p) = self_or_default(@_);
   my ($rule, $remove_replace) = @p;

   my (@opts);

   my $show_rule;
#   if ($options{'honeynet'}) {
 #     my $src = $rule->{'src'};
#      my $dst = $rule->{'dst'};
#      if ($src =~ /^\$/ && $dst =~ /^\$/) {
#         $rule->{'dst'} = $src;
#         $rule->{'src'} = $dst;
#      } elsif ($options{'verbose'}) {
#         $show_rule++ if ($options{'verbose'} > 1);
#         warn "Did not switch $rule->{'sid'}.  Doesn't use variables.\n";
#      }
#   }
   my $header = join (
      " ",                 $rule->{'action'},
      $rule->{'protocol'}, $rule->{'src'},
      $rule->{'srcport'},  $rule->{'direction'},
      $rule->{'dst'},      $rule->{'dstport'}
   );

   
   foreach my $id (sort { $a <=> $b } keys %{$rule->{'options'}}) {
       my $type = $rule->{'options'}->{$id}->{'type'};
       if (!defined($type)) {
           require Data::Dumper;
           die "Undefined type for $rule->{'sid'}:\n" .  Data::Dumper::Dumper($rule);
       }

       if ($type eq 'content' || $type eq 'uricontent') {
           my $content = $rule->{'options'}->{$id}->{'optomized'};
           die "no content: sid $rule->{'sid'}: $content" if !length($content);

           if ($rule->{'options'}->{$id}->{'not'}) {
               push (@opts, "$type:!\"$content\";");
           } else {
               push (@opts, "$type:\"$content\";");
           }

           if ($rule->{'options'}->{$id}->{'relative'}) {
               if ($rule->{'options'}->{$id}->{'depth'}) {
                   push (@opts, "within:$rule->{'options'}->{$id}->{'depth'};");

                   # here, we see if exists as well as is non 0, since distance
                   # 0 with a within is a noop.
                   if ($rule->{'options'}->{$id}->{'offset'}) {
                       push (@opts, "distance:$rule->{'options'}->{$id}->{'offset'};");
                   }
               } elsif (defined($rule->{'options'}->{$id}->{'offset'})) {
                   push (@opts, "distance:$rule->{'options'}->{$id}->{'offset'};");
               } 
           } else  {
               if ($rule->{'options'}->{$id}->{'depth'}) {
                   push (@opts, "depth:$rule->{'options'}->{$id}->{'depth'};");

                   # here, we see if exists as well as is non 0, since distance
                   # 0 with a within is a noop.
                   if ($rule->{'options'}->{$id}->{'offset'}) {
                       push (@opts, "offset:$rule->{'options'}->{$id}->{'offset'};");
                   }
               } elsif (defined($rule->{'options'}->{$id}->{'offset'})) {
                   push (@opts, "offset:$rule->{'options'}->{$id}->{'offset'};");
               }
           }

           if ($rule->{'options'}->{$id}->{'replace'}) {
               my $replace = make_hex($rule->{'options'}->{$id}->{'replace'});
               push (@opts, "replace:\"|$replace|\";");
           }

           if ($rule->{'options'}->{$id}->{'nocase'}) {
               push (@opts, "nocase;");
           }
		} elsif($type eq 'replace' && $remove_replace) {
			# Do nothing as we don't want to push replace to the array list
       } elsif ($type eq 'flow') {
           unshift (@opts, "flow:" . join(",",sort keys %{$rule->{'options'}->{$id}->{'args'}}) . ";");
       } elsif (defined($rule->{'options'}->{$id}{'args'})) {
           if (defined $optomizable{$type}) {
               unshift(@opts, "$type:$rule->{'options'}->{$id}{'args'};");
           } else {
           push (@opts, "$type:$rule->{'options'}->{$id}{'args'};");
           }
       } else {
           if (defined $optomizable{$type}) {
               unshift (@opts, "$type;");
           } else {
               push (@opts, "$type;");
           }
       }
   }
   
   
   my $msg = $rule->{'name'};
   $msg =~ s/([\\:;\(\)])/\\$1/g;
   unshift (@opts, "msg:\"$msg\";");
 
   if ($rule->{'references'}) {
       foreach my $ref_type (sort {$a cmp $b} keys % { $rule->{'references'} } ) {
           foreach my $ref (sort {$a cmp $b} keys % { $rule->{'references'}->{$ref_type} }) {
               push (@opts, "reference:$ref_type,$ref;");
           }
       }
   }

   if ($rule->{'classification'}) {
       push (@opts, "classtype:$rule->{'classification'};");
   }
  
   push (@opts, "sid:$rule->{'sid'};") if (defined($rule->{'sid'}));
   push (@opts, "rev:$rule->{'revision'};");

   my $string = $header . " (" . join (" ", @opts) . ")";
   if (!$rule->{'state'}) {
      $string = "# " . $string;
   }
#   use Data::Dumper;
#   $Data::Dumper::Sortkeys++;
#   print Dumper($rule);
   warn "$string\n" if ($show_rule);
   return ($string);
}



1;
