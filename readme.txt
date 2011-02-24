rewrapWav
Version 1.1
Created 2011-02-22
Modified 2011-02-23
Written by Theron Trowbridge


Description

PERL script to clean up WAVE files by stripping out extraneous RIFF chunks and re-forming the WAVE header.

Strips out any timing or BWF chunks and creates a standard WAVE header.


Usage

$ perl rewrapWav.pl <input.wav>

Works with glob operations (i.e., rewrapWav.pl *.wav) to operate on multiple WAVE files.


Output

Creates new file named input_rewrap.wav.


Known Issues

Currently attempts to read the entire data chunk (containing the audio data) in one read operation.  This should generally work, given the size of a typical WAVE file, but on a resource-constrained machine, memory could become an issue, particularly on larger files.
