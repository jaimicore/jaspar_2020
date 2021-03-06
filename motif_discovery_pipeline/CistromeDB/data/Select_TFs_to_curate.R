#####################
## Load R packages ##
#####################
required.libraries <- c("data.table",
                        "dplyr",
                        "jsonlite",
                        "optparse")
for (lib in required.libraries) {
  if (!require(lib, character.only=TRUE)) {
    install.packages(lib)
    library(lib, character.only=TRUE)
  }
}


####################
## Read arguments ##
####################
# Rscript Select_TFs_to_curate.R -f /storage/scratch/JASPAR_2020/jaspar_2020/motif_discovery_pipeline/CistromeDB/CistromeDB_results/curation -o mouse

option_list = list(
  make_option(c("-f", "--data_folder"), type="character", default=NULL, 
              help="Input table 2", metavar="character"),
  make_option(c("-o", "--organism"), type="character", default=NULL, 
              help="Input table 2", metavar="character")
);
opt_parser = OptionParser(option_list = option_list);
opt = parse_args(opt_parser);

organism <- opt$organism
data.folder <- opt$data_folder

# organism <- "mouse"
# data.folder <- "/run/user/280010/gvfs/sftp:host=biotin3.hpc.uio.no,user=jamondra/storage/scratch/JASPAR_2020/jaspar_2020/motif_discovery_pipeline/CistromeDB/CistromeDB_results/curation"
# # data.folder <- "/storage/scratch/JASPAR_2020/jaspar_2020/motif_discovery_pipeline/CistromeDB/CistromeDB_results/curation"
data.folder <- file.path(data.folder, organism)


########################################
## Use JASPAR API to get the TF names ##
########################################
jaspar.url <- "http://jaspar.genereg.net/api/v1/matrix/?page_size=600&collection=CORE&tax_group=Vertebrates&version=latest&format=json"
result <- fromJSON(jaspar.url)

## Create a dataframe with the motifs info
jaspar.tab <- data.table(result$results)
jaspar.TF.names <- toupper(unique(jaspar.tab$name))


##############################################
## Concat the tables with the curated files ##
##############################################
curation.chunks <- list.files(data.folder)

curation.tab.path <- paste(file.path(data.folder, curation.chunks, "Selected_motifs_to_curate_log10_pval_-200.tab"),
      collapse = " ")

## Command
curation.tab.file <- file.path(data.folder, paste0("Curation_table_all_", organism, ".tab"))
unlink(curation.tab.file)
curation.tab.command <- paste0("cat ", curation.tab.path, " > ", curation.tab.file)
system(curation.tab.command)


############################################################
## Prepare table: format to curate and upload into JASPAR ##
############################################################
curation.tab <- fread(curation.tab.file)
colnames(curation.tab) <- c("Datasets_ID", "TF_name", "TF", "Centrimo", "Centrimo_score", "Logo", "PDF")
curation.tab$TF <- toupper(curation.tab$TF)

## Add missing columns
curation.tab$PWM <- gsub(curation.tab$Centrimo, pattern = "central_enrichment", replacement = "motifs/jaspar/pfm")
curation.tab$PWM <- gsub(curation.tab$PWM, pattern = "(\\d+)_m(\\d+).+centrimo$", replacement = "\\1_peak-motifs_m\\2.jaspar", perl = T)

curation.tab$BED <- gsub(curation.tab$Centrimo, pattern = "central_enrichment", replacement = "matrix_sites")
curation.tab$BED <- gsub(curation.tab$PWM, pattern = "(\\d+)_m(\\d+).+centrimo$", replacement = "\\1_peak-motifs_m\\2.tf.sites.bed", perl = T)

curation.tab$FASTA <- gsub(curation.tab$Centrimo, pattern = "central_enrichment", replacement = "matrix_sites")
curation.tab$FASTA <- gsub(curation.tab$PWM, pattern = "(\\d+)_m(\\d+).+centrimo$", replacement = "\\1_peak-motifs_m\\2.tf.sites.fasta", perl = T)

