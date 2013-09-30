#!/usr/bin/perl
# 20130710/JT
# The script creates an RSS feed from http://www.cinemateket.no/program
# and drops is as rss.xml-file into the current directory.
# 
# Due to the nature of the cinemateket site, the script will grep all linked movies and extract the dates
# from there, reorder them and then create the RSS.
#
# Based on: http://www.perl.com/pub/2001/11/15/creatingrss.html
# Based on: http://search.cpan.org/~kellan/XML-RSS-1.02/lib/RSS.pm

use strict;
use LWP::Simple;    
use HTML::TokeParser;
use XML::RSS;
use DateTime;
use utf8;
use Switch;
use 5.10.1;

# Calculate Date acc. RFC822
our $lastbuilddate = DateTime->now()->strftime("%a, %d %b %Y %H:%M:%S %z");
our $pubdate = DateTime->now()->strftime("%a, %d %b %Y 00:00:01 %z");

# First - LWP::Simple.  Download the page using get();.
my $content = get( "http://www.cinemateket.no/program" ) or die $!;

# Second - Create a TokeParser object, using our downloaded HTML.
my $stream = HTML::TokeParser->new( \$content ) or die $!;

# Finally - create the RSS object. 
#my $rss = XML::RSS->new( version => "2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom" );
my $rss = XML::RSS->new( version => '2.0' );

# Declare variables
my ($tag);
my (@movieurls);

# Prep the RSS.
$rss->channel(
    title        => "Cinemateket Kino Program",
    link         => "http://www.cinemateket.no/program",
    language     => 'nb',
        generator    => 'rsscinemateket.pl',
        docs         => 'http://cyber.law.harvard.edu/rss/rss.html',
        managingEditor => 'cinemateket@nfi.no (www.cinemateket.no)',
        webmaster    => 'rss@micronarrativ.org',
    pubdate      => $pubdate,
    lastBuildDate   => $lastbuilddate,
    description  => "Cinemateket Kino Program from www.cinemateket.no. This RSS is not created by Cinemateket or the Norwegian Film-Institute.");

#our @twoWeeks = (1..14);
my $dt;

# Now get me all the movie URLS from the page, ALL I said!

while ( $tag = $stream->get_tag("div") ) {
    if ( $tag->[1]{class} = 'event' ) {
        $tag = $stream->get_tag("a");
        if ( $tag->[1]{href} =~ /http\:\/\/www\.cinemateket\.no\/\d{6}\/\w+/) { # Drop all non-movie urls
            
            # Drop double entries and only write down the unique ones.
            if ( !  grep { $_ eq $tag->[1]{href} } @movieurls) {
                push(@movieurls,$tag->[1]{href});
            }
        }
    }
}

my $movieurls = @movieurls;
say "number of movies: " . $movieurls;

# Now go through the URLS and grep the content and create an rss for each entry

