#' Calculate FOS of footprints
#' @description Calculate the FOS(footprints occupancy score) to identify enriched
#' transcriptions factor, and use these transcription factors to identify significant
#' regulatory relationships
#' @param Wig_list list object, where each element is the \link{cal_footprint_cuts} result
#' of each sample.
#' @param Candid If you follow our our pipline, this parameter should be the
#' second element of the list that generated by get_peaks_genes()
#' @param FOS_threshold numeric, indicating the threshold of footprint occupancy
#' score to identify significant footprints.
#' @param trans_wig logcial, if you use dnase_wig_tracks_both2.py to get wig_list,
#' please set trans_wig parameter as TRUE.
#'
#' @return return related transcription factors of footprints with FOS above FOS_threshold
#' @export
#'
#' @examples load(system.file("extdata", "Candid.rda", package = "IReNA"))
#' load(system.file("extdata", "wig_list.rda", package = "IReNA"))
#' regulatory_relationships <- Footprints_FOS(wig_list, Candid)
Footprints_FOS <- function(Wig_list, Candid, FOS_threshold = 1, trans_wig = FALSE) {
  validInput(Wig_list,'Wig_list','list')
  validInput(Candid,'Candid','df')
  validInput(FOS_threshold,'FOS_threshold','numeric')
  validInput(trans_wig,'trans_wig','logical')
  if (trans_wig == TRUE) {
    Wig_list2 <- Trans_WigToMultirows(Wig_list)
  } else {
    Wig_list2 <- Wig_list
  }
  cutsp2_list <- Add_size_of_motif(Wig_list2, Candid)
  cutsp2_FOS <- Cal_Footprints_FOS(cutsp2_list, FlankFold1 = 3)
  FOS1 <- Combine_Footprints_FOS(cutsp2_FOS)
  FOS2 <- Filter_Footprints(FOS1,FOS_threshold)
  FOSF <- get_potential_regulation(FOS2)
  FOSF_RegM <- FOSF[!duplicated(paste(FOSF[,1],FOSF[,3])),]
  FOSF_RegM <- FOSF_RegM[,c(1,3,2,4)]
  colnames(FOSF_RegM) <- c('TF','Target','Motif','MotifTypeChrStartEndFOS')
  return(FOSF_RegM)
}



Trans_WigToMultirows <- function(Wig_list) {
  list1 <- list()
  for (i in 1:length(Wig_list)) {
    wig <- Trans_WigToMultirows2(as.data.frame(Wig_list[[i]]))
    list1[[i]] <- wig
  }
  return(list1)
}


Trans_WigToMultirows2 <- function(b) {
  rownum <- c()
  col1 <- c()
  for (i in 1:nrow(b)) {
    if (!b[i, ] %in% c(as.character(0:20)) | !b[i, ] %in% 0:20) {
      rownum <- c(rownum, i)
    }
  }
  for (i in 1:length(rownum)) {
    if (i == length(rownum)) {
      acc1 <- b[(rownum[i] + 1):nrow(b), ]
    } else {
      acc1 <- b[(rownum[i] + 1):(rownum[i + 1] - 1), ]
    }
    acc11 <- paste(acc1, collapse = "\t")
    acc2 <- strsplit(b[rownum[i], ], "\t")[[1]]
    acc21 <- strsplit(acc2[2], "=")[[1]][2]
    acc22 <- as.numeric(strsplit(acc2[3], "=")[[1]][2]) - 1
    acc23 <- acc22 + length(acc1)
    acc3 <- paste(acc21, acc22, acc23, acc11, "\t")
    col1 <- c(col1, acc3)
  }
  col1 <- as.data.frame(col1)
}



Add_size_of_motif <- function(cutsp_list, Candid) {
  list1 <- list()
  con2 <- Candid
  Candid[,2] <- as.numeric(Candid[,2])
  Candid[,3] <- as.numeric(Candid[,3])
  Candid[,5] <- as.numeric(Candid[,5])
  Candid[,6] <- as.numeric(Candid[,6])
  for (i in 1:length(cutsp_list)) {
    cuts <- cutsp_list[[i]]
    cuts_footprint <- paste(cuts[,1],cuts[,2],cuts[,3])
    Candid_footprint <- paste(Candid[,1],
                              Candid[,5],Candid[,6])
    check1 <- cuts_footprint==Candid_footprint
    if (length(cuts_footprint)!=length(Candid_footprint)) {
      stop('number of footprints is not equal to number of peaks')
    }
    if (FALSE %in% check1) {
      stop('please check whether all footprints are in Candid')
    }
    size <- Candid[,3] - Candid[,2] +1
    Candid$motifsize <- size
    new_Candid <- cbind(Candid[,c(7,4,8,1,2,3)],cuts[,4])
    list1[[i]] <- new_Candid
  }
  return(list1)
}


