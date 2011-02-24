#!/usr/bin/perl
use strict;	# Enforce some good programming rules

#####
#
#	rewrapWav.pl
#	version:	1.1
#	created:	2011-02-22
#	modified:	2011-02-23
#	author:		Theron Trowbridge
#
#	description:
#		create WAVE file with clean header, and no extraneous chunks
#	
#	syntax:
#		rewrapWav.pl <input.wav>
#
#		accepts glob arguments (i.e., "rewrapWav.pl *.wav")
#
#	output:
#		creates new file named input_rewrap.wav
#	
#####


# variables/constants

my ( $input_file, $basename, $output_file );
my ( $result, $header, $buffer );
my ( $chunk_id, $chunk_size, $format );
my ( $sub_chunk_1_id, $sub_chunk_1_size, $audio_format );
my ( $num_channels, $sample_rate, $byte_rate, $block_align, $bits_per_sample );
my ( $sub_chunk_2_id, $sub_chunk_2_size );
my ( $file_size, $file_error, $bytes_read );
my ( $total_output_file_size, $output_file_chunk_size );
my $output_file_sub_chunk_1_size = 16;
my $file_io_size = 1024 * 1024;		# how much to read in copy operation - default 1 MiB


# subroutines

#	short_value()
#	convert argument into little-endian unsigned short
sub short_value {
	return( unpack( "S<", $_[0] ) );
}

#	long_value()
#	convert argument into little-endian unsigned long
sub long_value {
	return( unpack( "L<", $_[0] ) );
}

# find_chunk( $find_chunk_id )
# find specified RIFF chunk in the INPUT_FILE
# returns the size of the chunk data (as per the header)
# leaves file positioned at first byte of chunk data
sub find_chunk {
	my ( $result, $buffer, $result, $read_chunk_id, $read_chunk_size );
	my $find_chunk_id = $_[0];
	my $done = 0;
		
	seek( INPUT_FILE, 12, 0 );			# skip past the end of the header
		
	while ( !$done ) {
		$result = read ( INPUT_FILE, $buffer, 8 );
		if ( $result eq 0 ) {			# end of file
			seek ( INPUT_FILE, 0, 0 );	# rewind file
			return( 0 );			# return 0, which will indicate an error
		}
		
		$read_chunk_id = substr( $buffer, 0, 4 );
		$read_chunk_size = long_value( substr( $buffer, 4, 4 ) );
		
		if ( $read_chunk_id eq $find_chunk_id ) { return( $read_chunk_size ); }	# return chunk size
		else { seek( INPUT_FILE, $read_chunk_size, 1 ); }			# seek to next chunk		
	}
}


# main

# If no arguments passed, return usage string
if ( !$ARGV[0] ) { print "Usage: rewrapWav.pl <filename>\n"; }

