#!/usr/bin/perl
use warnings;
use Getopt::Long;


my $long_read_cluster_threshold = 2;
for($i = 0; $i < 6; $i++){$cluster_threshold_tab[$i] = $long_read_cluster_threshold;}
my $short_read_cluster_threshold = 3;
#my @cluster_threshold_tab = (2,2,2,2,1,1);
#my @cluster_threshold_tab = (2,2,2,2,2,1);
my $FLAG_FILTER_CONFLICTING_ALIGNEMENT = 0;
#my $FLAG_NO_CONFLICTING_EDGE = 1;


#SOME THRESHOLD
#Contig size
my $min_opera_contig_size = 500;
my $min_contig_size = 500;
my $min_contig_size_for_gap_filling = 100;
#Minimum fraction of contig mapped to be considered fully contained on the read
my $fraction = 0.9;
my $fraction_in_gap = 0.8;
#Minimum contig alignement length
my $min_alignment_length = 400;#Allows to have partially mapped short contigs at the edge of reads
#Used for 2 different purpose:
#1) maximum overlap allowed between 2 mapped contigs
#2) non-ovelapping sequences allowed on the contig and read to be concidered as a valid alignement
my $overlap = 200;

#my $mapper_extention 
my $graphmapDir = "";


#Used in case of grapmap mapping
my @contig_id_to_name = ();
#list of repeat contigs
my %repeat_contig = ();

#Init the software directories variables
my $blasrDir = "";
my $operaDir = "";
my $short_read_tooldir = "";
my $samtools_dir = "";
my $short_read_maptool = "bwa";
my $kmer_size = 100;
my $flag_help;
my $skip_opera = 0;
my $skip_short_read_mapping = 0;
my $help_message = "

Options:
    --contig-file: fasta file of contigs
    --kmer: size of the kmer used to produce the contig (default 100)
    --long-read-file: fasta file of long reads
    --output-prefix: prefix of output mapping file
    --output-directory: output directory for scaffolding results
    --num-of-processors: number of processors used for mapping stages
    --minimap2: Folder which contains minimap2 binary (default PATH)
    --blasr: Folder which contains blasr binary (default PATH)
    --short-read-maptool: Mapping tool can be either bwa (default) or bowtie
    --short-read-tooldir: Directory that contains binaries to the chosen short read mapping tool (default PATH)
    --samtools-dir:Directory that contains samtools binaries (default PATH)
    --opera: Folder which contains opera binary (default PATH)
    --perl-dir: directory were perl used
    --illumina-read1: fasta file of illumina read1
    --illumina-read2: fasta file of illumina read2
    --help : prints this message
    --skip-opera :set to 1 to skip running OPERA-LG and just uses the script for processing purposes. (Default set to 0)
";

if ( @ARGV == 0 ) {
    print $help_message;
    exit 0;
}

GetOptions(
    "contig-file=s"    => \$contigFile,
    "long-read-file=s"    => \$readsFile,
    "output-prefix=s" => \$file_pref,
    "output-directory=s" => \$outputDir,
    "num-of-processors=i" => \$nproc,
    "kmer=i" => \$kmer_size,
    "blasr=s"      => \$blasrDir,
    "graphmap=s"      => \$graphmapDir,
    "minimap2=s"      => \$minimap2Dir,
    "opera=s"      => \$operaDir,
    "samtools-dir=s"  => \$samtools_dir,
    "perl-dir=s" => \$perl_dir,
    "short-read-maptool=s" => \$short_read_maptool,
    "short-read-tooldir=s" => \$short_read_tooldir,
    "illumina-read1=s"      => \$illum_read1,
    "illumina-read2=s"      => \$illum_read2,
    "skip-short-read-mapping=i" => \$skip_short_read_mapping,
    "help"       => \$flag_help,
    "skip-opera=i" => \$skip_opera
    ) or die("Error in command line arguments.\n");

if ($flag_help) {
    print $help_message;
    exit 0;
}
if (!defined($contigFile)) {
    my $cmd = 'pwd';
    print STDERR "\n".$cmd."\n";
    die "contigs fasta file needs to be specified\n";
}
if (!defined($readsFile)) {
    die "long reads fasta file needs to be specified\n";
}
if (!defined($file_pref)) {
    die "prefix of output mapping file needs to be specified\n";
}
if (!defined($outputDir)) {
    die "output directory for scaffolding results needs to be specified\n";
}

#my $mapper = "minimap2";
my $mapper = "";
$mapper = "blasr" if(defined $blasrDir);
$mapper = "minimap2" if(defined $minimap2Dir);

die " No mapper specified in OPERA-long-read\n" if($mapper eq "");

#if (!defined($blasrDir)) {
#        print "Folder which contains blasr binary if it is not in PATH needs to be specified\n";
#        exit 0;
#}
#if (!defined($sspaceDir)) {
#        print "Folder which contains SSPACE perl script if it is not in PATH needs to be specified\n";
#        exit 0;
#}
#if (!defined($operaDir)) {
#        print "older which contains opera binary if it is not in PATH needs to be specified\n";
#        exit 0;
#}
if (!defined($illum_read1) || !defined($illum_read2)) {
    print STDERR " *** WARNING illumina fasta file not fully specified\n";
    $illum_read1 = "NONE";
    $illum_read2 = "NONE";
}


if( $outputDir !~ "/\$" && $outputDir ne "" )
{
    $outputDir .= "/";
}
run_exe("mkdir $outputDir") unless(-d $outputDir);
if( !-d $outputDir ){
    print STDERR "Error: the output directory does not exist, please try again.\n";
    exit( -1 );
}