Cal_Footprints_FOS <- function(cutsp2_list, FlankFold1 = 3) {
  list1 <- list()
  for (i in 1:length(cutsp2_list)) {
    FP <- cutsp2_list[[i]]
    FOS <- Cal_Footprints_FOS2(FP, FlankFold1 = FlankFold1)
    list1[[i]] <- FOS
  }
  return(list1)
}


Cal_Footprints_FOS2 <- function(FP1, FlankFold1 = 3) {
  FP2 <- apply(FP1, 1, function(X1) {
    MotifSize1 <- as.numeric(X1[3])
    WidthL1 <- floor(MotifSize1 / 2)
    WidthR1 <- MotifSize1 - WidthL1
    WidthL2 <- floor(MotifSize1 * (2 * FlankFold1 + 1) / 2)
    WidthR2 <- MotifSize1 * (2 * FlankFold1 + 1) - WidthL2
    Insertion1 <- strsplit(X1[7], ",")[[1]]
    Midpoint1 <- floor(length(Insertion1) / 2)
    Insertion2 <- as.numeric(Insertion1[c((Midpoint1 - WidthL2 + 1):(Midpoint1 + WidthR2))])

    L1 <- sum(Insertion2[1:(WidthL2 - WidthL1)]) / FlankFold1
    M1 <- sum(Insertion2[(WidthL2 - WidthL1 + 1):(WidthL2 + WidthR1)])
    R1 <- sum(Insertion2[(WidthL2 + WidthR1 + 1):length(Insertion2)]) / FlankFold1
    FOS1 <- min(-log2((M1 + 1) / (L1 + 1)), -log2((M1 + 1) / (R1 + 1)))
    return(c(X1[1:6], as.numeric(FOS1)))
  })

  return(t(FP2))
}



Combine_Footprints_FOS <- function(FOS_list) {
  for (i in 1:length(FOS_list)) {
    FOS1 <- FOS_list[[i]]
    if (i == 1) {
      FOS2 <- FOS1
    } else {
      FOS2 <- cbind(FOS2, FOS1[, ncol(FOS1)])
    }
  }
  colnames(FOS2)[1:6] <- c("Motif", "Target", "MotifSize", "Chr", "Start", "End")
  return(FOS2)
}


Filter_Footprints <- function(FOS1, FOS_cutoff) {
  mFOS1 <- apply(FOS1, 1, function(x1) {
    x2 <- as.numeric(x1[7:length(x1)])
    x3 <- max(x2)
    return(x3)
  })
  FOS2 <- cbind(FOS1, mFOS1)
  colnames(FOS2)[ncol(FOS2)] <- "MaxFOS"
  FOS3 <- FOS2[FOS2[, "MaxFOS"] > FOS_cutoff, ]
  print(nrow(FOS2))
  print(nrow(FOS3))
  return(FOS3)
}



get_potential_regulation <- function(FOSF) {
  potential_regulation <- apply(FOSF,1,get_potential_regulation2)
  potential_regulation <- do.call(dplyr::bind_rows,potential_regulation)
  return(potential_regulation)
}

