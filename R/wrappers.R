#' @import magrittr dplyr
NULL

#' Wrapper function for creating gene TSS object
getGeneTss <- function(gtf.file, kmeans.clustering, verbose = TRUE) {
  if (verbose) cat("Reading GTF file... ")
  gtf <- read.delim("/data/genomes/GRCh38-3.0.0_ens93/genes/genes.gtf", header=F, comment.char="#")
  if (verbose) cat("done!\nExtracting gene TSS regions... ")
  ### modify chromosome names in the gtf file to let it match chromosome names in the reference genome
  gtf[,1] <- paste0('chr',gtf[,1])
  gene_tss <- get_tss_region(gtf,rownames(Kmeans_clustering_ENS))
  if (verbose) cat("done!")
}