from genfunc import *
import pandas as pd


def is_zip(in_file):
    res = False
    if(in_file.endswith(".gz")):
        res = True
    return res

def get_correlation(assembly_dir):
    
    species_df = pd.read_csv("{}/read-concordance/S_abundance_comparison.txt".format(assembly_dir), header = 0, sep = "\t")
    genus_df = pd.read_csv("{}/read-concordance/G_abundance_comparison.txt".format(assembly_dir), header = 0, sep = "\t")
    species_corr = species_df['Short_read_abundance'].corr(species_df['Long_read_abundance'])
    genus_corr = genus_df['Short_read_abundance'].corr(genus_df['Long_read_abundance'])
    out_file = "{}/read-concordance/correlation_value.txt".format(assembly_dir)
    
    with open(out_file, "w") as fp:
        fp.write("genus_level_correlation\t{}\n".format(genus_corr))
        fp.write("species_level_correlation\t{}\n".format(species_corr))

    
def run_kraken2(assembly_dir, read1, read2, long_read, nb_thread, abundance_threshold):
    kraken_db = util_dir + "/../utils_db/kraken_db"
    
    out_dir = assembly_dir + "/read-concordance"
    create_dir(out_dir)
    #Short read
    out_file = out_dir + "/short_read.out"
    out_file_report = out_file + ".report"
    compress_format = ""
    if(is_zip(read1)):
       compress_format = "--gzip-compressed"
    if not os.path.exists(out_file_report):
        run_exe(util_dir + "/kraken2/kraken2" + " --db " +  kraken_db + " --threads " + str(nb_thread) + " --paired " + compress_format + " --output " + out_file + " --report " + out_file_report + " " + read1 + " " + read2, True)
    #
    #long read
    out_file = out_dir + "/long_read.out"
    out_file_report = out_file + ".report"
    compress_format = ""
    if(is_zip(long_read)):
        compress_format = "--gzip-compressed"
    if not os.path.exists(out_file_report):
        run_exe(util_dir + "/kraken2/kraken2" + " --db " +  kraken_db + " --threads " + str(nb_thread) + " " + compress_format + " --output " + out_file + " --report " + out_file_report + " " + long_read, True)
    
    #Comapare the abundance profile
    compare_abundance_profile(out_dir, out_dir + "/short_read.out.report", out_dir + "/long_read.out.report", "S", abundance_threshold)
    compare_abundance_profile(out_dir, out_dir + "/short_read.out.report", out_dir + "/long_read.out.report", "G", abundance_threshold)
    
    get_correlation(assembly_dir)
    run_exe("rm {}/*.out".format(out_dir), True)

def compare_abundance_profile(out_dir, short_read_profile, long_read_profile, tax_level, abundance_threshold):
    tax_abundance_comparison = {}
    read_profile(short_read_profile, tax_level, abundance_threshold, tax_abundance_comparison, 0)
    read_profile(long_read_profile, tax_level, abundance_threshold, tax_abundance_comparison, 1)
    #
    OUT = open(out_dir + "/" + tax_level + "_abundance_comparison.txt", "w")
    OUT.write("Tax_name\tShort_read_abundance\tLong_read_abundance\n")
    for tax in tax_abundance_comparison:
        OUT.write("{}\t{}\t{}\n".format(tax, tax_abundance_comparison[tax][0], tax_abundance_comparison[tax][1]))
    OUT.close()

def read_profile(profile, tax_level, abundance_threshold, abundance_comparison, col):
    FILE = open(profile, "r")
    for line in FILE:
        #print line
        line_list = line.split("\t")
        tax = line_list[3]
        abundance = float(line_list[0].strip())
        tax_name = ((line_list[5].lstrip()).rstrip()).replace(" ", "_")
        if tax == tax_level and abundance > abundance_threshold:
            #print tax + " |" + abundance + "| |" + tax_name + "|\n"
            if tax_name not in abundance_comparison:
                abundance_comparison[tax_name] = {0:0, 1:0}
            abundance_comparison[tax_name][col] = abundance
    FILE.close()