get_potential_regulation2 <- function(regulation){
  source <- strsplit(regulation[1],'\\|')[[1]]
  TFs <- c()
  motif <- c()
  for (i in source) {
    source2 <- strsplit(i,';')[[1]]
    motif1 <- source2[1]
    TF1 <- source2[-1]
    TFs <- c(TFs,TF1)
    motif <- c(motif,rep(motif1,length(TF1)))
  }
  target <- unlist(strsplit(strsplit(regulation[2],';')[[1]],'\\|'))
  target_gene <- target[seq(1,length(target),2)]
  target_gene2 <- c()
  for (i in target_gene) {
    target_gene2 <- c(target_gene2,strsplit(i,',')[[1]])
  }
  target_gene <- target_gene2
  annotation <- target[2]
  type <- paste(annotation,regulation[4],regulation[5],regulation[6],
                regulation[length(regulation)],sep = ',')
  AllTFs <- rep(TFs,length(target_gene))
  Allgenes <- rep(target_gene,each=length(TFs))
  AllType <- rep(type,length(AllTFs))
  potential_regulation <- data.frame(AllTFs,motif,Allgenes,AllType)
  return(potential_regulation)
}


Merge_same_pairs <- function(FOSF_Reg) {
  con1 <- FOSF_Reg
  hash1 <- list()
  for (i in 1:nrow(con1)) {
    var1 <- paste(as.character(con1[i, ][c(1, 3)]), collapse = "\t")
    var2 <- paste(as.character(con1[i, ][c(2, 4)]), collapse = ",")
    if (is.null(hash1[var1]) == FALSE) {
      hash1[[var1]] <- c(hash1[[var1]], var2)
    } else {
      hash1[var1] <- var2
    }
  }
  name1 <- names(hash1)
  name1 <- sort(name1)
  col1 <- c(paste("TF", "Target", "MotifTypeChrStartEndFOS", sep = "\t"))
  for (i in 1:length(name1)) {
    acc1 <- paste(unlist(hash1[name1[i]]), collapse = ";")
    var1 <- paste(name1[i], acc1, sep = "\t")
    col1 <- c(col1, var1)
  }
  col2 <- as.data.frame(col1)
  col2 <- split_dataframe(col2)
  colnames(col2) <- col2[1, ]
  col2 <- col2[-1, ]
  return(col2)
}



Merge_TFs_genes <- function(FOSF_RegM) {
  con1 <- FOSF_RegM
  hash1 <- list()
  hash2 <- list()
  for (i in 1:nrow(con1)) {
    var1 <- con1[i, ][2:3]
    var2 <- con1[i, ][c(1, 3)]
    gene1 <- as.character(con1[i, ][1])
    gene2 <- as.character(con1[i, ][2])
    if (is.null(hash1[gene1]) == FALSE) {
      hash1[[gene1]] <- c(hash1[[gene1]], var1)
    } else {
      hash1[gene1] <- var1
    }
    if (is.null(hash2[gene2]) == FALSE) {
      hash2[[gene2]] <- c(hash2[[gene2]], var2)
    } else {
      hash2[gene2] <- var2
    }
  }
  col1 <- c()
  col2 <- c()
  col1 <- c(paste("TF", "Target", "MotifTypeChrStartEndFOS", sep = "\t"), col1)
  col2 <- c(paste("Target", "TF", "MotifTypeChrStartEndFOS", sep = "\t"), col2)
  for (i in 1:2) {
    if (i == 1) {
      hash3 <- hash1
    } else {
      hash3 <- hash2
    }
    name1 <- names(hash3)
    name1 <- sort(name1)
    col3 <- c()
    for (j in 1:length(name1)) {
      num <- seq(1, length(hash3[[name1[j]]]), by = 2)
      acc1 <- paste(unlist(hash3[[name1[j]]][num]), collapse = "|")
      acc2 <- paste(unlist(hash3[[name1[j]]][num + 1]), collapse = "|")
      var1 <- paste(name1[j], acc1, acc2, sep = "\t")
      col3 <- c(col3, var1)
    }
    if (i == 1) {
      col1 <- c(col1, col3)
    } else {
      col2 <- c(col2, col3)
    }
  }
  col1 <- as.data.frame(col1)
  col2 <- as.data.frame(col2)
  col1 <- split_dataframe(col1)
  col2 <- split_dataframe(col2)
  colnames(col1) <- col1[1, ]
  colnames(col2) <- col2[1, ]
  col1 <- col1[-1, ]
  col2 <- col2[-1, ]
  list1 <- list(col1, col2)
  return(list1)
}


