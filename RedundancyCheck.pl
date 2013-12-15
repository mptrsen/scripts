use File::Copy;
use Cwd;
$taxoncounter = 0;
foreach $a (<*_dfgset2*>){
$taxoncounter++;
chdir $a;
$cwd = ();
$cwd = getcwd();
mkdir "RedundancyIssues";
chdir "log";
$taxonname = $a;
$taxonname =~ s/_dfgset2.*//;
@checkseq = ();
$noredundancy = 0;
$dircounter = 0;
 foreach $file (<*_HMMer3.out>) {
  open FILE, $file;
  while ($line = <FILE>) {
  chomp $line;
   @linesplit = split /\|/, $line;
   $sequenceID = $linesplit[3];
   $sequenceID =~ s/-\d*//g;
   @sequencenames = split /PP/, $sequenceID;
    foreach $b (0..$#sequencenames) {
     $sequencename = $sequencenames[$b];
     push (@checkseq, $sequencename);
    }
  }
  close FILE;
 }
 foreach $c (0..$#checkseq) {
 $counter = 0;
 @genenames = ();
 $checkname = $checkseq[$c];
  foreach $file (<*_HMMer3.out>) {
   open FILE, $file;
   while ($line = <FILE>) {
   chomp $line;
    @linesplit = split /\|/, $line;
    $sequenceID = $linesplit[3];
    $sequenceID =~ s/-\d*//g;
    @sequencenames = split /PP/, $sequenceID;
    foreach $e (0..$#sequencenames) {
     $sequencename = $sequencenames[$e];
     if ($checkname eq $sequencename) {
      $counter ++;
      push (@genenames, $linesplit[0]);
     }
    }
   }
   close FILE;
  }
  if ($counter > 1) {
   chdir "..";
   chdir "..";
   open OUTFILE, ">>TempRedundant.txt";
   print OUTFILE "$checkname of $taxonname found $counter times in: ";
   foreach $d (0..$#genenames) {
    print OUTFILE "$genenames[$d] ";
   }
   print OUTFILE "\n";
   close OUTFILE;
   foreach $d (0..$#genenames) {
    $alreadywritten = 0;
    chdir $a;
    open OUTFILE, "RedundancyIssues/SH_output_excerpt.txt";
     while ($line = <OUTFILE>) {
      if ($line =~ m/$genenames[$d]/) {
       $alreadywritten = 1;
      }
     }
    close OUTFILE;
    chdir "..";
    if ($alreadywritten == 0) {
     $shoutput = "hamstradTS";
     $shoutput .= $taxoncounter;
     $shoutput .= ".sh.o";
     foreach $shfile (<*.sh.o*>) {
      if ($shfile =~ m/$shoutput/) {
       open SHFILE, "$shfile";
        while ($line = <SHFILE>) {
         if ($line =~ m/$genenames[$d]/) {
          $excerpt = 1;
         }
         if ($line =~ m/now running \/share\/scientific_bin\/hmmer-3.0\/hmmsearch/ and $excerpt == 1) {
          $excerpt = 0;
         }
         if ($excerpt == 1) {
          chdir $a;
          open OUTFILE, ">>RedundancyIssues/SH_output_excerpt.txt";
           print OUTFILE "$line";
          close OUTFILE;
          chdir "..";
         }
        }
       close SHFILE;
      }
     }
    }
   }
   chdir $a;
   chdir "RedundancyIssues";
   if ($counter > 1 and $dircounter == 0) {
    mkdir "exonerate";
    mkdir "hmmsearch";
    mkdir "aa";
    mkdir "nt";
    mkdir "nt_cds";
    $dircounter = 1;
   }
   chdir "..";
   chdir "log";
   chdir "exonerate";
   foreach $d (0..$#genenames) {
    $newfilename = ();
    foreach $file (<*.out>) {
     if ($file =~ m/$genenames[$d]/) {
     $newfilename = $cwd;
     $newfilename .= "/RedundancyIssues/exonerate/";
     $newfilename .= $file;
     move ($file, $newfilename);
     }
    }
   }
   chdir "..";  
   chdir "hmmsearch";
   foreach $d (0..$#genenames) {
    $newfilename = ();
    foreach $file (<*.out>) {
     if ($file =~ m/$genenames[$d]/) {
     $newfilename = $cwd;
     $newfilename .= "/RedundancyIssues/hmmsearch/";
     $newfilename .= $file;
     move ($file, $newfilename);
     }
    }
   }
   chdir "..";  
   chdir "..";  
   chdir "aa";
   foreach $d (0..$#genenames) {
    $newfilename = ();
    foreach $file (<*.aa.fa>) {
     if ($file =~ m/$genenames[$d]/) {
     $newfilename = $cwd;
     $newfilename .= "/RedundancyIssues/aa/";
     $newfilename .= $file;
     move ($file, $newfilename);
     }
    }
   }
   chdir "..";  
   chdir "nt";
   foreach $d (0..$#genenames) {
    $newfilename = ();
    foreach $file (<*.nt.fa>) {
     if ($file =~ m/$genenames[$d]/) {
     $newfilename = $cwd;
     $newfilename .= "/RedundancyIssues/nt/";
     $newfilename .= $file;
     move ($file, $newfilename);
     }
    }
   }
   chdir "cds";
   foreach $d (0..$#genenames) {
    $newfilename = ();
    foreach $file (<*.cds.fa>) {
     if ($file =~ m/$genenames[$d]/) {
     $newfilename = $cwd;
     $newfilename .= "/RedundancyIssues/nt_cds/";
     $newfilename .= $file;
     move ($file, $newfilename);
     }
    }
   }
   chdir "..";  
   chdir "..";  
   chdir "log";  
   $noredundancy = 1;
  } 
 }
 chdir "..";
 chdir "..";
 if ($noredundancy == 0) {
  open OUTFILE, ">>NonRedundant.txt";
   print OUTFILE "No redundancies in $taxonname";
   print OUTFILE ".\n";
  close OUTFILE;  
 }
 print "Work on $taxonname done.\n";
}
@cleaning = ();
@cutout = ();
open INFILE, "TempRedundant.txt";
while ($line = <INFILE>) {
 push (@cleaning, $line);
}
close INFILE;
@double = @cleaning;
@printout = @cleaning;
foreach $f (0..$#cleaning) {
 $name = $cleaning[$f];
 shift (@double);
 foreach $g (0..$#double) {
  if ($name eq $double[$g]) {
  push (@cutout, $f); 
  }
 }
}
reverse @cutout;
foreach $h (0..$#cutout) {
 $del = $cutout[$h];
 delete $printout[$del];
}
open OUTFILE, ">>RedundantSequences.txt";
foreach $i (0..$#printout) {
print OUTFILE $printout[$i];
}
close OUTFILE;
unlink <TempRedundant.txt>;
open OUTFILE, ">RedundancyPerTaxon.txt";
 print OUTFILE "Taxon\tNumber_of_affected_contigs\tAA_file\tNumber_of_affected_genes\tNT_file\tNumber_of_affected_genes\n";