curation.tab$Organism <- ""
curation.tab$current_BASE_ID <- ""
curation.tab$current_VERSION <- ""
curation.tab$`TF name` <- curation.tab$TF
curation.tab$Uniprot <- ""
curation.tab$TAX_ID <- ""
curation.tab$class <- ""
curation.tab$family <- ""
curation.tab$pazar_tf_id <- ""
curation.tab$tfe_id <- ""
curation.tab$`TFBSshape ID` <- ""
curation.tab$type <- ""
curation.tab$Experiment <- ""
curation.tab$Source <- ""
curation.tab$Validation <- ""
curation.tab$Comment <- ""
curation.tab$`Addition or Upgrade or Non-validated (A or U or N )` <- ""

## Keep columns for annotation
curation.tab <- curation.tab[,c("PWM", "Organism", "current_BASE_ID", "current_VERSION" , "TF name", "Uniprot", "TAX_ID", "class", "family", "pazar_tf_id", "tfe_id", "TFBSshape ID", "type", "Experiment", "Source", "Validation", "Comment", "Addition or Upgrade or Non-validated (A or U or N )", "BED", "FASTA")]


###########################################################
## Filter the table: keep the TFs that are not in JASPAR ##
###########################################################
## TFs not in JASPAR
curation.no.jaspar.tab <- curation.tab %>%
                          dplyr::filter(!`TF name` %in% jaspar.TF.names) %>% 
                          arrange(`TF name`)

message("; Number of datasets: ", nrow(curation.tab))
message("; Number of unique TFs: ", length(unique(curation.tab$`TF name`)))
message("; Number of datasets not in JASPAR: ", nrow(curation.no.jaspar.tab))
message("; Number of unique TFs: ", length(unique(curation.no.jaspar.tab$`TF name`)))

sort(unique(curation.no.jaspar.tab$`TF name`))

#########################################
## Export table with TFS not in JASPAR ##
#########################################
curation.no.jaspar.tab.file <- file.path(data.folder, paste0("Curation_table_not_in_JASPAR_", organism, ".tab"))
fwrite(curation.no.jaspar.tab, curation.no.jaspar.tab.file, sep = "\t")


######################################
## Export PDF with motifs to curate ##
######################################

## Get the PDF file names
curation.no.jaspar.PDFs <- gsub(curation.no.jaspar.tab$PWM,
                                 pattern = "motifs/jaspar/pfm/(\\d+)_peak-motifs_m\\d+.jaspar",
                                 replacement = "central_enrichment/selected_motif/\\1.501bp.fa.sites.centrimo.best.TF_associated.pdf")

curation.no.jaspar.PDFs <- as.vector(curation.no.jaspar.PDFs)
curation.no.jaspar.PDFs <- paste(curation.no.jaspar.PDFs, collapse = " ")

## Concat PDFs command
concat.pdf.file <- file.path(data.folder, paste0("Motifs_to_curate_logos_CistromeDB", organism, ".PDF"))
concat.pdf.cmd <- paste0("pdfunite ", curation.no.jaspar.PDFs, " ", concat.pdf.file)
system(concat.pdf.cmd)


#############################
## Split table in N chunks ##
#############################
# chunk1 <- sample(unique(curation.no.jaspar.tab$`TF name`), size = round(length(unique(curation.no.jaspar.tab$`TF name`))/2), replace = FALSE)
# chunk2 <- unique(curation.no.jaspar.tab$`TF name`)[!unique(curation.no.jaspar.tab$`TF name`) %in% chunk1]
# # print(chunk1)
# # print(chunk2)
# 
# sum(grepl(chunk1, pattern = "ZNF"))
# sum(grepl(chunk2, pattern = "ZNF"))
# 
# curation.chunk.1 <- curation.no.jaspar.tab %>% 
#   dplyr::filter(`TF name` %in% chunk1)
# 
# curation.chunk.2 <- curation.no.jaspar.tab %>% 
#   dplyr::filter(`TF name` %in% chunk2)
# 
# curation.no.jaspar.tab.file <- file.path(data.folder, paste0("Curation_table_not_in_JASPAR_", organism, "_chunk1.tab"))
# fwrite(curation.chunk.1, curation.no.jaspar.tab.file, sep = "\t")
# 
# curation.no.jaspar.tab.file <- file.path(data.folder, paste0("Curation_table_not_in_JASPAR_", organism, "_chunk2.tab"))
# fwrite(curation.chunk.2, curation.no.jaspar.tab.file, sep = "\t")