if( !defined( $nproc ) ){
    $nproc = 1;
}
#To make that those varibles are really directories
if( $blasrDir !~ "/\$" && $blasrDir ne "" )
{
    $blasrDir .= "/";
}
if( $operaDir !~ "/\$" && $operaDir ne "" )
{
    $operaDir .= "/";
}
if( $samtools_dir !~ "/\$" && $samtools_dir ne "" )
{
    $samtools_dir .= "/";
}

chdir( $outputDir );

my $str_full_path = "or please enter the full path";
if ( ! -e $contigFile ) {die "\nError: $contigFile - contig file does not exist $str_full_path\n"};
if ( ! -e $readsFile ) {die "\nError: $readsFile - long read file does not exist $str_full_path\n"};

if ( ! -e "$blasrDir/blasr" && $blasrDir ne "") {die "\nError: $blasrDir - blasr does not exist in the directory $str_full_path\n"};


#if ( ! -e "$graphmapDir/graphmap" ) {die "$! graphmap does not exist in the directory $str_full_path\n"};
if ( ! -e "$operaDir/OPERA-LG" && $operaDir ne "") {die "\nError:$operaDir - OPERA-LG does not exist in the directory $str_full_path\n"};
if ( ! -e "$short_read_tooldir/bwa" && $short_read_maptool eq "bwa" && $short_read_tooldir ne "") {die "\nError: $short_read_tooldir - bwa does not exist in the directory $str_full_path\n"};


#map illumina reads to the contigs using preprocess_reads.pl
$str_path_dir = "";
$str_path_dir .= "--tool-dir  $short_read_tooldir" if($short_read_tooldir ne "");
$str_path_dir .= " --samtools-dir $samtools_dir" if($samtools_dir ne "");
if(index($illum_read1, ",") == -1){#single sample assembly
    if ( ! -e $illum_read1 && $illum_read1 ne "NONE") {die "\nError: $illum_read1 - illumina read 1 file does not exist $str_full_path\n"};
    if ( ! -e $illum_read2 && $illum_read2 ne "NONE") {die "\nError: $illum_read2 - illumina read 2 file does not exist $str_full_path\n"};
    
    if( !$skip_short_read_mapping && ! -e "${file_pref}.bam" &&  !($illum_read1 eq "NONE" && $illum_read2 eq "NONE")){
	$start_time = time;
	print " *** *** Mapping short-reads using  $short_read_maptool...\n";
    	run_exe("$perl_dir/perl $operaDir/preprocess_reads.pl $str_path_dir --nproc $nproc --contig $contigFile --illumina-read1 $illum_read1 --illumina-read2 $illum_read2 --out ${file_pref}.bam 2> preprocess_reads.err");
	if($?){
	    die "Error during read preprocessing. Please see $outputDir/preprocess_reads.err for details.\n";
	}
	$end_time = time;
	print STDOUT "***  Elapsed time: " . ($end_time - $start_time) . "\n";
    }
}
else{
    @illum_read1_tab = split(/,/, $illum_read1);
    @illum_read2_tab = split(/,/, $illum_read2);
    for(my $i = 0; $i < @illum_read1_tab; $i++){
	if(! -e "$file_pref\_$i.bam"){
	    run_exe("$perl_dir/perl $operaDir/preprocess_reads.pl $str_path_dir --nproc $nproc --contig $contigFile --illumina-read1 $illum_read1_tab[$i] --illumina-read2 $illum_read2_tab[$i] --out $file_pref\_$i.bam");
	}
    }
}
if($?){
    die "Error in the short read mapping. Please see log for details.\n";
}



if(! -e "$file_pref.map.sort"){
    # map using blasr
    $start_time = time;
    if($mapper eq "blasr"){
	print "Mapping long-reads using blasr...\n";
	run_exe( "${blasrDir}blasr  -nproc $nproc -m 1 -minMatch 5 -bestn 10 -noSplitSubreads -advanceExactMatches 1 -nCandidates 1 -maxAnchorsPerPosition 1 -sdpTupleSize 7 $readsFile $contigFile | cut -d ' ' -f1-12 | sed 's/ /\\t/g' > $file_pref.map 2> blasr.err");
	if($?){
	    die "Error in the blasr mapping. Please see $outputDir/blasr.err for details.\n";
	}
	$end_time = time;print STDOUT "***  Elapsed time: " . ($end_time - $start_time) . "\n";
	# sort mapping
	$start_time = time;
	print "Sorting mapping results...\n";
	run_exe("sort -k1,1 -k10,10g  $file_pref.map > $file_pref.map.sort");
	$end_time = time;print STDOUT "***  Elapsed time: " . ($end_time - $start_time) . "\n";
    }
    
    if($mapper eq "graphmap"){
	print "Mapping using graphmap...\n";
	run_exe("$graphmapDir/graphmap owler -t 20 -r $contigFile -d $readsFile -o $file_pref.map");
	print "Sorting mapping results...\n";
	run_exe("sort -k1,1 -k6,6g  $file_pref.map > $file_pref.map.sort");
    }

    if($mapper eq "minimap2"){
	print "Mapping long-reads using minimap2...\n";
	#
	run_exe("$minimap2Dir/minimap2 -t $nproc -w5 -m0 --cs=short $contigFile $readsFile | cut -f1-21 > $file_pref.map 2> minimap2.err");
	#
	if($?){
	    die "Error in the minimap2 mapping. Please see $outputDir/minimap2.err for details.\n";
	}
	$end_time = time;print STDOUT "***  Elapsed time: " . ($end_time - $start_time) . "\n";

	print "Sorting mapping results...\n";
	run_exe("sort -k1,1 -k3,3g  $file_pref.map > $file_pref.map.sort");
    }
    
}


