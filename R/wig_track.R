#' Calculate cuts
#' @description Function to calculate cuts of each position in footprints
#' @param bamfilepath character, indicating the path of bam file
#' @param bedfile bed file of footprints, generated by get_peaks_genes()
#' @param index_bam logical, indicating whether to index the bam file. If bam
#' file do not have a matched bai file, this parameter should be TRUE
#' @param workers number of cores
#' @importFrom Rsamtools PileupParam
#' @importFrom Rsamtools pileup
#' @importFrom Rsamtools indexBam
#' @importFrom dplyr group_by
#' @importFrom dplyr summarise
#' @importFrom parallel makeCluster
#' @importFrom parallel stopCluster
#' @return return formated wig file
#' @export
#'
#' @examples load(system.file("extdata", "list1.rda", package = "IReNA"))
#' load(system.file("extdata", "test_clustering.rda", package = "IReNA"))
#' bamfilepath1<-'mmATACCtrW00R1_CuFiQ10No_sorted.bam'
#' bamfilepath2<-'mmATACCtrW00R2_CuFiQ10No_sorted.bam'
#' test_clustering <- add_ENSID(test_clustering, Spec1 = "Hs")
#' list2<-get_related_peaks(list1,test_clustering)
#' #cuts1<-cal_footprint_cuts(bamfilepath = bamfilepath1,bedfile = list2[[1]])
#' #cuts2<-cal_footprint_cuts(bamfilepath = bamfilepath2,bedfile = list2[[1]])
#' #cuts_list<-list(cuts1,cuts2)
cal_footprint_cuts <- function(bamfilepath, bedfile, index_bam = FALSE,workers = NULL) {
  validInput(bedfile,'bedfile','df')
  validInput(bamfilepath,'bamfilepath','fileexists')
  validInput(index_bam,'index_bam','logical')
  footprints <- bedfile
  future::plan(future::multisession, workers = workers)
  p_param <- Rsamtools::PileupParam(min_base_quality = 10L)
  if (index_bam == TRUE) {
    Rsamtools::indexBam(bamfilepath)
  }
  res <- Rsamtools::pileup(bamfilepath, pileupParam = p_param)
  seq_depth <- dplyr::group_by(res,seqnames,pos)
  seq_depth <- dplyr::summarise(seq_depth,depth = sum(count))
  cuts <- CalCuts(seq_depth,worker = workers)
  cuts$cuts <- c(cuts$cuts[-nrow(cuts)],cuts[nrow(cuts),3])
  cl<-parallel::makeCluster(workers)
  bed_cuts <- parallel::parApply(cl, footprints, get("FootprintCuts"),
                                 MARGIN = 1,cuts = cuts,seq_depth=seq_depth)
  parallel::stopCluster(cl)
  bed_cuts <-as.data.frame(bed_cuts)
  bed_cuts <- cbind(bedfile,bed_cuts)
  return(bed_cuts)
}

CalCuts <- function(df,worker = NULL){
  future::plan(future::multisession, workers = worker)
  cal_cuts <- function(test_df,worker = worker){
    df1 <- data.frame(
      start = c(1,which(diff(test_df$pos) != 1)+1),
      end = c(which(diff(test_df$pos) != 1),length(test_df$pos))
    )
    main_fun<- function(i){
      test_df2 <- test_df[df1[i,1]:df1[i,2],]
      test_df2$cuts <- c(test_df2$depth[1],abs(diff(test_df2$depth)))
      return(test_df2)
    }
    test_last <- furrr::future_map_dfr(1:nrow(df1),main_fun)
    return(test_last)
  }
  test_list <- purrr::map(unique(df$seqnames),function(chr,df1 = df){
    test_df <- dplyr::filter(df1,seqnames == chr)
  })
  res_allchr <- furrr::future_map_dfr(test_list,cal_cuts,worker= worker)
  return(res_allchr)
}

FootprintCuts <- function(x,cuts,seq_depth){
  cut_all <- c()
  seq_len <- c(x[2]:x[3])
  cut_pos <- rep(0,length(seq_len))
  cuts_chr <- dplyr::filter(cuts, seqnames==x[1])
  cuts1 <- cuts_chr[cuts_chr$pos%in%seq_len,4]$cuts
  cut_pos[seq_len %in% seq_depth$pos]=cuts1
  naidx <- grep(FALSE,seq_len %in% seq_depth$pos)
  if (length(naidx)>0) {
    for (i in naidx) {
      next_pos <- as.character((seq_len[i]+1))
      if (next_pos %in% cuts_chr$pos) {
        cut_pos[i] = cuts_chr[cuts_chr$pos==next_pos,3]
      } else{cut_pos[i]=0}
    }
  }
  cuts_final <- paste0(cut_pos,collapse = ',')
  cut_all <- c(cut_all,cuts_final)
  return(cut_all)
}