close OUTFILE;
foreach $a (<*_dfgset2*>){
 $taxonname = $a;
 $taxonname =~ s/_dfgset2.*//;
 @redgenenames=();
 @printout=();
 $seqcounter=0;
 open INFILE, "RedundantSequences.txt";
  while ($line = <INFILE>) {
   chomp $line;
   @redlinesplit =();
   @redlinesplit = split / /, $line;
   if ($redlinesplit[2] =~ m/$taxonname/) {
    $seqcounter++;
    @newdata =();
    $end = $#redlinesplit;
    @newdata = @redlinesplit[7..$end];
    push (@redgenenames, @newdata);
   }
  }
 close INFILE;
 push (@printout, $taxonname);
 push (@printout, $seqcounter);
 chdir $a;
 chdir "log";
 foreach $file (<*.out>) {
  open INFILE, $file;
  $outfilenonred = $file;
  $outfilenonred .= "_nonredundant";
  $outfilered = $file;
  $outfilered .= "_redundant";
  $genecounter = 0;
   while ($line =<INFILE>) {
    $printnonred = 1;
    foreach $j (0..$#redgenenames) {
     if ($line =~ m/$redgenenames[$j]/) {
      $genecounter++;
      chdir "..";
      open OUTFILE, ">>RedundancyIssues/$outfilered";
       print OUTFILE "$line";
      close OUTFILE;
      $printnonred = 0;
      chdir "log";
     }
    }
    if ($printnonred == 1) {
     open OUTFILE, ">>$outfilenonred";
      print OUTFILE "$line";
     close OUTFILE;
    }
   }
  close INFILE;
 push (@printout, $file);
 push (@printout, $genecounter);
 }
 chdir "..";
 chdir "..";
 open OUTFILE, ">>RedundancyPerTaxon.txt";
  foreach $k (0..$#printout) {
   print OUTFILE $printout[$k];
   print OUTFILE "\t";
  }
  print OUTFILE "\n";
 close OUTFILE;
}