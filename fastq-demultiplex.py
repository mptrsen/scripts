#!/usr/bin/env python3

"""
Demultiplex a FASTQ file by barcode. The input file can be gzip compressed or
not (determined by the file extension). The FASTQ header must be in Illumina
format with colon-separated fields, the last one of which contains the barcode
sequence.

Usage: fastq-demultiplex.py reads.fastq samples.csv

This script requires two arguments: 
(1) path to the FASTQ file
(2) path to the dictionary file

The dictionary file specifies which barcode belongs to which sample. It must be
in comma-separated text format, with each line looking like this:

    Sample1,CCGCGGTT

The script places the output files in the working directory. The output files
are named according to the sample names listed in the dictionary and are
deleted if they exist. Reads that could not be assigned to a sample (orphans)
are placed in an additional output file named "orphans.fq.gz". This means that
no sample must be named "orphans".
"""

import os   # OS calls
import sys  # variables such as ARGV
import gzip # read and write gzip'ed files
import csv  # parse CSV files

class Demultiplexer:
    """
    initiate by parsing the samples dictionary and cleaning up old outputs
    """
    def __init__(self, samplesfile):
        self.dict = self.parse_csv(samplesfile)
        self.clean_output_files(self.dict)
        self.num_records_written = { }
        for sample in self.dict.values():
            self.num_records_written[sample] = 0
        self.num_records_written["orphans"] = 0
        self.total_records_written = 0

    """
    parse CSV into a dictionary
    """
    def parse_csv(self, samplesfile):
        data = { }
        with open(samplesfile) as fh:
            file = csv.reader(fh)
            for row in file:
                data[row[1]] = row[0]
            return(data)

    """
    remove old output files, if they exist
    """
    def clean_output_files(self, dict):
        for sample in dict.values():
            try:
                os.remove(sample + ".fq.gz")
            except:
                pass # I don't care, if there is a problem it will show up again when writing to the file
        try:
            os.remove("orphans.fq.gz")
        except:
            pass

    """
    write one fastq record to an output file. the file name is constructed from
    the sample name + ".fq.gz" (gzipped).
    """
    def write_record(self, data, sample):
        # die if dataset incomplete
        if len(data) != 4:
            raise ValueError("Incomplete record with " + len(data) + "lines, expected 4 lines")
        # write record to output file
        outfile = sample + ".fq.gz"
        with gzip.open(outfile, 'a') as ofh:
            output_line = "\n".join(data) + "\n"
            ofh.write(output_line.encode('ascii'))
            ofh.close()
        # collect counts for report
        self.num_records_written[sample] += 1
        self.total_records_written += 1

    """
    demultiplex: split the header to extract the barcode,
    name the output file according to the barcode dictionary,
    and write the records to the output files
    """
    def demultiplex(self, fastqfile):
        # open FASTQ file
        if fastqfile.endswith(".fastq.gz") or fastqfile.endswith(".fq.gz"):
            fh = gzip.open(fastqfile, 'rb')
        elif fastqfile.endswith(".fastq") or fastqfile.endswith(".fq"):
            fh = open(fastqfile, 'rb')
        else:
            sys.exit("Unknown file format: " + fastqfile + ". I can read .fastq, .fq and .fq.gz")

        # do the parsing and sorting into files
        data = [ ]
        for line in fh:
            str_line = line.decode('ascii').strip()
            # header lines -- this assumes that qual lines do not start with @
            # for additional certainty, a counter or enumerate() could be used
            if str_line.startswith("@"):
                hdr_parts = str_line.split(":")
                barcode = hdr_parts[-1]
                # set the sample name according to the barcode dictionary
                # or "orphans" if absent
                if not barcode in self.dict.keys():
                    sample = "orphans"
                else:
                    sample = self.dict[barcode]
                # write record unless first line (empty data)
                if len(data) != 0:
                    self.write_record(data, sample)
                # make new record list
                data = [ str_line ]
            # collect data until next header line
            else:
                data.append(str_line)
        # write the last record
        self.write_record(data, sample)
        fh.close()

    """
    write a report with the collected counts
    """
    def print_report(self):
        for sample in self.num_records_written:
            print(sample + ": " + str(self.num_records_written[sample]) + " records")
        print("Total: " + str(self.total_records_written) + " records")

def main():
    if len(sys.argv) != 3:
        sys.exit("I need two arguments: (1) the FASTQ file and (2) the samples CSV file")
    dm = Demultiplexer(sys.argv[2]) # argument: the sample CSV
    dm.demultiplex(sys.argv[1]) # argument: the FASTQ file
    dm.print_report()

if __name__ == "__main__":
    main()