#' Calculate correlation of each gene pair, and remove genes that are below the
#' threshold and are not transcription factors
#'
#' @param Kmeans_result Kmeans result, rownames should be ENSEMBL ID, first column
#' should be Symbol ID, second column should be KmeansGroup
#' @param motif motif file, you can choose our bulit-in motif database of
#' 'mus musculus', 'homo sapiens', 'zebrafish' and 'chicken' by 'motif = Tranfac201803_Mm_MotifTFsF',
#' 'motif = Tranfac201803_Hs_MotifTFsF', 'motif = Tranfac201803_Zf_MotifTFsF',
#' 'motif = Tranfac201803_Ch_MotifTFsF' respectively, or you can upload your own motif data base, but the formata use be the same as our built-in motif database.
#' @param correlation_filter numeric, indicating correlation threshold
#' @param start_column numeric, indicating the start column of expression value,
#' defalut is 4
#' @importFrom reshape2 melt
#' @return return a table contain transcription factor with correlation >
#' correlation_filter and correlation < -correlation_filter
#' @export
#'
#' @examples load(system.file("extdata", "test_clustering.rda", package = "IReNA"))
#' test_clustering=add_ENSID(test_clustering,Spec1 = 'Hs')
#' correlation <- get_cor(test_clustering, Tranfac201803_Hs_MotifTFsF, 0.7, start_column=3)

get_cor <- function(Kmeans_result, motif, correlation_filter, start_column=4) {
  validInput(Kmeans_result,'Kmeans_result','list')
  validInput(motif,'motif','df')
  validInput(correlation_filter,'correlation_filter','numeric')
  validInput(start_column,'start_column','numeric')
  cor1 <- sparse.cor(t(Kmeans_result[,start_column:ncol(Kmeans_result)]))
  cor2 <- reshape2::melt(cor1)
  cor2 <- cor2[cor2[,3]>correlation_filter | cor2[,3]< -correlation_filter,]
  motifgene <- c()
  for (i in 1:nrow(motif)) {
    gene1 <- strsplit(motif[i,5],';')[[1]]
    motifgene <- c(motifgene,gene1)
  }
  cor2 <- cor2[cor2$Var1 %in% motifgene,]
  colnames(cor2) <- c('TF','Target','Correlation')
  SourceIdx <- match(cor2[,1],rownames(Kmeans_result))
  TargetIdx <- match(cor2[,2],rownames(Kmeans_result))
  source2 <- Kmeans_result[SourceIdx,c(1,2)]
  colnames(source2) <- c('TFSymbol','TFGroup')
  target2 <- Kmeans_result[TargetIdx,c(1,2)]
  colnames(target2) <- c('TargetSymbol','TargetGroup')
  regulatory_relationships <- cbind(cor2,source2,target2)
  regulatory_relationships <- regulatory_relationships[,c(1,4,5,2,6,7,3)]
  return(regulatory_relationships)
}



sparse.cor <- function(x){
  n <- nrow(x)
  cMeans <- colMeans(x)
  cSums <- colSums(x)
  # Calculate the population covariance matrix.
  # There's no need to divide by (n-1) as the std. dev is also calculated the same way.
  # The code is optimized to minize use of memory and expensive operations
  covmat <- tcrossprod(cMeans, (-2*cSums+n*cMeans))
  crossp <- as.matrix(crossprod(x))
  covmat <- covmat+crossp
  sdvec <- sqrt(diag(covmat)) # standard deviations of columns
  covmat/crossprod(t(sdvec)) # correlation matrix
}



#' filter regulatory relationships based on footprints with high FOS
#' @description overlap footprints information with regulatory relationships
#' @param FOS footprints information, generated in \link{Footprints_FOS}
#' @param regulary_relationships generated in \link{get_cor}
#'
#' @return overlapped regulatory relationships
#' @export
#'
#' @examples
filter_ATAC <- function(FOS,regulary_relationships){
  validInput(regulary_relationships,'regulary_relationships','df')

  if (grepl("ENS", FOS[1,1])) {
    TfIndex <- 1
  }else{TfIndex <- 2}
  if (grepl("ENS", FOS[1,2])) {
    TargetIndex <- 4
  }else{TargetIndex <- 5}
  pair1 <- paste(FOS[,1],FOS[,2])
  pair2 <- paste(regulary_relationships[,TfIndex],
                 regulary_relationships[,TargetIndex])
  filtered <- regulary_relationships[pair2 %in% pair1,]
  return(filtered)
}
