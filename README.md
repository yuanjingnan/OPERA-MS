[![Preprint at bioRxiv](https://img.shields.io/badge/preprint-bioRxiv-yellow.svg)](https://www.biorxiv.org/content/early/2018/10/30/456905)

# Introduction 
OPERA-MS is a hybrid metagenomic assembler which combines the advantages of short and long-read technologies to provide high quality assemblies, addressing issues of low contiguity for short-read only assemblies, and low base-pair quality for long-read only assemblies. OPERA-MS has been extensively tested on mock and real communities sequenced using different long-read technologies, including Oxford Nanopore, PacBio and Illumina Synthetic Long Read, and is particularly robust to noise in the read data.

OPERA-MS employs a staged assembly strategy that is designed to exploit even low coverage long read data to improve genome assembly. It begins by constructing a short-read metagenomic assembly (default: [MEGAHIT](https://github.com/voutcn/megahit)) that provides a good representation of the underlying sequence in the metagenome but may be fragmented. Long and short reads are then mapped to the assembly to identify connectivity between the contigs and to compute read coverage information. This serves as the basis for the core of the OPERA-MS algorithm which is to exploit coverage as well as connectivity information to accurately cluster contigs into genomes using a Bayesian model based approach. Another important feature of OPERA-MS is that it can use information from reference genomes to deconvolute strains in the metagenome. After clustering, individual genomes are further scaffolded and gap-filled using the lightweight and robust scaffolder [OPERA-LG](https://sourceforge.net/p/operasf/wiki/The%20OPERA%20wiki/).

OPERA-MS can assemble near complete genomes from a metagenomic dataset with as little as 9x long-read coverage. Applied to human gut microbiome data it provides hundreds of high quality draft genomes, a majority of which have  N50 >100kbp. We observed the assembly of complete plasmids, many of which were novel and contain previously unseen resistance gene combinations. In addition, OPERA-MS can very accurately assemble genomes even in the presence of multiple strains of a species in a complex metagenome, allowing us to associate plasmids and host genomes using longitudinal data. For further details about these and other results using nanopore sequencing on stool samples from clinical studies see our [bioRxiv paper](https://www.biorxiv.org/content/early/2018/10/30/456905). 

# Installation

To install OPERA-MS on a typical Linux/Unix system run the following commands:

```
git clone https://github.com/CSB5/OPERA-MS.git
cd OPERA-MS
make
perl OPERA-MS.pl CHECK_DEPENDENCY
```
If you encounter any problems during the installation, or if some third party software binaries are not functional on your system, please see the [**Dependencies**](#dependencies) section. 

A set of test files and a sample configuration file is provided to test out the OPERA-MS pipeline. To run OPERA-MS on the test data-set, simply use the following commands (please note that the test script runs with 2 cores which is also the minimum.): 
```
cd test_files
perl ../OPERA-MS.pl \
    --contig-file contigs.fasta \
    --short-read1 R1.fastq.gz \
    --short-read2 R2.fastq.gz \
    --long-read long_read.fastq \
    --out-dir RESULTS 2> log.err
```
This will assemble a low diversity mock community in the folder **RESULTS**.
Notice that in case of an interruption during an OPERA-MS run, using the same command line will re-start the execution after the last completed checkpoint.

# Usage

### Essential arguments

- **--short-read1** : `R1.fq.gz` - path to the first read for Illumina paired-end read data

- **--short-read2** : `R2.fq.gz` - path to the second read for Illumina paired-end read data

- **--long-read** : `long-read.fq` - path to the long-read fastq file obtained from either Oxford Nanopore, PacBio or Illumina Synthetic Long Read sequencing

- **--out-dir** : `RESULTS` - directory where OPERA-MS results will be outputted

### Optional arguments 

- **--no-ref-clustering**  : - disable reference level clustering

- **--no-strain-clustering** :  - disable strain level clustering

- **--polishing** : - enable assembly polishing (currently using [Pilon](https://github.com/broadinstitute/pilon/wiki)). The polished contigs can be found in contig.polished.fasta

- **--long-read-mapper** : `default: blasr` - software used for long-read mapping i.e. blasr or minimap2

- **--kmer-size** : `default: 60` - kmer value used to assemble contigs

- **--contig-len-thr** : `default: 500` - contig length threshold for clustering; contigs smaller than CONTIG_LEN_THR will be filtered out

- **--contig-edge-len** : `default: 80` - during contig coverage calculation, number of bases filtered out from each contig end, to avoid biases due to lower mapping efficiency

- **--contig-window-len** : `default: 340` - window length in which the coverage estimation is performed. We recommend using contig_len_thr - 2 * contig_edge_len as the value

- **--contig-file** : `contigs.fa` - path to the contig file, if the short-reads have been assembled previously

- **--num-processor** : `default : 2` - number of processors to use (note that 2 is the minimum)

Alternatively, OPERA-MS parameters can be set using a [configuration file](https://github.com/CSB5/OPERA-MS/wiki/Configuration-file).

### Output

The following output files can be found in the specified output directory i.e. **RESULTS**.
The file **contig.fasta** (and **contig.polished.fasta** if the assembly have been polished) contains the assembled contigs, and **assembly.stats** provides overall assembly statistics (e.g. assembly size, N50, longest contig etc.).
[**contig_info.txt**](https://github.com/CSB5/OPERA-MS/wiki/Contig-info-file-description) provides a detailed overview of the assembled contigs.

Finally, the OPERA-MS strain level clusters can be found in the following directory: **RESULTS/opera_ms_clusters/**.
[**cluster_info.txt**](https://github.com/CSB5/OPERA-MS/wiki/Cluster-info-file-description) provides a detailed overview of the OPERA-MS clusters. Notice that clusters have been obtained using the OPERA-MS conservative clustering that may not cluster a significant number of contigs. More sensitive binning may be obtained using alternative approaches such that [MaxBin2](https://sourceforge.net/projects/maxbin2/) or [MetaBAT2](https://bitbucket.org/berkeleylab/metabat/src/master/).

# OPERA-MS-utils (coming soon ...)

The assembly of a metagenome dataset is only the beginning of long journey, and substential downstrean analysis had to be performed on the assembly to reveal its biology.
To facilitate this process, we are planning to release a utility tool box to allow a streamline analysis of OPERA-MS assemblies. We are planning to include in our first releases methods for: assembly binning, bin assessment, identification of circular contigs and novel species, etc ...
This is a work in progress, and we will be happy to hear your comments and suggestions.

# Performance

The OPERA-MS running time is dependent of the microbiome complexity and of the short/long-read data amount.
We ran OPERA-MS with default parameters using 16 threads on a server with Intel Xeon platinium with a SSD hard drive, on three different dataset:

| Dataset  | Short-read data (Gbp) | Long-read data (Gbp) | Running time (hours)  | Peak RAM usage (Gb) |
|---                 |---|---   |---   |--- |
| low complexity     | 3.9  | 2    | 1.4  | 5.5| 
| medium complexity  | 24.4  | 1.6  | 2.7  | 10.2| 
| high complexity    | 9.9  | 4.8  | 4.5    | 12.8|

To obtain the best assembly performance, OPERA-MS requires a minimum of 30x short-read coverage and 10x long-read coverage. Hence, to assemble a typical bacterial genome (3Mbp) at 1% abundance, 9Gb of short-read data and 3Gb of long-read data are recommended.

# Dependencies

The only true dependency is `cpanm`, which is used to automatically install Perl modules. All other required software comes either pre-compiled with OPERA-MS or is built during the installation process. Binaries are placed inside the __utils__ folder:

1) [MEGAHIT](https://github.com/voutcn/megahit) - (tested with version 1.0.4-beta)
2) [samtools](https://github.com/samtools/samtools) - (version 0.1.19 or below)
3) [bwa](https://github.com/lh3/bwa) - (tested with version 0.7.10-r789)
4) [blasr](https://github.com/PacificBiosciences/blasr) - (version 5.1 and above which uses '-' options)
5) [minimap2]( https://github.com/lh3/minimap2) (tested with version 2.11-r797)
6) [Racon](https://github.com/isovic/racon) - (version 0.5.0)
7) [Mash](https://github.com/marbl/Mash) - (tested with version 1.1.1)
8) [MUMmer](http://mummer.sourceforge.net/) (tested with version 3.23)
9) [Pilon](https://github.com/broadinstitute/pilon/wiki) (tested with version 1.22)

If a pre-built software does not work on the user's machine, OPERA-MS will check if the tool is present in the user's PATH. However, the version of the software may be different than the one packaged. Alternatively, to specify a different directory for the dependency, a link to the software may be placed in the __utils__ folder.

OPERA-MS is written in C++, Python, R and Perl, and makes use of the following Perl modules (installed using [cpanm](https://metacpan.org/pod/distribution/App-cpanminus/bin/cpanm)):

- [Switch](http://search.cpan.org/~chorny/Switch-2.17/Switch.pm)
- [File::Which](https://metacpan.org/pod/File::Which)
- [File::Spec::Functions](https://perldoc.perl.org/File/Spec/Functions.html)
- [Statistics::Basic](http://search.cpan.org/~jettero/Statistics-Basic-1.6611/lib/Statistics/Basic.pod)
- [Statistics::R](https://metacpan.org/pod/Statistics::R)
- [Getopt::Long](http://perldoc.perl.org/Getopt/Long.html)

Once cpanm is installed, simply run the following command to install all the perl modules:
```
perl utils/install_perl_module.pl
```
If the perl libraries cannot be installed under root, the following line should be added to the `.bashrc`:
```
export PERL5LIB="/home/$USER/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}";
```

# Docker
A simple Dockerfile is provided in the root of the repository. To build the image:
```
docker build -t operams .
```
The generic command to run a OPERA-MS docker container after building:
```
docker run \
    -v /host/path/to/indata/:/indata/ \
    -v /host/path/to/outdata/:/outdata/ \
    operams config.file
```
To process data with the dockerized OPERA-MS, directories for in- and outdata should be mounted into the container. An example is shown below for running the test dataset. In the below example the repo was cloned to /home/myuser/git/OPERA-MS/). The repo is needed only for the `sample_files` directory and the `sample_config.config` file. If Docker is running in a VM, as is the case for Windows or OSX, but also when deployed on a cloud platform such as AWS or Azure, a minimum of 2 available cores is required.  

```
docker run \ 
    -v /home/myuser/git/OPERA-MS/sample_files:/sample_files \
    -v /home/myuser/git/OPERA-MS/sample_output:/sample_output \
     operams sample_config.config
```

# Contact information
For additional information, help and bug reports please send an email to: 

- Denis Bertrand <bertrandd@gis.a-star.edu.sg>
- Chengxuan Tong <Tong_Chengxuan@gis.a-star.edu.sg>
- Lorenz Gerber (docker related topics): <lorenzottogerber@gmail.com>