#Read the contig file to get an array contig ID -> contig_name as the map file contain only read and contig identifier based on thei line number
if($mapper eq "graphmap"){
    print "Analyse contig file...\n";
    open(FILE, "grep \">\" $contigFile | sed 's/>//' |");
    while(<FILE>){
	@line = split(/\s+/, $_);
	push(@contig_id_to_name, $line[0]);
    }
    close(FILE);
}
# analyze mapping file
$start_time = time;
print "Analyzing sorted results...\n";
#my $all_edge_file = "pairedEdges";
my $all_edge_file = "pairedEdges";
&checkMapping( "$file_pref.map.sort", $all_edge_file);

#Get the long read coverage information
#if($illum_read1 eq "NONE" && $illum_read2 eq "NONE"){
    long_read_coverage_estimate("$file_pref.map.sort.status", "$file_pref.map.cov");
    #print "Mapping long-reads using minimap2...\n";<STDIN>;
#}

# extract edges
print "Extracting linking information...\n";
#extract_edge("pairedEdges");
extract_edge($all_edge_file);

#No repeat detection required
my @allEdgeFiles = ();
for (my $i = 0; $i <= 5; $i++){
    $edge_file = $all_edge_file."_i$i";
    push(@allEdgeFiles, $edge_file);
}

# create configure file
&CreateConfigFile( $contigFile, "", $outputDir, @allEdgeFiles );


if (!$skip_opera){

        # run opera
    &run_exe( "${operaDir}OPERA-LG config > log" );

    #Link to the result file
    &run_exe("ln -s results/scaffoldSeq.fasta scaffoldSeq.fasta");

}

sub extract_edge{
    my ($all_edge_file) = @_;

    my %inter = (
	"i0", [-200, 300],
	"i1", [300, 1000],
	"i2", [1000, 2000],
	"i3", [2000, 5000],
	"i4", [5000, 15000],
	"i5", [15000, 40000]
	);
    
    my %out_edge = ();
    foreach $it (keys %inter){
	print STDERR $it."\t".$inter{$it}->[0]."\t".$inter{$it}->[1]."\n";
	my $OUT;
	open($OUT, ">$all_edge_file\_$it");
	$out_edge{$it} = $OUT;
    }

    open(FILE, $all_edge_file);
    while(<FILE>){
	chop $_;
	@line = split(/\t/, $_);
	$dist = $line[4];
	$support = $line[6];
	foreach $it (keys %inter){
	    if($support >= 0 && $inter{$it}->[0] < $dist && $dist < $inter{$it}->[1]){
		$OUT = $out_edge{$it};
		print $OUT join("\t", @line)."\n";
		last;
	    }
	}
    }
    

    foreach $it (keys %inter){
	$OUT = $out_edge{$it};
	close($OUT);
    }
}




sub getAlignmentType {

    my ($rn, $cn, $ro, $co, $cs, $ce, $cl, $rs, $re, $rl) = @_;
    
    #the contig is fully contained in the read 
    #the second condition is made for short contig that required to have at leat [ cl - overlap ] based mapped ... NOT TOO RELAXED ... It is not better to use the minimum mapping length here ?
    if($ce-$cs >= $fraction*$cl || $ce-$cs >= $cl-$overlap) {
    #if($ce-$cs >= $fraction*$cl || $ce-$cs >= $cl-$min_alignment_length) {

        return("contig-contained");
    }
    
    #the read is fully contained in the read 
    elsif($re-$rs >= $fraction*$rl || $re-$rs >= $rl-$overlap) {
    #elsif($re-$rs >= $fraction*$rl || $re-$rs >= $rl-$min_alignment_length) {

	return("read-contained");
    }

    
    elsif($ce >= $cl-$overlap && $rs <= $overlap) {

	return("contig-at-start");
    }
    elsif($cs <= $overlap && $re >= $rl-$overlap) {
	
	return("contig-at-end");
    }
    else{            
	return("partial-match");
    }
}

sub add_contig_for_gapfilling{
    my ($contig_list, $contig_name, $contig_orientation, $contig_start, $contig_end, $contig_score, $contig_size, $flag_check_for_conflict) = @_;
    if(!$flag_check_for_conflict || check_overlap_contig_for_gapfilling($contig_list, $contig_start, $contig_end, $contig_score, $contig_size)){
	my @tab = ($contig_name, $contig_orientation, $contig_start, $contig_end, $contig_score);
	push(@{$contig_list}, \@tab);
    }
}