foreach (@movieurls) {
    
    # Variables for meta-data from the sub-pages
    our (
        $movietitle,
        $moviepicurl,
        $moviestory,
        $movieoriginaltitle,
        $movieproduced,
        $movienationality,
        $movieregi,
        $movielanguage,
        $moviesubs,
        $movieplaytime,
        $movieactors,
        $moviesiteurl
        );
    my @movieplaydates;
    
    $content = get( $_ ) or die $!;
    $stream = HTML::TokeParser->new( \$content ) or die $!;
    $moviesiteurl = $_;

    # Movie title
    while ( $tag = $stream->get_tag("div") ) {
        last if ( $tag->[1]{class} =~ 'article' ) 
    }
    $tag = $stream->get_tag("h1");
    $movietitle = $stream->get_text();
    #say "movie title: " . $movietitle;


    # Movie Titel image
    $tag = $stream->get_tag("img");
    $moviepicurl = $tag->[1]{src};
    
    # Movie-meta-data
    # ( Original title, Produced, Nationality, Regi, Language, Subs, Playtime, Actors )
    while ($tag = $stream->get_tag("div") ) {
        last if ( $tag->[1]{class} =~ 'movie-meta' )
    }

    # This sub will be used in the meta-data a couple of times to parse the dt/dl structure
    sub moviemetacontent {
        $stream->get_tag("dd");
        #$stream->get_token();
        #$stream->get_token();
        #$stream->get_token();
        my $token = $stream->get_token();
        #return ($stream->get_text());
        return ($token->[1]);
    }

    $tag = $stream->get_tag("dt");    
    while ( my $token = $stream->get_token() ) {
        last if ($token->[1] eq 'p');        
                
        switch ( $token->[1] ){            
            case m/(original tittel:)/i { 
                $movieoriginaltitle = &moviemetacontent;
            }
            case m/nasjonalitet:/i {
                $movienationality = &moviemetacontent;
            }
            case m/produsert:/i {
                $movieproduced = &moviemetacontent;
            }
            case m/(original tittel:)/i { 
                $movieoriginaltitle = &moviemetacontent;
            }
            case m/nasjonalitet:/i {
                $movienationality = &moviemetacontent;
            }
            case m/produsert:/i {
                $movieproduced = &moviemetacontent;
            }
            case m/regi:/i {                
                $movieregi = &moviemetacontent;
            }
            case m/språk:/i {
                $movielanguage = &moviemetacontent;
            }
            case m/tekstet:/i {
                $moviesubs = &moviemetacontent;
            }
            case m/spilletid:/i {
                $movieplaytime = &moviemetacontent;
            }
            case m/med:/i {
                $movieactors = &moviemetacontent;
            }
            case m/regi:/i {                
                $movieregi = &moviemetacontent;
            }
            case m/språk:/i {
                $movielanguage = &moviemetacontent;
            }
            case m/tekstet:/i {
                $moviesubs = &moviemetacontent;
            }
            case m/spilletid:/i {
                $movieplaytime = &moviemetacontent;
            }
            case m/med:/i {
                $movieactors = &moviemetacontent;
            }            
       }
    }
        
    # Extract the Movie description
    $tag = $stream->get_tag("p");
    $moviestory = '';
    while (my $token = $stream->get_token() ) {
        last if ($token->[1] eq 'div');
        next if ($token->[1] eq 'p' );

        $token->[1] =~ s/br\//<br\/>/gi;        
        $token->[1] =~ s/ +/ /;
        $token->[1] =~ s/(strong|h2|h3)//gi;
        
        $moviestory .= $token->[1];
    }    
    

    # Get the movie dates
    # If there are no dates, there will on be a future showing of the movie, 
    # so we're gonna skip it.
    my $timestamp;
    while ( $tag = $stream->get_tag("div") ) {
        last if ($tag->[1]{class} eq 'visninger');
    }
    my $token = $stream->get_token();
    $token = $stream->get_token();
    # If the headline is here, there're are future showings
    
    if ( $token->[1] eq 'h2' ) {
        
        # Loop until you see an h3-tag
        while ( my $token2 = $stream->get_token() ) {
            last if ( $token2->[1] eq 'h3' );
            
            # Get the day
            $tag = $stream->get_tag("dt");
            $timestamp = $stream->get_text();
            
            # Get the time and location
            $tag = $stream->get_tag("span"),
            $timestamp .= ' ' . $stream->get_text();
            push (@movieplaydates,$timestamp);
            
            # Hint:
            # if you want to add the download of the vcal information, drop everything in a hash
            # and loop through that one instead.
            
            # Next timestamp
            next;
        }
        
    } else {
        next;
    }
    
    
    # Now that we've got all the information, we need to put everything in an RSS object
    # Remember: The loop you're currently in is per movie.
    foreach (@movieplaydates) {
        if  ($_=~ m/^(?<weekday>\w+)\s(?<day>\d{1,2})\.(?<month>\d{1,2})\.(?<year>\d{4})\s(?<location>\w+)\s(?<hour>\d{2})\.(?<minutes>\d{2})/i ) {            
             
            my $dt = DateTime->new(
                year => $+ {year},
                month => $+{month},
                day => $+{day},
                hour => $+{hour},
                minute => $+{minutes},
                second => 00,                
            );
             my $moviedate;
            $moviedate = $dt->day_abbr() .
                 ', ' .
                 $dt->day() . 
                 ' ' . 
                 $dt->month_abbr() . 
                 ' ' . 
                 $dt->year() .
                 ' ' .
                 $dt->hour() .
                 ':00' . 
                 #$dt->minute() .
                 ':00' .
                 #$dt->second() .
                 ' GMT';
            
            my $moviepiclinkurl = '<a href="'
              . $moviesiteurl
              . '"><img src="'
              . $moviepicurl
              . '" width="80" alt="'
              . $movietitle
              .'" align="top" hspace="5"></a>';     
            
            # Build the description text
            my $moviedescription = $moviepiclinkurl
                . $moviestory
                . '<br/><br/> '
                . 'Når: ' . $dt->year() . '-' .sprintf("%02d",$dt->month()) . '-' . sprintf("%02d",$dt->day()) . ', ' . sprintf("%02d",$dt->hour()) . ':' . sprintf("%02d",$dt->minute()) . '<br/>'
                . 'Hvor: ' . $+{location}
                . '<br/><br/> '
                . 'Filmfakta: <br/>'
                . '------<br/>'
                . (( $movieoriginaltitle ne '' ) ? 'Original tittel: ' . $movieoriginaltitle . '<br/>' : '' ) 
                . (( $movienationality ne '' )  ? 'Nasjonalitet: ' . $movienationality . '<br/>' : '' )
                . (( $movieproduced ne '' ) ? 'Year: ' . $movieproduced . '<br/>' : '' )
                . (( $movieregi ne '' ) ? 'Regi: ' . $movieregi . '<br/>' : '' )
                . (( $moviesubs ne '' ) ? 'Tekstet : ' . $moviesubs . '<br/>' : '' )
                . (( $movieplaytime ne '' ) ? 'Spilletid: ' . $movieplaytime . '<br/>' : '' )
                . (( $movieactors ne '' ) ? 'Skuspiller: ' . $movieactors . '<br/>' : '') 
                . '';
                
            # Event title for RSS element
            my $rsslementtitle = $movietitle . ', ' . $dt->year() . '.' . sprintf("%02d",$dt->month()) . '.' . sprintf("%02d",$dt->day()) . ' , ' . sprintf("%02d",$dt->hour()) . ':' . sprintf("%02d",$dt->minute());
            
            $rss->add_item(
                
                title       => $rsslementtitle,
                link        => $moviesiteurl,
                #permaLink   => $moviesiteurl,
                description => $moviedescription,
                pubDate     => $moviedate,
                
            );     
        } # End of IF-Condition
        
    } # End of ForEach-loop (movie-date-loop)
    
    # Reset the movie-metadata variables
    undef $movietitle;
    undef $moviepicurl;
    undef $moviestory;
    undef $movieoriginaltitle,
    undef $movieproduced;
    undef $movienationality;
    undef $movieregi;
    undef $movielanguage;
    undef $moviesubs;
    undef $movieplaytime,;
    undef $movieactors;
    undef $moviesiteurl;
    
} # End of Movie-Loop

# Save the rss
$rss->save("cinemateket_program.rss");

# Todo
# Create a calendar entry for each time to download - jeezzz. I'm lazy