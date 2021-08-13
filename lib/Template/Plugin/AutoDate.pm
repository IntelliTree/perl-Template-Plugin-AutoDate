package Template::Plugin::AutoDate;
use strict;
use warnings;
use parent 'DateTime';
use Try::Tiny;
use DateTime::Format::Flexible;

# ABSTRACT: Enhance Template Toolkit with easy access to DateTime and DateTime::Format::Flexible
# VERSION

=head1 SYNOPSIS

  [% USE AutoDate %]
  
  Yesterday was [% AutoDate.now.subtract(days => 1).ymd("-") %]
  The record is from month [% AutoDate.coerce(foo.bar.datestring).month_name %]
  
  [% USE y2k= AutoDate(year => 2000, month => 1, day => 1) %]
  
  [% datestring= "2016-01-01" %]
  [% datestring.strftime("%M/%d") %]
  [% datestring.coerce_date.year %]

=head1 DESCRIPTION

This module allows you to access the full power of L<DateTime> from within
Template Toolkit.  Since you don't always have date objects, it also allows
you to coerce arbitrary strings into DateTime using L<DateTime::Format::Flexible>.

When you use this plugin, it installs two vmethods into your current Template
context:

=over

=item coerce_date

This can be called on any scalar, and it will parse the scalar with
L<DateTime::Format::Flexible>.  It returns undef if the string cannot be
parsed, allowing you to continue chaining calls on it and get TT's behavior
for undefined values.

If called on an actual DateTime object, it returns the DateTime object
un-altered.

=item strftime

When called on a scalar, this coerces it to a DateTime, and if defined, then
calls the ".strftime" method on it.  This means you can now call "strftime"
on any date field you like regardless of whether it's been inflated to a
DateTime object by your controller.

=back

It also provides an object (which inherits from DateTime) which you can call
methods on.

=cut

# The moment the user *loads* this plugin, we inject 2 vmethods into the context.
sub load {
   my ($class, $context)= @_;
   
   # Allow .strftime(format) to be called on any scalar that parses as a datetime
   $context->define_vmethod('scalar', 'strftime', \&_loose_strftime);

   # Create .coerce_date method to coerce things into DateTime objects
   $context->define_vmethod($_, 'coerce_date', \&_coerce_datetime)
      for qw( scalar hash array );
   
   return $class;
}

=head1 METHODS

=head2 new

  [% USE AutoDate %]
  [% USE x = AutoDate(@args) %]

The first form of using the Autodate module gives you a variable named
Autodate which is a subclass of DateTime containing the value of 'now'.
(Since it is a DateTime, you may modify its contents! so there is no
guarantee that it still holds the value of 'now'.)  The primary purpose
here is to be able to call the static class methods of DateTime, which
can be called on an object just as well as a package name.
(Template toolkit plugins do not have the option of returning a package
name, and must return a blessed object.)

In the second form, it calls the DateTime constructor with the arguments
of your choice, returning a named date object.

=cut

sub new {
   #my ($class, $context, @args)= @_;
   
   # Black magic here.  The Template::Plugin expects to create a new instance
   # of the plugin when the user says [% USE AutoDate %], but DateTime can't
   # create instances without arguments like 'year' and etc.  So, translate
   #   [% USE AutoDate %]
   # into
   #   DateTime->now
   # but translate
   #   [% USE d = AutoDate( year => 1900, month => 1, day => 1 ) %]
   # as
   #   DateTime->new( year => 1900, month => 1, day => 1 )
   
   # Allow user to call 'new' directly, but checking the $context param
   splice(@_, 1, 1)
      if (defined $_[1] && ref($_[1]) && ref($_[1])->can('define_vmethod'));
   # If no arguments, return "now"
   goto &DateTime::now unless @_ > 1;
   goto &DateTime::new;
}

sub now {
   # If called on an object, rearrange it to be called on the package
   splice(@_, 0, 1, ref $_[0]) if ref $_[0];
   goto &DateTime::now;
}

=head2 coerce

  [% AutoDate.coerce("January 1, 2000") %]

This class method is a shortcut to L<DateTime::Format::Flexible/parse_datetime>.
Returns empty string if the date can't be parsed.

=cut

sub coerce { _coerce_datetime($_[1]) }

=head2 now_local

  [% AutoDate.now_local %]

Returns C<< DateTime->now(time_zone => "local") >>

=cut

sub now_local { DateTime->now(time_zone => 'local') }

=head2 now_floating

  [% AutoDate.now_floating %]

Returns C<< DateTime->now(time_zone => "local")->set_time_zone("floating") >>,
which results in a floating DateTime that contains local time.

=cut

sub now_floating { DateTime->now(time_zone => 'local')->set_time_zone('floating') }

sub _coerce_datetime {
   my $thing= shift;
   return '' unless defined $thing;
   return $thing if ref $thing && ref($thing)->isa('DateTime');
   return eval { DateTime::Format::Flexible->parse_datetime($thing) } || '';
}

sub _loose_strftime {
   my ($value, $format)= @_;
   $value= _coerce_datetime($value)
      unless ref $value && ref($value)->can("strftime");
   return $value? $value->strftime($format) : undef;
}

1;