#Check if the contig is the new contig overlap with the last one and pop the last contig if necessary
#return 1 if the contig can be added, 0 otherwise
sub check_overlap_contig_for_gapfilling{
    my ($contig_list, $contig_start, $contig_end, $contig_score, $contig_size) = @_;
    my $list_size = @{$contig_list}+0;
    return 1 if($list_size == 0);
    my $last_contig_info = @{$contig_list}[-1];#$contig_name, $contig_orientation, $contig_start, $contig_end, $contig_score, $contig_length
    #print STDERR " *** check_overlap_contig_for_gapfilling |@{$contig_list}| |@{$last_contig_info}|\n";<STDIN>;
    $prev_alignment_end = $last_contig_info->[3];
    #This an overlapping alignement
    if( $prev_alignment_end - $overlap > $contig_start) {
	$prev_contig_size = $last_contig_info->[-1];
	$prev_contig_score = $last_contig_info->[-2];
	if($contig_size >= $min_contig_size ||
	   ($prev_contig_size < $min_contig_size && $prev_contig_score > $contig_score)){
	    pop(@{$contig_list});
	        #The new contig have a alignement with better quality and it can be added to the list
	    return 1;
	}
	else{
	        #The new contig have a alignement with lower quality than the previous contig, it will not be added to the list
	    return 0;
	}
    }
    else{
	#Non overlapping contigs
	return 1;
    }
}
sub printEdges {

    local(*alignments) = @_;
    my $next_allignemnet_to_link;
    my $edge_ID;my @contig_order;
    my $next_contig_found = 0;
    my @contig_for_gapfilling_list = ();
    for($i = 0; $i <= $#alignments; $i++ ){
	#Conflicting alignement are filtered out
	next if(index($alignments[$i], "_CONFLICT") != -1 ||
		index($alignments[$i], "_small_contig_gapfilling") != -1
	    );
	my ($rn1, $cn1, $ro1, $co1, $cs1, $ce1, $cl1, $rs1, $re1, $rl1) = split(/ /, $alignments[$i]);
	$ori1 = ($co1 == 0 ? "+" : "-");
	
	$alignemnt_to_link = $#alignments;
	$next_contig_found = 0;
	@contig_for_gapfilling_list = ();
	for( $j = $i + 1; $j <= $alignemnt_to_link; $j++ ){
	        
	        #Conflicting alignement are filtered out
	    next if(index($alignments[$j], "_CONFLICT") != -1);

	    my ($rn2, $cn2, $ro2, $co2, $cs2, $ce2, $cl2, $rs2, $re2, $rl2) = split(/ /, $alignments[$j]);
	    $ori2 = ($co2 == 0 ? "+" : "-");
	        
	    if(0 && $cn1 == 170676){
		print STDERR $cn1."\t".$cn2." $rn2 => ";
		foreach $a (@contig_for_gapfilling_list){
		    print STDERR " ".join(",", @{$a});
		}
		#print STDERR "\n";<STDIN> if($cn2 == 172314 && @contig_for_gapfilling_list != 0 && $contig_for_gapfilling_list[0]->[0] == 167726);
	    }

	        #To store the short contig for the gapfilling
	    if(index($alignments[$j], "_small_contig_gapfilling") != -1){
		if($re1 - $overlap < $rs2){#No conflict with contig at the starting point of the edge [TESTED TOO MANY TIMES]
		    add_contig_for_gapfilling(\@contig_for_gapfilling_list, $cn2,  $ori2, $rs2, $re2, $cs2, $cl2, 1);
		}
		next;
	    }
	           
	    $distance = int(($rs2-$re1) + abs($rs2-$re1)*0.09); 
	        #NEED TO REMOVE AS SD IS NOW COMPUTED ON THE AVG DISTANCE OF THE EDGE
	    $sd = int(abs($distance)*0.1+50);#Why the SD is applied to the corrected distance 
	    $distance += -$cs2 - ($cl1-$ce1);

	        #print "$alignments[$i]\n$alignments[$j]\n \n" if($cn1 eq $cn2); 
	        next if(
		    $cn1 eq $cn2 || #the contig is the same
		    ($cl1 < $min_opera_contig_size || $cl2 < $min_opera_contig_size) ||#one contig does not pass opera contig size threshold
		    exists $repeat_contig{$cn1} ||#one of the contig is a repeat
		    exists $repeat_contig{$cn2} 
		    #exists $edge_to_filter{$cn1.":".$cn2.":".$distance}#This a conflicting edge
		    );
	        
	    @contig_order = sort($cn1, $cn2);
	    $edge_ID = join(" ", @contig_order);

	        #Collect the transitive edge for that read to filter out edge from reads that contain only the transitive edge
	        
	    if($component{$cn1} == 0 && $component{$cn2} == 0) {

		$component{$cn1} = $component{$cn2} = $component_num; 
		$member{$component_num} = "$cn1 $cn2";
		$length{$component_num} += $cl1 + $cl2; 
		$component_num++;
	    }
	    elsif($component{$cn1} == 0) {

		$component{$cn1} = $component{$cn2};
		$member{$component{$cn1}} .= " $cn1";
		$length{$component{$cn1}} += $cl1;
	    }
	    elsif($component{$cn2} == 0) {

		$component{$cn2} = $component{$cn1};
		$member{$component{$cn2}} .= " $cn2";
		$length{$component{$cn2}} += $cl2;
	    }
	    elsif($component{$cn1} != $component{$cn2}) {

		#print $length{$component{$cn1}}." with ".$length{$component{$cn2}}."\n";
		if($length{$component{$cn1}} >= $length{$component{$cn2}}) {
		        
		    $member{$component{$cn1}} .= " ".$member{$component{$cn2}};
		    $length{$component{$cn1}} += $length{$component{$cn2}}; $length{$component{$cn2}} = 0; 
		    foreach $member (split(/ /, $member{$component{$cn2}})) { $component{$member} = $component{$cn1}; }
		}
		else {

		    $member{$component{$cn2}} .= " ".$member{$component{$cn1}};
		    $length{$component{$cn2}} += $length{$component{$cn1}}; $length{$component{$cn1}} = 0; 
		    foreach $member (split(/ /, $member{$component{$cn1}})) { $component{$member} = $component{$cn2}; }
		}
	    }

	    if(! defined $edge_read_info{$edge_ID}){
		#$print{$edge_ID} = "$cn1\t$ori1\t$cn2\t$ori2\t$distance\t$sd\t";
		#$print{$edge_ID} = "$cn1\t$ori1\t$cn2\t$ori2\t";
		#$str = "$cn1\t$ori1\t$cn2\t$ori2";
		#$str = "$cn2\t$ori2\t$cn1\t$ori1" if($contig_order[0] ne $cn1);
		$str = "$cn1\t$cn2";
		$str = "$cn2\t$cn1" if($contig_order[0] ne $cn1);
		$edge_read_info{$edge_ID} = {"EDGE", $str,
					          "DIST_LIST", [],
					          "READ_LIST", [],
					          "COORD_CONTIG_1", [],
					          "COORD_CONTIG_2", [],
					          "COORD_CONTIG_1_ON_READ", [],
					          "COORD_CONTIG_2_ON_READ", [],
					          "CONTIG_GAPFILLING", []
		};
	    }
	    $others{$edge_ID} .= "$rn1,$cn1,$ori1,$cn2,$ori2,$distance,$sd|";

	        #Swap the alignement in case of contig order change
	    if($contig_order[0] eq $cn1){
		push(@{$edge_read_info{$edge_ID}->{"COORD_CONTIG_1"}}, $co1."_".$cs1."_".$ce1);
		push(@{$edge_read_info{$edge_ID}->{"COORD_CONTIG_2"}}, $co2."_".$cs2."_".$ce2);
		#
		push(@{$edge_read_info{$edge_ID}->{"COORD_CONTIG_1_ON_READ"}}, $ro1."_".$rs1."_".$re1);
		push(@{$edge_read_info{$edge_ID}->{"COORD_CONTIG_2_ON_READ"}}, $ro2."_".$rs2."_".$re2);
	    }
	    else{
		push(@{$edge_read_info{$edge_ID}->{"COORD_CONTIG_1"}}, $co2."_".$cs2."_".$ce2);
		push(@{$edge_read_info{$edge_ID}->{"COORD_CONTIG_2"}}, $co1."_".$cs1."_".$ce1);
		#
		push(@{$edge_read_info{$edge_ID}->{"COORD_CONTIG_1_ON_READ"}}, $ro2."_".$rs2."_".$re2);
		push(@{$edge_read_info{$edge_ID}->{"COORD_CONTIG_2_ON_READ"}}, $ro1."_".$rs1."_".$re1);
	    }
	    push(@{$edge_read_info{$edge_ID}->{"READ_LIST"}}, $rn1);
	    push(@{$edge_read_info{$edge_ID}->{"DIST_LIST"}}, $distance);
	        
	        #Check if the long contig ovlap with the last contig of the list
	    check_overlap_contig_for_gapfilling(\@contig_for_gapfilling_list, $rs2, $re2, $cs2, $cl2);
	    $c_gap_filling_str = "";
	    foreach $c (@contig_for_gapfilling_list){
		$c_gap_filling_str .= $c->[1].$c->[0].",";
	    }
	    chop $c_gap_filling_str;
	    $c_gap_filling_str = "NONE" if($c_gap_filling_str eq "");
	    push(@{$edge_read_info{$edge_ID}->{"CONTIG_GAPFILLING"}}, $c_gap_filling_str);
	        #add the long contig to the contig list in case of direct edges not present, the contig is filtered as repeat
	    add_contig_for_gapfilling(\@contig_for_gapfilling_list, $cn2,  $ori2, $rs2, $re2, $cs2, $cl2, 0);
	        #next;
	}
    }    
}