# Otherwise, parse through each argument passed and try to convert it
foreach $input_file (@ARGV) {
	# figure out ouptput file name
	$basename = $input_file;
	$basename =~ s/\.[^.]+$//;	# lop off everything from the last period on
	$output_file = $basename . "_rewrapped.wav";
	## this will overwrite another _rewrapped.wav file if it exists
	## maybe test for -e and add tempdate if necessary to avoid overwrite?
	
	# open input file and check for errors
	$file_error = open( INPUT_FILE, "<", $input_file );
	if ( $file_error == undef ) {
		warn "Error: opening $input_file: $!\n\n";
		next;	# move on to next file
	}
	
	binmode( INPUT_FILE );			# treat file as a binary file
	$file_size = -s INPUT_FILE;		# get size of input WAVE file
	
	# parse WAVE header and find data chunk
	
	# first 12 bytes should be ChunkID, ChunkSize, and Format
	$file_error = read( INPUT_FILE, $header, 12 );
	if ( $file_error == undef ) {
		warn "Error: reading $input_file: $!\n\n";
		next;	# move on to next file
	}
	$chunk_id = substr( $header, 0, 4 );
	$chunk_size = long_value( substr( $header, 4, 4 ) );
	$format = substr( $header, 8, 4 );
	
	# ChunkID should be "RIFF"
	if ( $chunk_id ne "RIFF" ) {
		warn "Error: $input_file is not a WAVE file (no RIFF)\n\n";
		next;	# move on to next file
	}
	
	# ChunkSize + 8 should equal the total file size
	if ( ( $chunk_size + 8 ) ne $file_size ) {
		warn "Warning: ChunkSize is not correct\n"
		# continue on with this file anyway
	}
	
	# Format should be "WAVE"
	if ( $format ne "WAVE" ) {
		warn "Error: $input_file is not a WAVE file (no RIFF)\n\n";
		next;	# move on to next file
	}
	
	$sub_chunk_1_id = "fmt ";
	$sub_chunk_1_size = find_chunk( $sub_chunk_1_id );
	if ( $sub_chunk_1_size eq 0 ) {
		warn "Error: no fmt chunk\n";
		next;	# move on to next file
	}
	
	# Subchunk1Size is the amount we need to read for the remainder of the fmt sub chunk
	read( INPUT_FILE, $header, $sub_chunk_1_size );
	if ( $file_error == undef ) {
		warn "Error: reading file $input_file: $!\n\n";
		next;	# move on to next file
	}
	
	# parse fmt sub chunk into header values
	$audio_format = short_value( substr( $header, 0, 2 ) );
	$num_channels = short_value( substr( $header, 2, 2 ) );
	$sample_rate = long_value( substr( $header, 4, 4 ) );
	$byte_rate = long_value( substr( $header, 8, 4 ) );
	$block_align = short_value( substr( $header, 12, 2 ) );
	$bits_per_sample = short_value( substr( $header, 14, 2 ) );
	
	# go find the data chunk
	$sub_chunk_2_id = "data";
	$sub_chunk_2_size = find_chunk( $sub_chunk_2_id );
	if ( $sub_chunk_2_size eq 0 ) {
		warn "Error: no data chunk\n";
		next;	# move on to next file
	}
	
	# figure out new output file size and chunk size
	$total_output_file_size = $sub_chunk_2_size + 44;
	$output_file_chunk_size = $total_output_file_size - 8;
	
	# open/create output file
	$result = open ( OUTPUT_FILE, ">", $output_file );
	if ( !$result ) {
		warn "Error: opening file $output_file: $!\n\n";
		next;	# move on to next file
	}
	binmode( OUTPUT_FILE );
	
	# write WAVE header to output file
	print OUTPUT_FILE "RIFF";
	print OUTPUT_FILE pack( 'L', $output_file_chunk_size );
	print OUTPUT_FILE "WAVE";
	print OUTPUT_FILE "fmt ";
	print OUTPUT_FILE pack( 'L', $output_file_sub_chunk_1_size );
	print OUTPUT_FILE pack( 'S', $audio_format );
	print OUTPUT_FILE pack( 'S', $num_channels );
	print OUTPUT_FILE pack( 'L', $sample_rate );
	print OUTPUT_FILE pack( 'L', $byte_rate );
	print OUTPUT_FILE pack( 'S', $block_align );
	print OUTPUT_FILE pack( 'S', $bits_per_sample );
	
	## yeah, I know I am unpacking and then packing most of these
	## so this could be simplified somewhat
	## but this isn't slowing things down too much so I'm OK with it
	
	# write data chunk header
	print OUTPUT_FILE "data";
	print OUTPUT_FILE pack( 'L', $sub_chunk_2_size );
	
	$bytes_read = read( INPUT_FILE, $buffer, $sub_chunk_2_size );
	## this is ugly - reading entire data chunk in one go
	## in some cases (resource-constrained machines) this could be a bad idea
	## ideally do in $file_io_size chunks
	## but need to track bytes written to keep from going over $sub_chunk_2_size
	## because we don't want to carry over any BWF chunks inadvertantly
	## and my original code assumed that the PCM data ran to end of file
	## which is safe when reading from a raw PCM file
	## make this change for next version
	if ( $bytes_read ne $sub_chunk_2_size ) {
		warn "Error: wrong number of bytes read from $input_file\n";
	}
	print OUTPUT_FILE $buffer;
		
	# close our files
	close ( INPUT_FILE );
	close ( OUTPUT_FILE );
}