sub long_read_coverage_estimate{
    my ($paf_file, $out_file) = @_;

    #print STDERR "long_read_coverage_estimate $paf_file $out_file\n";<STDIN>;
    
    #my $sequence_overhang = 100;
    #my $MINIMUM_READ_SIZE = 200;
    
    open(FILE, "grep -v small-alignment $paf_file | ");
    my $nb_read_process = 0;
    my %contig_read_map_length = (); my %read_on_contig = ();my %contig_length =();
    my @line;
    my ($read_name, $read_length, $map_s, $map_e, $contig, $curr_read);
    $curr_read = "";
    while(<FILE>){
	$nb_read_process++;
	print STDERR " *** *** $nb_read_process\n" if($nb_read_process % 100000 == 0);#<STDIN>;
	@line = split(/\t/, $_);
	$read_name = $line[0];
	$read_length = $line[9];
	$map_s = $line[7];
	$map_e = $line[8];
	
	$contig = $line[1];
	$contig_length = $line[6];
	
	$contig_length{$contig} = $contig_length;
	#
	#next if($read_length < $MINIMUM_READ_SIZE);
	#
	if($curr_read ne $read_name){
	    %read_on_contig = ();
	    $curr_read = $read_name;
	}
	#
	
	#Read are allowed to map to multiple contigs if they map fully
	if(! exists $read_on_contig{$contig}){
	    if(! exists $contig_read_map_length{$contig}){
		$contig_read_map_length{$contig} = 0;
	    }
	    $contig_read_map_length{$contig} += ($map_e - $map_s);
	    $read_on_contig{$contig} = 1;
	}
    }
    close(FILE);
    
    open(OUT, ">$out_file");
    foreach $c (keys %contig_read_map_length){
	#$contig_thoughput_fraction = "NA";
	#$contig_thoughput_fraction = $contig_read_map_length{$c} / $throughput if($throughput != 0);
	$c_l = $contig_length{$c};
	print OUT $c . "\t" . $c_l . "\t" . ($contig_read_map_length{$c} / $c_l) . "\n";
    }
    close(OUT);
}

sub checkMapping{
    my ($mapFile, $all_edge_file) = @_;
    my ($rn, $cn, $score, $unused, $ro, $rs, $re, $rl, $co, $cs, $ce, $cl, $similarity);
    my $currentScore = 0;my $previousScore = 0;
    %component = (); %length = (); $component_num = 1; %member = ();
    #%print = (); 
    %others = ();
    %edge_read_info = ();
    
    open(MAP, "$mapFile") or die $!;
    #open(MAP, "head -n10000 $mapFile | ") or die $!;
    open(STATUS, ">$mapFile.status") or die $!;

    $prev_rn = ""; @alignments = (); $prev_alignment_end = 0;
    while(<MAP>){
	chomp; 
	@line = split /\s+/; 
	next if(@line < 10);
	#Get the mapping coordinates using blars or graphmap
	#($rn, $cn, $ro, $co, $cs, $ce, $cl, $rs, $re, $rl, $score) = @line if($mapper eq "blasr");
	($rn, $cn, $ro, $co, $score, $similarity, $cs, $ce, $cl, $rs, $re, $rl) = @line if($mapper eq "blasr");

    #print STDOUT "$score\n";
	#Conversion from the graphmmap (mhap) format to the blasr format
	if($mapper eq "graphmap"){
	    ($rn, $cn, $score, $unused, $ro, $rs, $re, $rl, $co, $cs, $ce, $cl) = @line;
	    $cn = $contig_id_to_name[$cn];
	}

	if($mapper eq "minimap2"){
	    ($rn, $rl, $rs, $re, $ro,
	     $cn, $cl, $cs, $ce) = @line;
	    #
	    if($ro eq "-"){
		$ro = 0;
		$co = 1;
		#
		#print STDERR "$cl $cs:$ce =>";
		$cs_rev = $cl - $ce;
		$ce_rev = $cl - $cs;
		#
		$ce = $ce_rev;
		$cs = $cs_rev;
		#print STDERR " $cs:$ce\n";<STDIN>;
		
	    }
	    else{
		$ro = 0 if($ro eq "+");
		$co = 0;
	    }
	    #
	    $score = $line[9] / ($ce - $cs);
	    #($rn, $cn, $score, $unused, $ro, $rs, $re, $rl, $co, $cs, $ce, $cl) = @line;
	    
	}
	
	@data = ($rn, $cn, $ro, $co, $cs, $ce, $cl, $rs, $re, $rl, $score);

	#Init the contig component
	if(! defined $component{$cn}){
	    $component{$cn} = 0;
	}

	#print STDERR "$mapper -> @data"."\n".$rn."\t".$cl."\n\n";<STDIN>;
	
	#Save the contig length for the conflicting edge pipeline
	$contig_length{$cn} = $cl;

	#Filter small contigs
	if($cl < $min_contig_size) {
	    print STATUS (join("\t", @data)." | "); print STATUS "small-contig\n";
	        #Those alignement are saved for the gapfilling part only in order to improve the sequence quality of the filled sequences
	        #The overlapping alignements are solve during the print edge step to avoind interference between long contigs used for scaffolding and short contigs only used gapfilling
	        if($cl > $min_contig_size_for_gap_filling && 
		          $ce-$cs >= $fraction_in_gap*$cl #The contig fraction mapped is 90% of is length
		    ){
		    push @alignments, "@data";
		    $alignments[@alignments-1] .= "_small_contig_gapfilling";
		}
	    next;
	}
	
	#Minimum alignment length threshold
	if($re-$rs < $min_alignment_length) {
	    print STATUS (join("\t", @data)." | "); print STATUS "small-alignment\n";
	    next;
	}
	
	#Do we want to filter base on score as well ? At least for graphmap ...
	$alignmentType = &getAlignmentType(@data);
	
	print STATUS (join("\t", @data)." | "); print STATUS $alignmentType;
	if($alignmentType eq "partial-match") {

	    print STATUS "\n";
	    next;
	}

	#This is a new read
	if($rn ne $prev_rn) {
	        #Get the edge of the alignement on read prev_rn
	    &printEdges(*alignments) if(@alignments > 1);
	        #Udpdate the variable to start to collect information about the alignent on the read $rn
	    $prev_rn = $rn; @alignments = (); 
	    push @alignments, "@data";
	    $prev_alignment_end = $re + $cl-$ce;
	    $previousScore = $currentScore;   
	}
	else {

	    $curr_alignment_start = $rs - $cs;
	    $curr_alignment_end = $re + $cl-$ce;
	    $currentScore = $score;
	        #Non overlapping alignement
	    if($prev_alignment_end-$overlap < $curr_alignment_start) {
		
		push @alignments, "@data";
		$prev_alignment_end = $curr_alignment_end;
		$previousScore = $currentScore;   
	    }
	    else {
		#WE SIMPLY FLAG THE ALIGNEMENT AS CONFLICTING AND LOOSE THE INFORMATION
		if($FLAG_FILTER_CONFLICTING_ALIGNEMENT){
		    $prev_alignment_end = $curr_alignment_end;
		        #print STDERR " *** ADD CONFLICT TAG ".(($alignments[@alignments-1]))."\n";#<STDIN>;
		    $alignments[@alignments-1] .= "_CONFLICT";
		    print STATUS " overlapped";
		}
		else{
		        #If 2 contig alignements are overlapping, take the one with the highest score
		        #DO WE WANT TO USE THE ALIGNEMENT LENGTH AS WELL TO COMPARE THE ALIGNEMENT ???
		        if( ($mapper eq "blasr" && $previousScore > $currentScore) || #the best score are the more negative
			    (($mapper eq "graphmap" || $mapper eq "minimap2") && $previousScore < $currentScore) #here we use for graphmap/minimap2 the the fraction of bases covered by seeds to compare the alignements
			    ){
			    # replace mapping
			    pop @alignments;
			    push @alignments, "@data";
			    $prev_alignment_end = $curr_alignment_end;
			    $previousScore = $currentScore; 
			    print STATUS " overlapped better";
			}
			else{
			    print STATUS " overlapped";
			}
		}
	    }
	}

	print STATUS "\n";
    }
    
    #open(EDATA, ">$mapFile.edge_data") or die $!;
    #Compute the distance and support of each edge
    #Due to missmapping problem it is possible that 2 contigs have edges with non-concordant distances
    open(EDGE, ">$all_edge_file") or die $!;
    open(EDGE_READ, ">edge_read_info.dat") or die $!;
    my %edge_distance_support = ();my @sorted_distance_ori = ();my @all_distance_ori = ();
    my ($distance_ID, $best_support);
    foreach $key (keys(%edge_read_info)) {
#print STDERR "\n *** *** contig pair $key\n";
	#Compute the support and edge distance as well as the orientation
	#Constructure a array that contain the distance as well as the orientation of the 2 contigs involve in the edge
	%edge_distance_support = ();
	@all_distance_ori = ();
	$edge_read_info{$key}->{"EDGE_TYPE"} =  ();
	for(my $i = 0; $i < @{$edge_read_info{$key}->{"DIST_LIST"}}; $i++){
	        #print STDERR " *** $i ".(@{$edge_read_info{$key}->{"DIST_LIST"}}+0)."\n";<STDIN>;
	    $d = $edge_read_info{$key}->{"DIST_LIST"}->[$i];
	    @tmp = split(/\_/, $edge_read_info{$key}->{"COORD_CONTIG_1"}->[$i]);$ori_1 = ($tmp[0] == 0 ? "+" : "-");
	    @tmp = split(/\_/, $edge_read_info{$key}->{"COORD_CONTIG_2"}->[$i]);$ori_2 = ($tmp[0] == 0 ? "+" : "-");
	        #
	    @tmp = split(/\_/, $edge_read_info{$key}->{"COORD_CONTIG_1_ON_READ"}->[$i]);$start_1 = $tmp[1];
	    @tmp = split(/\_/, $edge_read_info{$key}->{"COORD_CONTIG_2_ON_READ"}->[$i]);$start_2 = $tmp[1];
	        #
	    $edge = $ori_1.":".$ori_2;
	    if($start_1 > $start_2){#The order of the contig is reversed
		$ori_1 = ($ori_1 eq "+" ? "-" : "+");
		$ori_2 = ($ori_2 eq "+" ? "-" : "+");
		$edge = $ori_1.":".$ori_2;
	    }
	    push(@all_distance_ori, [$d, $edge]);
	    push(@{$edge_read_info{$key}->{"EDGE_TYPE"}}, $edge);
	}
	#Sort the edge according to their distance and start the bundling
	@sorted_distance_ori = (sort {$b->[0] <=> $a->[0]} @all_distance_ori);
	$nb_edge_distance = 0;
	for(my $i = 0; $i < @sorted_distance_ori; $i++){
	    $distance = $sorted_distance_ori[$i]->[0];
	    $edge = $sorted_distance_ori[$i]->[1];
##    print STDERR " *** $edge the dist $distance\n";
	    $distance_ID = -1;
	    if(exists $edge_distance_support{$edge}){
		for(my $j = 0; $j < @{$edge_distance_support{$edge}}; $j++){
		        #The distance match one the the previous distance found
		    if(remove_standard_deviation($edge_distance_support{$edge}->[$j]->[0]) <= $distance && $distance <= add_standard_deviation($edge_distance_support{$edge}->[$j]->[0])){
			$distance_ID = $j;
			last;
		    }
		}
	    }
	    if($distance_ID == -1){
		#New edge distance
##print STDERR " ------------ new distance\n";
		$edge_distance_support{$edge} = () if(! exists $edge_distance_support{$edge});
		push(@{$edge_distance_support{$edge}}, [$distance, $distance, 1]);
		$nb_edge_distance++;
	    }
	    else{
		#Update the edge distance and the support if the distance are similar
		$edge_distance_support{$edge}->[$distance_ID]->[1] += $distance;
		$edge_distance_support{$edge}->[$distance_ID]->[2]++;
	    }
	}
	
#print STDERR " *** ".$nb_edge_distance." number of distance or that edge\n";<STDIN>;

	#Compute the final support
	$best_distance_ID = 0;
	@tmp = keys(%edge_distance_support); $best_edge = $tmp[0];#$best_edge = @{keys(%edge_distance_support)}[0];
	$best_support = $edge_distance_support{$best_edge}->[$best_distance_ID]->[2];
	foreach $edge (keys %edge_distance_support){
	    for(my $j = 0; $j < @{$edge_distance_support{$edge}}; $j++){
		$support = $edge_distance_support{$edge}->[$j]->[2];
		if($best_support < $support){
		    $best_support = $support;
		    $best_distance_ID = $j;
		    $best_edge = $edge;
		}
	    }
	}
	
	#Print the edge with the highest support

	$best_distance = $edge_distance_support{$best_edge}->[$best_distance_ID]->[1] / $edge_distance_support{$best_edge}->[$best_distance_ID]->[2];#Compute the average distance 
	$sd = int(abs($best_distance)*0.1+50);
	#print EDGE "$print{$key}".(int($distance))."\t$sd\t$best_support\n";
	@final_edge_ori = split("\:", $best_edge);
	@contig_ID = split("\t", $edge_read_info{$key}->{"EDGE"});
	$edge_read_info{$key}->{"EDGE"} = $contig_ID[0]."\t".$final_edge_ori[0]."\t".$contig_ID[1]."\t".$final_edge_ori[1];
	print EDGE $edge_read_info{$key}->{"EDGE"}."\t".(int($best_distance))."\t$sd\t$best_support\n";
	
	#Update the read info and print it
	$splice_offset = 0;
	for(my $j = 0; $j < @{$edge_read_info{$key}->{"DIST_LIST"}}; $j++){
	    $read_distance = $edge_read_info{$key}->{"DIST_LIST"}->[$j];#cmp_read];
	    $read_edge_type = $edge_read_info{$key}->{"EDGE_TYPE"}->[$j];
	        if($best_edge ne $read_edge_type ||#this read does not support the correct edge type
		   ! (remove_standard_deviation($best_distance) <= $read_distance && $read_distance <= add_standard_deviation($best_distance))){#this read does not support the correct distance
		    #print STDERR " *** Remove reads ".($edge_read_info{$key}->{"READ_LIST"}->[$splice_offset])." $read_edge_type $read_distance not in [ ".(remove_standard_deviation($best_distance))." ,".(add_standard_deviation($best_distance))."] from $best_edge $best_distance and supported by $best_support reads n\n";
		    splice @{$edge_read_info{$key}->{"READ_LIST"}}, $splice_offset, 1;
		    splice @{$edge_read_info{$key}->{"COORD_CONTIG_1"}}, $splice_offset, 1;
		    splice @{$edge_read_info{$key}->{"COORD_CONTIG_2"}}, $splice_offset, 1;
		    splice @{$edge_read_info{$key}->{"COORD_CONTIG_1_ON_READ"}}, $splice_offset, 1;
		    splice @{$edge_read_info{$key}->{"COORD_CONTIG_2_ON_READ"}}, $splice_offset, 1;
		    splice @{$edge_read_info{$key}->{"CONTIG_GAPFILLING"}}, $splice_offset, 1;
		    #$nb_read_in_edge--;
		}
	    else{
		$splice_offset++;
	    }
	}
	
	print EDGE_READ
	    $edge_read_info{$key}->{"EDGE"}."\t".
	    join(";", @{$edge_read_info{$key}->{"READ_LIST"}})."\t".
	    "COORD_CONTIG_1:".join(";", @{$edge_read_info{$key}->{"COORD_CONTIG_1"}})."\t".
	    "COORD_CONTIG_2:".join(";", @{$edge_read_info{$key}->{"COORD_CONTIG_2"}})."\t".
	    "COORD_CONTIG_1_ON_READ:".join(";", @{$edge_read_info{$key}->{"COORD_CONTIG_1_ON_READ"}})."\t".
	    "COORD_CONTIG_2_ON_READ:".join(";", @{$edge_read_info{$key}->{"COORD_CONTIG_2_ON_READ"}})."\t".
	    "CONTIG_FOR_GAPFILLING:".join(";", @{$edge_read_info{$key}->{"CONTIG_GAPFILLING"}}).
	    "\n";
	
	#if($nb_edge_distance > 1){
	#    print STDERR " *** ".$nb_edge_distance." number of distance or that edge\n";#<STDIN>;
	#}

    }
    #close EDATA;
    close STATUS;
    close MAP;
    close EDGE;
    close EDGE_READ;

    $total = 0;
    foreach $component (sort {$length{$b} <=> $length{$a}} keys(%length)) {

	#print "$length{$component}\n";
	$total += $length{$component};
	if($total > 5e6) {

	    print STDERR "N50: $length{$component}\n"; 
	    last;
	}
    }
}

sub add_standard_deviation{
    my ($d) = @_;
    #print STDERR " **** $d\n";
    return $d + 6 * (abs($d)*0.1+50);
}

sub remove_standard_deviation{
    my ($d) = @_;
    return $d - 6 * (abs($d)*0.1+50);
}


sub CreateConfigFile{
    my( $contigFile, $suffix, $outputDir, @edgeFiles) = @_;
    
    open( CONF, ">config".$suffix ) or die $!;

    print CONF "#\n# Essential Parameters\n#\n\n";
    my $opera_out_folder = "results$suffix";
    
    print CONF "# Output folder for final results\n";
    #print CONF "output_folder=results\n";
    #print CONF "output_folder=results_no_trans\n";
    print CONF "output_folder=$outputDir/$opera_out_folder\n";
    #print CONF "output_folder=results_no_trans_no_conflict\n";
    #print CONF "output_folder=results_no_conflict\n";

    print CONF "# Contig file\n";
    print CONF "contig_file=$contigFile\n";
#TODO This is to make sure scaffolds form when there is 0 coverage. Remove/keep in release

    print CONF "kmer=$kmer_size\n";

    #print CONF "cluster_threshold=2\n";
    print CONF "# Mapped read locations\n";

    #Update the config file to add the illumina mapping
    if(-e "${file_pref}.bam"){
	print CONF "[LIB]\n";
	print CONF "map_file=$outputDir/${file_pref}.bam\n";
	print CONF "cluster_threshold=$short_read_cluster_threshold\n";
    }
    else{
	run_exe("rm -r $opera_out_folder") if(-d $opera_out_folder);
	run_exe("mkdir $opera_out_folder;ln -s ../$file_pref.map.cov $opera_out_folder/contigs");#Get the coverage from long reads
    }
    
    $i = 0;
    @means = (300, 1000, 2000, 5000, 15000, 40000);
    @stds = (30, 100, 200, 500, 1500, 4000);
    foreach $edgeFileName ( @edgeFiles ){
	print CONF "[LIB]\n";
	    #print CONF "cluster_threshold=$cluster_threshold\n";
	print CONF "cluster_threshold=$cluster_threshold_tab[ $i ]\n";
	print CONF "map_file=$outputDir/$edgeFileName\n";
	print CONF "lib_mean=$means[ $i ]\n";
	print CONF "lib_std=$stds[ $i ]\n";
	print CONF "map_type=opera\n";
	$i++;
    }
    
    close CONF;
}



sub run_exe{
    my ($exe) = @_;
    $run = 1;
    print STDERR $exe."\n";;
    print STDERR `$exe` if($run);
}
