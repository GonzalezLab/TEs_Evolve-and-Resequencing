#!/usr/bin/env Rscript

library(DescTools) 
library(GenomicRanges)
library(tidyr)
library(dplyr)

args = commandArgs(trailingOnly=TRUE)
#args[1]: path to the folder with the diferent subfolders (pools) containing the TEMP output files (i.e., "/home/")
#args[2]: path to the results folder

### Read TEMP output files (avoid this step if the script 1.Griffin.r was already run before)
parent.f <- args[1]
parent.0 <- args[2]

list.dirs  <- dir(parent.f, pattern ="*summary")

for (d in 1:length(list.files)) {
	setwd(parent.f)
	input <- list.files[d]
	name <- strsplit(input, split="-", fixed=T)[[1]][1]
	output <- paste(name, ".insertion.1p1.f0.10.txt", sep="")

	# Read input	
	x <- read.table(input, header=T, sep="\t", fill=T, row.names=NULL)
	y <- x
	colnames(y) <- colnames(x)[-1]

	# Get only those insertions supported by reads at both sides and with freq > 0.10
	ins.1p1.0.10 <- y[as.numeric(as.character(y[,8])) > 0.10 & y[,6] == "1p1", ] 
	
	# Predicted junctions with bp-resolution (columns 10,11:13 with values different from 0) = Narrow junctions
	ins.1p1.0.10.ref.1 <- NULL
	for (i in 1:length(ins.1p1.0.10[,1])) {
		if (as.numeric(ins.1p1.0.10[i,10]) != 0 && as.numeric(ins.1p1.0.10[i,12]) != 0 && as.numeric(ins.1p1.0.10[i,13]) != 0 && as.numeric(ins.1p1.0.10[i,14]) != 0) {		
			ins.1p1.0.10.ref.1 <- rbind(ins.1p1.0.10.ref.1, ins.1p1.0.10[i, c(1,9,11,4:8,10,12:14)])		
		} 
	}
		
	# Predicted junctions with bp-resolution (columns 10,11:13 with some value = 0) = Broad junctions
	ins.1p1.0.10.ref.2 <- NULL
	for (i in 1:length(ins.1p1.0.10[,1])) {	
		if (as.numeric(ins.1p1.0.10[i,10]) == 0 || as.numeric(ins.1p1.0.10[i,12]) == 0 || as.numeric(ins.1p1.0.10[i,13]) == 0 || as.numeric(ins.1p1.0.10[i,14]) == 0) {	 
			ins.1p1.0.10.ref.2 <- rbind(ins.1p1.0.10.ref.2, ins.1p1.0.10[i, c(1:8,10,12:14)]) 
		}
	}	
		
	# Include the name of the strain for each input file (ex: AK2_1D, AK2_2D...)	
	strain <- rep(name, length(ins.1p1.0.10.ref.1[,1]))
	ins.1p1.0.10.ref.1 <- cbind(ins.1p1.0.10.ref.1, strain)
	strain <- rep(name, length(ins.1p1.0.10.ref.2[,1]))
	ins.1p1.0.10.ref.2 <- cbind(ins.1p1.0.10.ref.2, strain)	

	# Join both the Narrow and Broad junction and name the final data.frame
	ins.1p1.0.10.ref.1 <- unname(ins.1p1.0.10.ref.1)
	ins.1p1.0.10.ref.2 <- unname(ins.1p1.0.10.ref.2)
	colnames(ins.1p1.0.10.ref.1) <- c("Chr", "Start", "End", "TransposonName", "TransposonDirection", "Class", "VariantSupport", "Frequency", "Junction1Support", "Junction2Support", "5'_Support", "3'_Support", "Strain")
	colnames(ins.1p1.0.10.ref.2) <- c("Chr", "Start", "End", "TransposonName", "TransposonDirection", "Class", "VariantSupport", "Frequency", "Junction1Support", "Junction2Support", "5'_Support", "3'_Support", "Strain")
	ins.1p1.0.10.ref <- rbind(ins.1p1.0.10.ref.1, ins.1p1.0.10.ref.2)

	# Remove those TEs that are the same in the same chr and coordinates but annotated twice		
	data.f0.10.final <- data.f0.10.final.j <- data.f0.10.1.final <- data.f0.10.2.final <- mr.f0.10 <- mr1.f0.10 <- NULL

	# Non-duplicated TEs
	te.j.f0.10 <- ins.1p1.0.10.ref %>% unite(All, c(Chr, Start,  End, TransposonName), sep = "//", remove = TRUE)	

	# Duplicated TEs
	te.d.f0.10 <- te.j.f0.10[duplicated(te.j.f0.10[,1]), ]
	data.f0.10.1.final <- te.j.f0.10[!(te.j.f0.10[,1] %in% te.d.f0.10[,1]), ]

	# Select, among the duplicated TEs, the annotation with more supported reads
	for (i in 1:length(te.d.f0.10[,1])) {	
	 	ind.f0.10 <- which(te.j.f0.10[,1] == te.d.f0.10[i, 1])
	 	mr.f0.10 <- NULL
	 	for (j in 1:length(ind.f0.10)) {
	 		mr.f0.10 <- rbind(mr.f0.10, te.j.f0.10[ind.f0.10[j], ])
	 	}
	 	mr1.f0.10 <- mr.f0.10[mr.f0.10[,4] == max(mr.f0.10[,4]), ]
	 	data.f0.10.2.final <- rbind(data.f0.10.2.final, mr1.f0.10[1, ])
	}	 

	# Join the non-duplicated TEs and those among the duplicated with more supponting reads
	data.f0.10.final.j <- rbind(data.f0.10.1.final, data.f0.10.2.final)	 
	data.f0.10.final.j <- na.omit(data.f0.10.final.j) #This is in case that there were duplicated TEs and hence data.f0.10.final.j in filled with NAs 
	data.f0.10.final <- cbind(matrix(unlist(strsplit(data.f0.10.final.j$All, split="//", fixed=T)), ncol=4, byrow=T, dimnames=list(NULL, c("Chr", "Start", "End", "TransposonName"))), data.f0.10.final.j[, c(2:10)])
	data.f0.10.final[, 2] <- as.numeric(as.character(data.f0.10.final[,2]))
	data.f0.10.final[, 3] <- as.numeric(as.character(data.f0.10.final[,3]))
	
	write.table(data.f0.10.final, file=paste(parent.o, output, sep=""), quote=F, col.names=T, row.names=F, sep="\t")	 	
}

### Compare selection pool to each control pool
list.files.temp  <- dir(parent.o, pattern = ".insertion.1p1.f0.10.txt")

for (f in 1:length(list.files.temp)) {
	temp.f <- NULL
	input.temp <- paste(parent.o, list.files.temp[f], sep="")
	temp <- read.table(file=paste(parent.o, list.files.temp[f], sep=""), header=T)
	temp.f <- cbind(temp, matrix("NA", ncol=1, nrow=length(temp[,1])))
	temp.f[, 14] <- as.numeric(temp.f[, 14])
	name <- strsplit(list.files.temp[f], split=".", fixed=T)[[1]][1]
	
	for (l in 1:length(temp[,1])) {
		ref <- round((as.numeric(temp[l,7]) - (as.numeric(temp[l,8])*as.numeric(temp[l,7])))/as.numeric(temp[l,8]))	
		temp.f[l, 14] <- round((as.numeric(temp[l,7]) - (as.numeric(temp[l,8])*as.numeric(temp[l,7])))/as.numeric(temp[l,8]))	
	}
	colnames(temp.f)[14]<- "Reads_ref"
	write.table(temp.o, file=paste(parent.o, name, ".insertion.1p1.f0.10.final_ref.txt", sep=""), 
	quote=F, sep="\t", row.names=F, col.names=T)
}
										   
list.files.sel  <- dir(parent.o, pattern ="AK2_.*D.insertion.1p1.f0.10.final_ref.txt") 
list.files.con  <- dir(parent.o, pattern ="AK2_.*C.insertion.1p1.f0.10.final_ref.txt")

for (s in 1:length(list.files.sel)) {
	input.s <- read.table(file=paste(parent.o, list.files.sel[s], sep=""), sep="\t", header=T)
	input.s.n <- input.s %>% unite(Chr_TE_ID, c(Chr, TransposonName), sep = "&&", remove = TRUE)
    name.s <- strsplit(list.files.sel[s], split=".", fixed=T)[[1]][1]			
	
	# Controls
	for (f in 1:length(list.files.con)) {										
		input.c <- read.table(file=paste(parent.o, list.files.con[f], sep=""), sep="\t", header=T)
		input.c.n <- input.c %>% unite(Chr_TE_ID, c(Chr, TransposonName), sep = "&&", remove = TRUE)
		data1 <- NULL
		name.c <- strsplit(list.files.con[f], split=".", fixed=T)[[1]][1]
		for (i in 1:length(input.s.n[,1])) {
			for (j in 1:length(input.c.n[,1])) {
				if (input.s.n[i,1] == input.c.n[j,1]) {
					if (c(input.s.n[i,2],input.s.n[i,3]) %overlaps% c(input.c.n[j,2], input.c.n[j,3])) {
						pval <- fisher.test(matrix(c(as.numeric(input.s.n[i,6]), as.numeric(input.s.n[i,13]), 
											as.numeric(input.c.n[j,6]), as.numeric(input.c.n[j,13])), nrow=2, ncol=2, byrow=T))$p.val
						data1 <- rbind(data1, c(strsplit(input.s.n[i,1], split="&&")[[1]][1], 
										strsplit(input.s.n[i,1], split="&&")[[1]][2], input.s.n[i,2], input.s.n[i,3], input.c.n[j,2], 
										input.c.n[j,3], input.s.n[i,7], input.c.n[j,7], scientific(as.numeric(pval), digits=2)))
					}
				}		
			}
		}
		
		# P-values
		colnames(data1) <- c("Chr", "TE_ID", "Start_SEL", "Stop_SEL", "Start_CTR", "Stop_CTR", "Freq_SEL", 
							"Freq_CTR", "Pval")
		write.table(data1, file=paste(parent.o, "Freqs_", name.s, "-", name.c, "_f0.10.Pval_reads_temp.txt", sep=""), 
					quote=F, sep="\t", row.names=F, col.names=T)

		data2 <- data1
		data2 <- cbind(data2, rep("-", length(data2[,1])) )
		for (d in 1:length(data2[,1])) {
			if ( as.numeric(data2[d,9]) < (0.05/length(data2[,1])) ) {
				data2[d,10] <- "*"
			}
			if (as.numeric(data2[d,9]) < (0.01/length(data2[,1])) ) {
				data2[d,10] <- "**"
			}
		}
		
		# Bonferroni Correction
		colnames(data2) <- c("Chr", "TE_ID", "Start_SEL", "Stop_SEL", "Start_CTR", "Stop_CTR", "Freq_SEL", 
							"Freq_CTR", "Pval", "Pval_BF")
		write.table(data2, file=paste(parent.o, "Freqs_", name.s, "-", name.c, "_f0.10.Pval_BF_reads_temp.txt", sep=""), 
					quote=F, sep="\t", row.names=F, col.names=T)
	}
}

### Compare each selection pool to all controls
# Selection pool A
list.files.sel  <- dir(parent.o, pattern ="Freqs_AK2_1D-AK2_.*C_f0.10.Pval_BF_reads_temp.txt")

input.sa <- read.table(file=paste(parent.o, list.files.sel[1], sep=""), sep="\t", header=T)
input.sb <- read.table(file=paste(parent.o, list.files.sel[2], sep=""), sep="\t", header=T)
input.sc <- read.table(file=paste(parent.o, list.files.sel[3], sep=""), sep="\t", header=T)

sall <- r.sel <- sa <- NULL
sall <- rbind(input.sa, input.sb, input.sc)
sall.u <- sall %>% unite(Chr_TE_ID, c(Chr, TE_ID), sep = "&&", remove = TRUE)
p.ranges <- GRanges(sall.u$Chr_TE_ID, IRanges(sall.u$Start_SEL, sall.u$Stop_SEL))
p.ranges.red <- reduce(p.ranges)
p.new.int <- as.data.frame(p.ranges.red)
r.sel <- cbind(unlist(sapply(strsplit(as.character(p.new.int[,1]),'&&'), "[", 1)), 
				unlist(sapply(strsplit(as.character(p.new.int[,1]),'&&'), "[", 2)), p.new.int[,2], 
				p.new.int[,3])  
r.sel1 <- as.data.frame(r.sel, stringsAsFactors=FALSE) 
r.sel1[,3] <- as.numeric(r.sel1[,3])
r.sel1[,4] <- as.numeric(r.sel1[,4])
colnames(r.sel1) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new")

sa <- cbind(r.sel1, as.data.frame(matrix("NA", nrow=length(p.new.int[,1]), ncol=24), stringsAsFactors=FALSE))  

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(input.sa[,1])) {
		if (r.sel1[i,1] == input.sa[j,1] && r.sel1[i,2] == input.sa[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(input.sa[j,5], input.sa[j,6])) {
				sa[i, c(5:12)] <- input.sa[j, c(3:10)]
			}
	    }
	}	
}				

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(input.sb[,1])) {
		if (r.sel1[i,1] == input.sb[j,1] && r.sel1[i,2] == input.sb[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(input.sb[j,5], input.sb[j,6])) {
				sa[i, c(13:20)] <- input.sb[j, c(3:10)]
			}
	    }
	}	
}

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(input.sc[,1])) {
		if (r.sel1[i,1] == input.sc[j,1] && r.sel1[i,2] == input.sc[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(input.sc[j,5], input.sc[j,6])) {
				sa[i, c(21:28)] <- input.sc[j, c(3:10)]
			}
	    }
	}	
}

sa[, 12] <- gsub("1", "-", sa[, 12])
sa[, 12] <- gsub("2", "*", sa[, 12])
sa[, 12] <- gsub("3", "**", sa[, 12])
sa[, 20] <- gsub("1", "-", sa[, 20])
sa[, 20] <- gsub("2", "*", sa[, 20])
sa[, 20] <- gsub("3", "**", sa[, 20])
sa[, 28] <- gsub("1", "-", sa[, 28])
sa[, 28] <- gsub("2", "*", sa[, 28])
sa[, 28] <- gsub("3", "**", sa[, 28])

colnames(sa)[5:28] <- c("Start_SELA","Stop_SELA", "Start_CTRA","Stop_CTRA", "Freq_SELA", "Freq_CTRA", "Pval", "Pval_BF", 
						"Start_SELA","Stop_SELA", "Start_CTRB", "Stop_CTRB", "Freq_SELA", "Freq_CTRB", "Pval", "Pval_BF", 
						"Start_SELA","Stop_SELA", "Start_CTRC", "Stop_CTRC", "Freq_SELA", "Freq_CTRC", "Pval", "Pval_BF")

write.table(sa, file=paste(parent.o, "Freqs_AK2_1D-3CTRs_f0.10.Pval_BF_reads_temp.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)

# Selection pool B
list.files.sel  <- dir(parent.o, pattern ="Freqs_AK2_2D-AK2_.*C_f0.10.Pval_BF_reads_temp.txt")

input.sa <- read.table(file=paste(parent.o, list.files.sel[1], sep=""), sep="\t", header=T)
input.sb <- read.table(file=paste(parent.o, list.files.sel[2], sep=""), sep="\t", header=T)
input.sc <- read.table(file=paste(parent.o, list.files.sel[3], sep=""), sep="\t", header=T)

sall <- r.sel <- sa <- NULL
sall <- rbind(input.sa, input.sb, input.sc)
sall.u <- sall %>% unite(Chr_TE_ID, c(Chr, TE_ID), sep = "&&", remove = TRUE)
p.ranges <- GRanges(sall.u$Chr_TE_ID, IRanges(sall.u$Start_SEL, sall.u$Stop_SEL))
p.ranges.red <- reduce(p.ranges)
p.new.int <- as.data.frame(p.ranges.red)
r.sel <- cbind(unlist(sapply(strsplit(as.character(p.new.int[,1]),'&&'), "[", 1)), 
				unlist(sapply(strsplit(as.character(p.new.int[,1]),'&&'), "[", 2)), 
				p.new.int[,2], p.new.int[,3])  
r.sel1 <- as.data.frame(r.sel, stringsAsFactors=FALSE) 
r.sel1[,3] <- as.numeric(r.sel1[,3])
r.sel1[,4] <- as.numeric(r.sel1[,4])
colnames(r.sel1) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new")

sa <- cbind(r.sel1, as.data.frame(matrix("NA", nrow=length(p.new.int[,1]), ncol=24), stringsAsFactors=FALSE))  

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(input.sa[,1])) {
		if (r.sel1[i,1] == input.sa[j,1] && r.sel1[i,2] == input.sa[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(input.sa[j,5], input.sa[j,6])) {
				sa[i, c(5:12)] <- input.sa[j, c(3:10)]
			}
	    }
	}	
}				

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(input.sb[,1])) {
		if (r.sel1[i,1] == input.sb[j,1] && r.sel1[i,2] == input.sb[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(input.sb[j,5], input.sb[j,6])) {
				sa[i, c(13:20)] <- input.sb[j, c(3:10)]
			}
	    }
	}	
}

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(input.sc[,1])) {
		if (r.sel1[i,1] == input.sc[j,1] && r.sel1[i,2] == input.sc[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(input.sc[j,5], input.sc[j,6])) {
				sa[i, c(21:28)] <- input.sc[j, c(3:10)]
			}
	    }
	}	
}

sa[, 12] <- gsub("1", "-", sa[, 12])
sa[, 12] <- gsub("2", "*", sa[, 12])
sa[, 12] <- gsub("3", "**", sa[, 12])
sa[, 20] <- gsub("1", "-", sa[, 20])
sa[, 20] <- gsub("2", "*", sa[, 20])
sa[, 20] <- gsub("3", "**", sa[, 20])
sa[, 28] <- gsub("1", "-", sa[, 28])
sa[, 28] <- gsub("2", "*", sa[, 28])
sa[, 28] <- gsub("3", "**", sa[, 28])

colnames(sa)[5:28] <- c("Start_SELB","Stop_SELB", "Start_CTRA", "Stop_CTRA", "Freq_SELB", "Freq_CTRA", "Pval", "Pval_BF", 
						"Start_SELB","Stop_SELB", "Start_CTRB", "Stop_CTRB", "Freq_SELB", "Freq_CTRB", "Pval", "Pval_BF", 
						"Start_SELB","Stop_SELB", "Start_CTRC", "Stop_CTRC", "Freq_SELB", "Freq_CTRC", "Pval", "Pval_BF")

write.table(sa, file=paste(parent.o, "Freqs_AK2_2D-3CTRs_f0.10.Pval_BF_reads_temp.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)

# Selection pool C
list.files.sel  <- dir(parent.o, pattern ="Freqs_AK2_3D-AK2_.*C_f0.10.Pval_BF_reads_temp.txt")

input.sa <- read.table(file=paste(parent.o, list.files.sel[1], sep=""), sep="\t", header=T)
input.sb <- read.table(file=paste(parent.o, list.files.sel[2], sep=""), sep="\t", header=T)
input.sc <- read.table(file=paste(parent.o, list.files.sel[3], sep=""), sep="\t", header=T)

sall <- r.sel <- sa <- NULL
sall <- rbind(input.sa, input.sb, input.sc)
sall.u <- sall %>% unite(Chr_TE_ID, c(Chr, TE_ID), sep = "&&", remove = TRUE)
p.ranges <- GRanges(sall.u$Chr_TE_ID, IRanges(sall.u$Start_SEL, sall.u$Stop_SEL))
p.ranges.red <- reduce(p.ranges)
p.new.int <- as.data.frame(p.ranges.red)
r.sel <- cbind(unlist(sapply(strsplit(as.character(p.new.int[,1]),'&&'), "[", 1)), 
				unlist(sapply(strsplit(as.character(p.new.int[,1]),'&&'), "[", 2)), 
				p.new.int[,2], p.new.int[,3])  
r.sel1 <- as.data.frame(r.sel, stringsAsFactors=FALSE) 
r.sel1[,3] <- as.numeric(r.sel1[,3])
r.sel1[,4] <- as.numeric(r.sel1[,4])
colnames(r.sel1) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new")

sa <- cbind(r.sel1, as.data.frame(matrix("NA", nrow=length(p.new.int[,1]), ncol=24), stringsAsFactors=FALSE))  

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(input.sa[,1])) {
		if (r.sel1[i,1] == input.sa[j,1] && r.sel1[i,2] == input.sa[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(input.sa[j,5], input.sa[j,6])) {
				sa[i, c(5:12)] <- input.sa[j, c(3:10)]
			}
	    }
	}	
}				

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(input.sb[,1])) {
		if (r.sel1[i,1] == input.sb[j,1] && r.sel1[i,2] == input.sb[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(input.sb[j,5], input.sb[j,6])) {
				sa[i, c(13:20)] <- input.sb[j, c(3:10)]
			}
	    }
	}	
}

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(input.sc[,1])) {
		if (r.sel1[i,1] == input.sc[j,1] && r.sel1[i,2] == input.sc[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(input.sc[j,5], input.sc[j,6])) {
				sa[i, c(21:28)] <- input.sc[j, c(3:10)]
			}
	    }
	}	
}

sa[, 12] <- gsub("1", "-", sa[, 12])
sa[, 12] <- gsub("2", "*", sa[, 12])
sa[, 12] <- gsub("3", "**", sa[, 12])
sa[, 20] <- gsub("1", "-", sa[, 20])
sa[, 20] <- gsub("2", "*", sa[, 20])
sa[, 20] <- gsub("3", "**", sa[, 20])
sa[, 28] <- gsub("1", "-", sa[, 28])
sa[, 28] <- gsub("2", "*", sa[, 28])
sa[, 28] <- gsub("3", "**", sa[, 28])

colnames(sa)[5:28] <- c("Start_SELC","Stop_SELC", "Start_CTRA", "Stop_CTRA", "Freq_SELC", "Freq_CTRA", "Pval", "Pval_BF", 
						"Start_SELC","Stop_SELC", "Start_CTRB", "Stop_CTRB", "Freq_SELC", "Freq_CTRB", "Pval", "Pval_BF", 
						"Start_SELC","Stop_SELC", "Start_CTRC", "Stop_CTRC", "Freq_SELC", "Freq_CTRC", "Pval", "Pval_BF")

write.table(sa, file=paste(parent.o, "Freqs_AK2_3D-3CTRs_f0.10.Pval_BF_reads_temp.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)

### Classify the TEs of each selection and control pool
# TEs that are significant in three controls and change the frequency in the same direction (increase or decrease)
# TEs that are significant in three controls and change the frequency in the same direction (increase or decrease) and that change the frequency in the same direction in a the third pool but not significantly
# TEs that are significant in one control (increase or decrease) and that change the frequency in the same direction in a the two other pools but not significantly
# All that was different from above

saa <- read.table(file=paste(parent.o, "Freqs_AK2_1D-3CTRs_f0.10.Pval_BF_reads_temp.txt", sep=""), 
					header=T, sep="\t")
sbb <- read.table(file=paste(parent.o, "Freqs_AK2_2D-3CTRs_f0.10.Pval_BF_reads_temp.txt", sep=""), 
					header=T, sep="\t")
scc <- read.table(file=paste(parent.o, "Freqs_AK2_3D-3CTRs_f0.10.Pval_BF_reads_temp.txt", sep=""), 
					header=T, sep="\t")

colnames(saa) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SELD14","Stop_SELD14","Start_CTR14",
					"Stop_CTR14","Freq_SELD14","Freq_CTR14", "Pval14","Pval_BF14","Start_SELD17","Stop_SELD17",
					"Start_CTR17","Stop_CTR17","Freq_SELD17","Freq_CTR17","Pval17","Pval_BF17","Start_SELD18",
					"Stop_SELD18","Start_CTR18","Stop_CTR18","Freq_SELD18","Freq_CTR18","Pval18","Pval_BF18")
colnames(sbb) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SELD14","Stop_SELD14","Start_CTR14",
					"Stop_CTR14","Freq_SELD14","Freq_CTR14", "Pval14","Pval_BF14","Start_SELD17","Stop_SELD17",
					"Start_CTR17","Stop_CTR17","Freq_SELD17","Freq_CTR17","Pval17","Pval_BF17","Start_SELD18",
					"Stop_SELD18","Start_CTR18","Stop_CTR18","Freq_SELD18","Freq_CTR18","Pval18","Pval_BF18")
colnames(scc) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SELD14","Stop_SELD14","Start_CTR14",
					"Stop_CTR14","Freq_SELD14","Freq_CTR14", "Pval14","Pval_BF14","Start_SELD17","Stop_SELD17",
					"Start_CTR17","Stop_CTR17","Freq_SELD17","Freq_CTR17","Pval17","Pval_BF17","Start_SELD18",
					"Stop_SELD18","Start_CTR18","Stop_CTR18","Freq_SELD18","Freq_CTR18","Pval18","Pval_BF18")

# SAA pool
saa.tw.i  <- saa.on.i <- saa.tw.d <- saa.on.d <- saa.all.s <- NULL

# Significant in selection pool and in one, two or three controls and increase in frequency from control to selection pool
saa.tr.i <- saa[grepl("*", saa[,12], fixed = TRUE) & saa[,9] > saa[,10] & grepl("*", saa[,20], fixed = TRUE) & 
				saa[,17] > saa[,18] & grepl("*", saa[,28], fixed = TRUE) & saa[,25] > saa[,26], ]

saa.tw.i.1 <- saa[!grepl("*", saa[,12], fixed = TRUE) & (saa[,9] > saa[,10] | is.na(saa[,9]) | is.na(saa[,10])) & 
				grepl("*", saa[,20], fixed = TRUE) & saa[,17] > saa[,18] & grepl("*", saa[,28], fixed = TRUE) & 
				saa[,25] > saa[,26], ]
saa.tw.i.2 <- saa[grepl("*", saa[,12], fixed = TRUE) & saa[,9] > saa[,10] & !grepl("*", saa[,20], fixed = TRUE) & 
				(saa[,17] > saa[,18] | is.na(saa[,17]) | is.na(saa[,18])) & grepl("*", saa[,28], fixed = TRUE) & 
				saa[,25] > saa[,26], ]
saa.tw.i.3 <- saa[grepl("*", saa[,12], fixed = TRUE) & saa[,9] > saa[,10]  & grepl("*", saa[,20], fixed = TRUE) & 
				saa[,17] > saa[,18] & !grepl("*", saa[,28], fixed = TRUE) & (saa[,25] > saa[,26] | is.na(saa[,25]) | 
				is.na(saa[,26])), ]
saa.tw.i <- rbind(saa.tw.i.1, saa.tw.i.2, saa.tw.i.3)

saa.on.i.1 <- saa[!grepl("*", saa[,12], fixed = TRUE) & (saa[,9] > saa[,10] | is.na(saa[,9]) | is.na(saa[,10])) & 
				!grepl("*", saa[,20], fixed = TRUE) & (saa[,17] > saa[,18] | is.na(saa[,17]) | is.na(saa[,18])) & 
				grepl("*", saa[,28], fixed = TRUE) & saa[,25] > saa[,26], ]
saa.on.i.2 <- saa[!grepl("*", saa[,12], fixed = TRUE) & (saa[,9] > saa[,10] | is.na(saa[,9]) | is.na(saa[,10])) & 
				grepl("*", saa[,20], fixed = TRUE) & saa[,17] > saa[,18] & !grepl("*", saa[,28], fixed = TRUE) & 
				(saa[,25] > saa[,26] | is.na(saa[,25]) | is.na(saa[,26])), ]
saa.on.i.3 <- saa[grepl("*", saa[,12], fixed = TRUE) & saa[,9] > saa[,10] & !grepl("*", saa[,20], fixed = TRUE) & 
				(saa[,17] > saa[,18] | is.na(saa[,17]) | is.na(saa[,18])) & !grepl("*", saa[,28], fixed = TRUE) & 
				(saa[,25] > saa[,26] | is.na(saa[,25]) | is.na(saa[,26])), ]
saa.on.i <- rbind(saa.on.i.1, saa.on.i.2, saa.on.i.3)

# Significant in selection pool and in one, two or three controls and decrease in frequency from control to selection pool
saa.tr.d <- saa[grepl("*", saa[,12], fixed = TRUE) & saa[,9] < saa[,10] & grepl("*", saa[,20], fixed = TRUE) & 
				saa[,17] < saa[,18] & grepl("*", saa[,28], fixed = TRUE) & saa[,25] < saa[,26], ]

saa.tw.d.1 <- saa[!grepl("*", saa[,12], fixed = TRUE) & (saa[,9] < saa[,10] | is.na(saa[,9]) | is.na(saa[,10])) & 
				grepl("*", saa[,20], fixed = TRUE) & saa[,17] < saa[,18] & grepl("*", saa[,28], fixed = TRUE) & 
				saa[,25] < saa[,26], ]
saa.tw.d.2 <- saa[grepl("*", saa[,12], fixed = TRUE) & saa[,9] < saa[,10] & !grepl("*", saa[,20], fixed = TRUE) & 
				(saa[,17] < saa[,18] | is.na(saa[,17]) | is.na(saa[,18])) & grepl("*", saa[,28], fixed = TRUE) & 
				saa[,25] < saa[,26], ]
saa.tw.d.3 <- saa[grepl("*", saa[,12], fixed = TRUE) & saa[,9] < saa[,10] & grepl("*", saa[,20], fixed = TRUE) & 
				saa[,17] < saa[,18] & !grepl("*", saa[,28], fixed = TRUE) & (saa[,25] < saa[,26] | is.na(saa[,25]) | 
				is.na(saa[,26])), ]
saa.tw.d <- rbind(saa.tw.d.1, saa.tw.d.2, saa.tw.d.3)

saa.on.d.1 <- saa[!grepl("*", saa[,12], fixed = TRUE) & (saa[,9] < saa[,10] | is.na(saa[,9]) | is.na(saa[,10])) & 
				!grepl("*", saa[,20], fixed = TRUE) & (saa[,17] < saa[,18] | is.na(saa[,17]) | is.na(saa[,18])) & 
				grepl("*", saa[,28], fixed = TRUE) & saa[,25] < saa[,26], ]
saa.on.d.2 <- saa[!grepl("*", saa[,12], fixed = TRUE) & (saa[,9] < saa[,10] | is.na(saa[,9]) | is.na(saa[,10])) & 
				grepl("*", saa[,20], fixed = TRUE) & saa[,17] < saa[,18] & !grepl("*", saa[,28], fixed = TRUE) & 
				(saa[,25] < saa[,26] | is.na(saa[,25]) | is.na(saa[,26])), ]
saa.on.d.3 <- saa[grepl("*", saa[,12], fixed = TRUE) & saa[,9] < saa[,10] & !grepl("*", saa[,20], fixed = TRUE) & 
				(saa[,17] < saa[,18] | is.na(saa[,17]) | is.na(saa[,18])) & !grepl("*", saa[,28], fixed = TRUE) & 
				(saa[,25] < saa[,26] | is.na(saa[,25]) | is.na(saa[,26])), ]
saa.on.d <- rbind(saa.on.d.1, saa.on.d.2, saa.on.d.3)

# Significant in selection pool and in one, two or three controls and increase/decrease in frequency from control to selection pool
saa.all.s <- rbind(saa.tr.i, saa.tw.i, saa.on.i, saa.tr.d, saa.tw.d, saa.on.d)

# All the rest
saa.o <- anti_join(saa, saa.all.s)

# SBB pool
sbb.tw.i  <- sbb.on.i <- sbb.tw.d <- sbb.on.d <- sbb.all.s <- NULL

# Significant in selection pool and in one, two or three controls and increase in frequency from control to selection pool
sbb.tr.i <- sbb[grepl("*", sbb[,12], fixed = TRUE) & sbb[,9] > sbb[,10] & grepl("*", sbb[,20], fixed = TRUE) & 
				sbb[,17] > sbb[,18] & grepl("*", sbb[,28], fixed = TRUE) & sbb[,25] > sbb[,26], ]

sbb.tw.i.1 <- sbb[!grepl("*", sbb[,12], fixed = TRUE) & (sbb[,9] > sbb[,10] | is.na(sbb[,9]) | is.na(sbb[,10])) & 
				grepl("*", sbb[,20], fixed = TRUE) & sbb[,17] > sbb[,18] & grepl("*", sbb[,28], fixed = TRUE) & 
				sbb[,25] > sbb[,26], ]
sbb.tw.i.2 <- sbb[grepl("*", sbb[,12], fixed = TRUE) & sbb[,9] > sbb[,10] & !grepl("*", sbb[,20], fixed = TRUE) & 
				(sbb[,17] > sbb[,18] | is.na(sbb[,17]) | is.na(sbb[,18])) & grepl("*", sbb[,28], fixed = TRUE) & 
				sbb[,25] > sbb[,26], ]
sbb.tw.i.3 <- sbb[grepl("*", sbb[,12], fixed = TRUE) & sbb[,9] > sbb[,10]  & grepl("*", sbb[,20], fixed = TRUE) & 
				sbb[,17] > sbb[,18] & !grepl("*", sbb[,28], fixed = TRUE) & (sbb[,25] > sbb[,26] | is.na(sbb[,25]) | 
				is.na(sbb[,26])), ]
sbb.tw.i <- rbind(sbb.tw.i.1, sbb.tw.i.2, sbb.tw.i.3)

sbb.on.i.1 <- sbb[!grepl("*", sbb[,12], fixed = TRUE) & (sbb[,9] > sbb[,10] | is.na(sbb[,9]) | is.na(sbb[,10])) & 
				!grepl("*", sbb[,20], fixed = TRUE) & (sbb[,17] > sbb[,18] | is.na(sbb[,17]) | is.na(sbb[,18])) & 
				grepl("*", sbb[,28], fixed = TRUE) & sbb[,25] > sbb[,26], ]
sbb.on.i.2 <- sbb[!grepl("*", sbb[,12], fixed = TRUE) & (sbb[,9] > sbb[,10] | is.na(sbb[,9]) | is.na(sbb[,10])) & 
				grepl("*", sbb[,20], fixed = TRUE) & sbb[,17] > sbb[,18] & !grepl("*", sbb[,28], fixed = TRUE) & 
				(sbb[,25] > sbb[,26] | is.na(sbb[,25]) | is.na(sbb[,26])), ]
sbb.on.i.3 <- sbb[grepl("*", sbb[,12], fixed = TRUE) & sbb[,9] > sbb[,10] & !grepl("*", sbb[,20], fixed = TRUE) & 
				(sbb[,17] > sbb[,18] | is.na(sbb[,17]) | is.na(sbb[,18])) & !grepl("*", sbb[,28], fixed = TRUE) & 
				(sbb[,25] > sbb[,26] | is.na(sbb[,25]) | is.na(sbb[,26])), ]
sbb.on.i <- rbind(sbb.on.i.1, sbb.on.i.2, sbb.on.i.3)

# Significant in selection pool and in one, two or three controls and decrease in frequency from control to selection pool
sbb.tr.d <- sbb[grepl("*", sbb[,12], fixed = TRUE) & sbb[,9] < sbb[,10] & grepl("*", sbb[,20], fixed = TRUE) & 
				sbb[,17] < sbb[,18] & grepl("*", sbb[,28], fixed = TRUE) & sbb[,25] < sbb[,26], ]

sbb.tw.d.1 <- sbb[!grepl("*", sbb[,12], fixed = TRUE) & (sbb[,9] < sbb[,10] | is.na(sbb[,9]) | is.na(sbb[,10])) & 
				grepl("*", sbb[,20], fixed = TRUE) & sbb[,17] < sbb[,18] & grepl("*", sbb[,28], fixed = TRUE) & 
				sbb[,25] < sbb[,26], ]
sbb.tw.d.2 <- sbb[grepl("*", sbb[,12], fixed = TRUE) & sbb[,9] < sbb[,10] & !grepl("*", sbb[,20], fixed = TRUE) & 
				(sbb[,17] < sbb[,18] | is.na(sbb[,17]) | is.na(sbb[,18])) & grepl("*", sbb[,28], fixed = TRUE) & 
				sbb[,25] < sbb[,26], ]
sbb.tw.d.3 <- sbb[grepl("*", sbb[,12], fixed = TRUE) & sbb[,9] < sbb[,10] & grepl("*", sbb[,20], fixed = TRUE) & 
				sbb[,17] < sbb[,18] & !grepl("*", sbb[,28], fixed = TRUE) & (sbb[,25] < sbb[,26] | is.na(sbb[,25]) | 
				is.na(sbb[,26])), ]
sbb.tw.d <- rbind(sbb.tw.d.1, sbb.tw.d.2, sbb.tw.d.3)

sbb.on.d.1 <- sbb[!grepl("*", sbb[,12], fixed = TRUE) & (sbb[,9] < sbb[,10] | is.na(sbb[,9]) | is.na(sbb[,10])) & 
				!grepl("*", sbb[,20], fixed = TRUE) & (sbb[,17] < sbb[,18] | is.na(sbb[,17]) | is.na(sbb[,18])) & 
				grepl("*", sbb[,28], fixed = TRUE) & sbb[,25] < sbb[,26], ]
sbb.on.d.2 <- sbb[!grepl("*", sbb[,12], fixed = TRUE) & (sbb[,9] < sbb[,10] | is.na(sbb[,9]) | is.na(sbb[,10])) & 
				grepl("*", sbb[,20], fixed = TRUE) & sbb[,17] < sbb[,18] & !grepl("*", sbb[,28], fixed = TRUE) & 
				(sbb[,25] < sbb[,26] | is.na(sbb[,25]) | is.na(sbb[,26])), ]
sbb.on.d.3 <- sbb[grepl("*", sbb[,12], fixed = TRUE) & sbb[,9] < sbb[,10] & !grepl("*", sbb[,20], fixed = TRUE) & 
				(sbb[,17] < sbb[,18] | is.na(sbb[,17]) | is.na(sbb[,18])) & !grepl("*", sbb[,28], fixed = TRUE) & 
				(sbb[,25] < sbb[,26] | is.na(sbb[,25]) | is.na(sbb[,26])), ]
sbb.on.d <- rbind(sbb.on.d.1, sbb.on.d.2, sbb.on.d.3)

# Significant in selection pool and in one, two or three controls and increase/decrease in frequency from control to selection pool
sbb.all.s <- rbind(sbb.tr.i, sbb.tw.i, sbb.on.i, sbb.tr.d, sbb.tw.d, sbb.on.d)

# All the rest
sbb.o <- anti_join(sbb, sbb.all.s)

# SCC pool
scc.tw.i  <- scc.on.i <- scc.tw.d <- scc.on.d <- scc.all.s <- NULL

# Significant between selection pool and in one, two or three controls and increase in frequency from control to selection pool
scc.tr.i <- scc[grepl("*", scc[,12], fixed = TRUE) & scc[,9] > scc[,10] & grepl("*", scc[,20], fixed = TRUE) & 
				scc[,17] > scc[,18] & grepl("*", scc[,28], fixed = TRUE) & scc[,25] > scc[,26], ]
scc.tw.i.1 <- scc[!grepl("*", scc[,12], fixed = TRUE) & (scc[,9] > scc[,10] | is.na(scc[,9]) | is.na(scc[,10])) & 
				grepl("*", scc[,20], fixed = TRUE) & scc[,17] > scc[,18] & grepl("*", scc[,28], fixed = TRUE) & 
				scc[,25] > scc[,26], ]
scc.tw.i.2 <- scc[grepl("*", scc[,12], fixed = TRUE) & scc[,9] > scc[,10] & !grepl("*", scc[,20], fixed = TRUE) & 
				(scc[,17] > scc[,18] | is.na(scc[,17]) | is.na(scc[,18])) & grepl("*", scc[,28], fixed = TRUE) & 
				scc[,25] > scc[,26], ]
scc.tw.i.3 <- scc[grepl("*", scc[,12], fixed = TRUE) & scc[,9] > scc[,10]  & grepl("*", scc[,20], fixed = TRUE) & 
				scc[,17] > scc[,18] & !grepl("*", scc[,28], fixed = TRUE) & (scc[,25] > scc[,26] | is.na(scc[,25]) | 
				is.na(scc[,26])), ]
scc.tw.i <- rbind(scc.tw.i.1, scc.tw.i.2, scc.tw.i.3)

scc.on.i.1 <- scc[!grepl("*", scc[,12], fixed = TRUE) & (scc[,9] > scc[,10] | is.na(scc[,9]) | is.na(scc[,10])) & 
				!grepl("*", scc[,20], fixed = TRUE) & (scc[,17] > scc[,18] | is.na(scc[,17]) | is.na(scc[,18])) & 
				grepl("*", scc[,28], fixed = TRUE) & scc[,25] > scc[,26], ]
scc.on.i.2 <- scc[!grepl("*", scc[,12], fixed = TRUE) & (scc[,9] > scc[,10] | is.na(scc[,9]) | is.na(scc[,10])) & 
				grepl("*", scc[,20], fixed = TRUE) & scc[,17] > scc[,18] & !grepl("*", scc[,28], fixed = TRUE) & 
				(scc[,25] > scc[,26] | is.na(scc[,25]) | is.na(scc[,26])), ]
scc.on.i.3 <- scc[grepl("*", scc[,12], fixed = TRUE) & scc[,9] > scc[,10] & !grepl("*", scc[,20], fixed = TRUE) & 
				(scc[,17] > scc[,18] | is.na(scc[,17]) | is.na(scc[,18])) & !grepl("*", scc[,28], fixed = TRUE) & 
				(scc[,25] > scc[,26] | is.na(scc[,25]) | is.na(scc[,26])), ]
scc.on.i <- rbind(scc.on.i.1, scc.on.i.2, scc.on.i.3)

# Significant between selection pool and in one, two or three controls and decrease in frequency from control to selection pool
scc.tr.d <- scc[grepl("*", scc[,12], fixed = TRUE) & scc[,9] < scc[,10] & grepl("*", scc[,20], fixed = TRUE) & 
				scc[,17] < scc[,18] & grepl("*", scc[,28], fixed = TRUE) & scc[,25] < scc[,26], ]

scc.tw.d.1 <- scc[!grepl("*", scc[,12], fixed = TRUE) & (scc[,9] < scc[,10] | is.na(scc[,9]) | is.na(scc[,10])) & 
				grepl("*", scc[,20], fixed = TRUE) & scc[,17] < scc[,18] & grepl("*", scc[,28], fixed = TRUE) & 
				scc[,25] < scc[,26], ]
scc.tw.d.2 <- scc[grepl("*", scc[,12], fixed = TRUE) & scc[,9] < scc[,10] & !grepl("*", scc[,20], fixed = TRUE) & 
				(scc[,17] < scc[,18] | is.na(scc[,17]) | is.na(scc[,18])) & grepl("*", scc[,28], fixed = TRUE) & 
				scc[,25] < scc[,26], ]
scc.tw.d.3 <- scc[grepl("*", scc[,12], fixed = TRUE) & scc[,9] < scc[,10] & grepl("*", scc[,20], fixed = TRUE) & 
				scc[,17] < scc[,18] & !grepl("*", scc[,28], fixed = TRUE) & (scc[,25] < scc[,26] | is.na(scc[,25]) | 
				is.na(scc[,26])), ]
scc.tw.d <- rbind(scc.tw.d.1, scc.tw.d.2, scc.tw.d.3)

scc.on.d.1 <- scc[!grepl("*", scc[,12], fixed = TRUE) & (scc[,9] < scc[,10] | is.na(scc[,9]) | is.na(scc[,10])) & 
				!grepl("*", scc[,20], fixed = TRUE) & (scc[,17] < scc[,18] | is.na(scc[,17]) | is.na(scc[,18])) & 
				grepl("*", scc[,28], fixed = TRUE) & scc[,25] < scc[,26], ]
scc.on.d.2 <- scc[!grepl("*", scc[,12], fixed = TRUE) & (scc[,9] < scc[,10] | is.na(scc[,9]) | is.na(scc[,10])) & 
				grepl("*", scc[,20], fixed = TRUE) & scc[,17] < scc[,18] & !grepl("*", scc[,28], fixed = TRUE) & 
				(scc[,25] < scc[,26] | is.na(scc[,25]) | is.na(scc[,26])), ]
scc.on.d.3 <- scc[grepl("*", scc[,12], fixed = TRUE) & scc[,9] < scc[,10] & !grepl("*", scc[,20], fixed = TRUE) & 
				(scc[,17] < scc[,18] | is.na(scc[,17]) | is.na(scc[,18])) & !grepl("*", scc[,28], fixed = TRUE) & 
				(scc[,25] < scc[,26] | is.na(scc[,25]) | is.na(scc[,26])), ]
scc.on.d <- rbind(scc.on.d.1, scc.on.d.2, scc.on.d.3)

# Significant between selection pool and in one, two or three controls and increase/decrease in frequency from control to selection pool
scc.all.s <- rbind(scc.tr.i,scc.tw.i, scc.on.i, scc.tr.d, scc.tw.d, scc.on.d)

# All the rest
scc.o <- anti_join(scc, scc.all.s)

# Save all the TEs in three, two or one selections pools ans increase, decrease and all the rest.
# SAA
write.table(rbind(saa.tr.i, saa.tw.i, saa.on.i), file=paste(parent.o, "Freqs_AK2_1D_-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)
write.table(rbind(saa.tr.d, saa.tw.d, saa.on.d), file=paste(parent.o, "Freqs_AK2_1D_-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)
write.table(saa.o, file=paste(parent.o, "Freqs_AK2_1D_-3CTRs_f0.10.Pval_BF_reads_others.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)

# SBB
write.table(rbind(sbb.tr.i,sbb.tw.i, sbb.on.i), file=paste(parent.o, "Freqs_AK2_2D_-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)
write.table(rbind(sbb.tr.d,sbb.tw.d, sbb.on.d), file=paste(parent.o, "Freqs_AK2_2D_-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)
write.table(sbb.o, file=paste(parent.o, "Freqs_AK2_2D_-3CTRs_f0.10.Pval_BF_reads_others.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)

# SCC
write.table(rbind(scc.tr.i,scc.tw.i, scc.on.i), file=paste(parent.o, "Freqs_AK2_3D_-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)
write.table(rbind(scc.tr.d,scc.tw.d, scc.on.d), file=paste(parent.o, "Freqs_AK2_3D_-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)
write.table(scc.o, file=paste(parent.o, "Freqs_AK2_3D_-3CTRs_f0.10.Pval_BF_reads_others.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)

# Get the TEs that are shared in three, two and one (unique) selection pools (increase and decrease in frequency)
# Increase in frequency
saa <- sbb <- scc <- NULL
saa <- read.table(file=paste(parent.o, "Freqs_AK2_1D_-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), header=T, sep="\t")
sbb <- read.table(file=paste(parent.o, "Freqs_AK2_2D_-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), header=T, sep="\t")
scc <- read.table(file=paste(parent.o, "Freqs_AK2_3D_-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), header=T, sep="\t")

colnames(saa) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR", "Pval","Pval_BF","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF","Start_SEL","Stop_SELC","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF")
colnames(sbb) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR", "Pval","Pval_BF","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF","Start_SEL","Stop_SELC","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF")  
colnames(scc) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR", "Pval","Pval_BF","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF","Start_SEL","Stop_SELC","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF") 

saa[ , 12] <-  gsub("^\\*$", "1", saa[, 12])
saa[ , 12] <-  gsub("^\\**$", "2", saa[, 12])
saa[ , 12] <-  gsub("-", "30", saa[, 12])
saa[ , 12] <- as.numeric(saa[ , 12])
saa[ , 20] <-  gsub("^\\*$", "1", saa[, 20])
saa[ , 20] <-  gsub("^\\**$", "2", saa[, 20])
saa[ , 20] <-  gsub("-", "30", saa[, 20])
saa[ , 20] <- as.numeric(saa[ , 20])
saa[ , 28] <-  gsub("^\\*$", "1", saa[, 28])
saa[ , 28] <-  gsub("^\\**$", "2", saa[, 28])
saa[ , 28] <-  gsub("-", "30", saa[, 28])
saa[ , 28] <- as.numeric(saa[ , 28])

sbb[ , 12] <-  gsub("^\\*$", "1", sbb[, 12])
sbb[ , 12] <-  gsub("^\\**$", "2", sbb[, 12])
sbb[ , 12] <-  gsub("-", "30", sbb[, 12])
sbb[ , 12] <- as.numeric(sbb[ , 12])
sbb[ , 20] <-  gsub("^\\*$", "1", sbb[, 20])
sbb[ , 20] <-  gsub("^\\**$", "2", sbb[, 20])
sbb[ , 20] <-  gsub("-", "30", sbb[, 20])
sbb[ , 20] <- as.numeric(sbb[ , 20])
sbb[ , 28] <-  gsub("^\\*$", "1", sbb[, 28])
sbb[ , 28] <-  gsub("^\\**$", "2", sbb[, 28])
sbb[ , 28] <-  gsub("-", "30", sbb[, 28])
sbb[ , 28] <- as.numeric(sbb[ , 28])
	
scc[ , 12] <-  gsub("^\\*$", "1", scc[, 12])
scc[ , 12] <-  gsub("^\\**$", "2", scc[, 12])
scc[ , 12] <-  gsub("-", "30", scc[, 12])
scc[ , 12] <- as.numeric(scc[ , 12])
scc[ , 20] <-  gsub("^\\*$", "1", scc[, 20])
scc[ , 20] <-  gsub("^\\**$", "2", scc[, 20])
scc[ , 20] <-  gsub("-", "30", scc[, 20])
scc[ , 20] <- as.numeric(scc[ , 20])
scc[ , 28] <-  gsub("^\\*$", "1", scc[, 28])
scc[ , 28] <-  gsub("^\\**$", "2", scc[, 28])
scc[ , 28] <-  gsub("-", "30", scc[, 28])
scc[ , 28] <- as.numeric(scc[ , 28])
 
sall <- NULL
sall <- rbind(saa, sbb, scc)
sall[,1] <- as.character(sall[,1])
sall[,2] <- as.character(sall[,2])
sall <- sall[, 1:4]

sall.u <- sall %>% unite(Chr_TE_ID, c(Chr, TE_ID), sep = "&&", remove = TRUE)
p.ranges <- GRanges(sall.u$Chr_TE_ID, IRanges(sall.u$Start_SEL_new, sall.u$Stop_SEL_new))
p.ranges.red <- reduce(p.ranges)
p.new.int <- as.data.frame(p.ranges.red)
r.sel <- cbind(unlist(sapply(strsplit(as.character(p.new.int[,1]),'&&'), "[", 1)), 
				unlist(sapply(strsplit(as.character(p.new.int[,1]),'&&'), "[", 2)), p.new.int[,2], p.new.int[,3])  
r.sel1 <- as.data.frame(r.sel, stringsAsFactors=FALSE) 
r.sel1[,3] <- as.numeric(r.sel1[,3])
r.sel1[,4] <- as.numeric(r.sel1[,4])
colnames(r.sel1) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new")

sa <- NULL
sa <- cbind(r.sel1, as.data.frame(matrix("NA", nrow=length(r.sel1[,1]), ncol=78), stringsAsFactors=FALSE))
for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(saa[,1])) {
		if (r.sel1[i,1] == saa[j,1] && r.sel1[i,2] == saa[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(saa[j,3], saa[j,4])) {
				sa[i, c(5:30)] <- (saa[j, c(3:28)])
			}
	    }
	}	
}	

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(sbb[,1])) {
		if (r.sel1[i,1] == sbb[j,1] && r.sel1[i,2] == sbb[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(sbb[j,3], sbb[j,4])) {
				sa[i, c(31:56)] <- (sbb[j, c(3:28)])
			}
	    }
	}	
}

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(scc[,1])) {
		if (r.sel1[i,1] == scc[j,1] && r.sel1[i,2] == scc[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(scc[j,3], scc[j,4])) {
				sa[i, c(57:82)] <- (scc[j, c(3:28)])
			}
	    }
	}	
}			
colnames(sa) <- c("Chr","TE_ID","Start_SEL_all","Stop_SEL_all","Start_SEL1D_new","Stop_SEL1D_new",
				"Start_SEL1D","Stop_SEL1D","Start_CTR4C","Stop_CTR4C","Freq_SEL1D","Freq_CTR4C","Pval","Pval_BF",
				"Start_SEL1D","Stop_SEL1D","Start_CTR7C","Stop_CTR7C","Freq_SEL1D","Freq_CTR7C","Pval","Pval_BF",
				"Start_SEL1D","Stop_SEL1D","Start_CTR8C","Stop_CTR8C","Freq_SEL1D","Freq_CTR8C","Pval","Pval_BF",
				"Start_SEL2D_new","Stop_SEL2D_new","Start_SEL2D","Stop_SEL2D","Start_CTR4C","Stop_CTR4C","Freq_SEL2D",
				"Freq_CTR4C","Pval","Pval_BF","Start_SEL2D","Stop_SEL2D","Start_CTR7C","Stop_CTR7C","Freq_SEL2D",
				"Freq_CTR7C","Pval","Pval_BF","Start_SEL2D","Stop_SEL2D","Start_CTR8C","Stop_CTR8C","Freq_SEL2D",
				"Freq_CTR8C","Pval","Pval_BF","Start_SEL3D_new","Stop_SEL3D_new","Start_SEL3D","Stop_SEL3D",
				"Start_CTR4C","Stop_CTR4C","Freq_SEL3D","Freq_CTR4C","Pval","Pval_BF","Start_SEL3D","Stop_SEL3D",
				"Start_CTR7C","Stop_CTR7C","Freq_SEL3D","Freq_CTR7C","Pval","Pval_BF","Start_SEL3D","Stop_SEL3D",
				"Start_CTR8C","Stop_CTR8C","Freq_SEL3D","Freq_CTR8C","Pval","Pval_BF")

sa[ , 14] <-  gsub("1", "*",  sa[, 14])
sa[ , 14] <-  gsub("2", "**", sa[, 14])
sa[ , 14] <-  gsub("30", "-", sa[, 14])
sa[ , 22] <-  gsub("1", "*", sa[, 22])
sa[ , 22] <-  gsub("2", "**", sa[, 22])
sa[ , 22] <-  gsub("30", "-", sa[, 22])
sa[ , 30] <-  gsub("1", "*", sa[, 30])
sa[ , 30] <-  gsub("2", "**", sa[, 30])
sa[ , 30] <-  gsub("30", "-", sa[, 30])
sa[ , 40] <-  gsub("1", "*", sa[, 40])
sa[ , 40] <-  gsub("2", "**", sa[, 40])
sa[ , 40] <-  gsub("30", "-", sa[, 40])
sa[ , 48] <-  gsub("1", "*", sa[, 48])
sa[ , 48] <-  gsub("2", "**", sa[, 48])
sa[ , 48] <-  gsub("30", "-", sa[, 48])
sa[ , 56] <-  gsub("1", "*", sa[, 56])
sa[ , 56] <-  gsub("2", "**", sa[, 56])
sa[ , 56] <-  gsub("30", "-", sa[, 56])
sa[ , 66] <-  gsub("1", "*", sa[, 66])
sa[ , 66] <-  gsub("2", "**", sa[, 66])
sa[ , 66] <-  gsub("30", "-", sa[, 66])
sa[ , 74] <-  gsub("1", "*", sa[, 74])
sa[ , 74] <-  gsub("2", "**", sa[, 74])
sa[ , 74] <-  gsub("30", "-", sa[, 74])
sa[ , 82] <-  gsub("1", "*", sa[, 82])
sa[ , 82] <-  gsub("2", "**", sa[, 82])
sa[ , 82] <-  gsub("30", "-", sa[, 82])

write.table(sa, file=paste(parent.o, "Freqs_All_SEL-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), 
					quote=F, sep="\t", row.names=F, col.names=T)
sa <- read.table(file=paste(parent.o, "Freqs_All_SEL-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), 
					header=T, sep="\t")

on <- tw <- tr <- NULL
for (i in 1:length(sa[,1])) {

	if (!is.na(as.numeric(sa[i,5])) & !is.na(as.numeric(sa[i,31])) & !is.na(as.numeric(sa[i,57]))) {
		tr <- rbind(tr, sa[i, ])
	}
	if (is.na(as.numeric(sa[i,5])) & !is.na(as.numeric(sa[i,31])) & !is.na(as.numeric(sa[i,57]))) {
		tw <- rbind(tw, sa[i, ])
	}
	if (!is.na(as.numeric(sa[i,5])) & !is.na(as.numeric(sa[i,31])) & is.na(as.numeric(sa[i,57]))) {
		tw <- rbind(tw, sa[i, ])
	}
	if (!is.na(as.numeric(sa[i,5])) & is.na(as.numeric(sa[i,31])) & !is.na(as.numeric(sa[i,57]))) {
		tw <- rbind(tw, sa[i, ])
	}
	if (!is.na(as.numeric(sa[i,5])) & is.na(as.numeric(sa[i,31])) & is.na(as.numeric(sa[i,57]))) {
		on <- rbind(on, sa[i, ])
	}
	if (is.na(as.numeric(sa[i,5])) & !is.na(as.numeric(sa[i,31])) & is.na(as.numeric(sa[i,57]))) {
		on <- rbind(on, sa[i, ])
	}
	if (is.na(as.numeric(sa[i,5])) & is.na(as.numeric(sa[i,31])) & !is.na(as.numeric(sa[i,57]))) {
		on <- rbind(on, sa[i, ])
	}
}	
write.table(tr, file=paste(parent.o, "Freqs_3pools_SEL-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)
write.table(tw, file=paste(parent.o, "Freqs_2pools_SEL-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)
write.table(on, file=paste(parent.o, "Freqs_1pools_SEL-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)

# Decrease in frequency
saa <- sbb <- scc <- NULL
saa <- read.table(file=paste(parent.o, "Freqs_AK2_1D_-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), header=T, sep="\t")
sbb <- read.table(file=paste(parent.o, "Freqs_AK2_2D_-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), header=T, sep="\t")
scc <- read.table(file=paste(parent.o, "Freqs_AK2_3D_-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), header=T, sep="\t")

colnames(saa) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR", "Pval","Pval_BF","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF","Start_SEL","Stop_SELC","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF")
colnames(sbb) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR", "Pval","Pval_BF","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF","Start_SEL","Stop_SELC","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF")  
colnames(scc) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR", "Pval","Pval_BF","Start_SEL","Stop_SEL","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF","Start_SEL","Stop_SELC","Start_CTR","Stop_CTR",
					"Freq_SEL","Freq_CTR","Pval","Pval_BF") 

saa[ , 12] <-  gsub("^\\*$", "1", saa[, 12])
saa[ , 12] <-  gsub("^\\**$", "2", saa[, 12])
saa[ , 12] <-  gsub("-", "30", saa[, 12])
saa[ , 12] <- as.numeric(saa[ , 12])
saa[ , 20] <-  gsub("^\\*$", "1", saa[, 20])
saa[ , 20] <-  gsub("^\\**$", "2", saa[, 20])
saa[ , 20] <-  gsub("-", "30", saa[, 20])
saa[ , 20] <- as.numeric(saa[ , 20])
saa[ , 28] <-  gsub("^\\*$", "1", saa[, 28])
saa[ , 28] <-  gsub("^\\**$", "2", saa[, 28])
saa[ , 28] <-  gsub("-", "30", saa[, 28])
saa[ , 28] <- as.numeric(saa[ , 28])

sbb[ , 12] <-  gsub("^\\*$", "1", sbb[, 12])
sbb[ , 12] <-  gsub("^\\**$", "2", sbb[, 12])
sbb[ , 12] <-  gsub("-", "30", sbb[, 12])
sbb[ , 12] <- as.numeric(sbb[ , 12])
sbb[ , 20] <-  gsub("^\\*$", "1", sbb[, 20])
sbb[ , 20] <-  gsub("^\\**$", "2", sbb[, 20])
sbb[ , 20] <-  gsub("-", "30", sbb[, 20])
sbb[ , 20] <- as.numeric(sbb[ , 20])
sbb[ , 28] <-  gsub("^\\*$", "1", sbb[, 28])
sbb[ , 28] <-  gsub("^\\**$", "2", sbb[, 28])
sbb[ , 28] <-  gsub("-", "30", sbb[, 28])
sbb[ , 28] <- as.numeric(sbb[ , 28])
	
scc[ , 12] <-  gsub("^\\*$", "1", scc[, 12])
scc[ , 12] <-  gsub("^\\**$", "2", scc[, 12])
scc[ , 12] <-  gsub("-", "30", scc[, 12])
scc[ , 12] <- as.numeric(scc[ , 12])
scc[ , 20] <-  gsub("^\\*$", "1", scc[, 20])
scc[ , 20] <-  gsub("^\\**$", "2", scc[, 20])
scc[ , 20] <-  gsub("-", "30", scc[, 20])
scc[ , 20] <- as.numeric(scc[ , 20])
scc[ , 28] <-  gsub("^\\*$", "1", scc[, 28])
scc[ , 28] <-  gsub("^\\**$", "2", scc[, 28])
scc[ , 28] <-  gsub("-", "30", scc[, 28])
scc[ , 28] <- as.numeric(scc[ , 28])
 
sall <- NULL
sall <- rbind(saa, sbb, scc)
sall[,1] <- as.character(sall[,1])
sall[,2] <- as.character(sall[,2])
sall <- sall[, 1:4]

sall.u <- sall %>% unite(Chr_TE_ID, c(Chr, TE_ID), sep = "&&", remove = TRUE)
p.ranges <- GRanges(sall.u$Chr_TE_ID, IRanges(sall.u$Start_SEL_new, sall.u$Stop_SEL_new))
p.ranges.red <- reduce(p.ranges)
p.new.int <- as.data.frame(p.ranges.red)
r.sel <- cbind(unlist(sapply(strsplit(as.character(p.new.int[,1]),'&&'), "[", 1)), 
				unlist(sapply(strsplit(as.character(p.new.int[,1]),'&&'), "[", 2)), p.new.int[,2], p.new.int[,3])  
r.sel1 <- as.data.frame(r.sel, stringsAsFactors=FALSE) 
r.sel1[,3] <- as.numeric(r.sel1[,3])
r.sel1[,4] <- as.numeric(r.sel1[,4])
colnames(r.sel1) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new")

sa <- NULL
sa <- cbind(r.sel1, as.data.frame(matrix("NA", nrow=length(r.sel1[,1]), ncol=78), stringsAsFactors=FALSE))
for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(saa[,1])) {
		if (r.sel1[i,1] == saa[j,1] && r.sel1[i,2] == saa[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(saa[j,3], saa[j,4])) {
				sa[i, c(5:30)] <- (saa[j, c(3:28)])
			}
	    }
	}	
}	

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(sbb[,1])) {
		if (r.sel1[i,1] == sbb[j,1] && r.sel1[i,2] == sbb[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(sbb[j,3], sbb[j,4])) {
				sa[i, c(31:56)] <- (sbb[j, c(3:28)])
			}
	    }
	}	
}

for (i in 1:length(r.sel1[,1])) {
	for (j in 1:length(scc[,1])) {
		if (r.sel1[i,1] == scc[j,1] && r.sel1[i,2] == scc[j,2]) {
			if (c(r.sel1[i,3],r.sel1[i,4]) %overlaps% c(scc[j,3], scc[j,4])) {
				sa[i, c(57:82)] <- (scc[j, c(3:28)])
			}
	    }
	}	
}			
colnames(sa) <- c("Chr","TE_ID","Start_SEL_all","Stop_SEL_all","Start_SEL1D_new","Stop_SEL1D_new","Start_SEL1D",
				"Stop_SEL1D","Start_CTR4C","Stop_CTR4C","Freq_SEL1D","Freq_CTR4C","Pval","Pval_BF",
				"Start_SEL1D","Stop_SEL1D","Start_CTR7C","Stop_CTR7C","Freq_SEL1D","Freq_CTR7C",
				"Pval","Pval_BF","Start_SEL1D","Stop_SEL1D","Start_CTR8C","Stop_CTR8C","Freq_SEL1D",
				"Freq_CTR8C","Pval","Pval_BF","Start_SEL2D_new","Stop_SEL2D_new","Start_SEL2D","Stop_SEL2D",
				"Start_CTR4C","Stop_CTR4C","Freq_SEL2D","Freq_CTR4C","Pval","Pval_BF","Start_SEL2D",
				"Stop_SEL2D","Start_CTR7C","Stop_CTR7C","Freq_SEL2D","Freq_CTR7C","Pval","Pval_BF","Start_SEL2D",
				"Stop_SEL2D","Start_CTR8C","Stop_CTR8C","Freq_SEL2D","Freq_CTR8C","Pval","Pval_BF","Start_SEL3D_new",
				"Stop_SEL3D_new","Start_SEL3D","Stop_SEL3D","Start_CTR4C","Stop_CTR4C","Freq_SEL3D","Freq_CTR4C",
				"Pval","Pval_BF","Start_SEL3D","Stop_SEL3D","Start_CTR7C","Stop_CTR7C","Freq_SEL3D","Freq_CTR7C",
				"Pval","Pval_BF","Start_SEL3D","Stop_SEL3D","Start_CTR8C","Stop_CTR8C","Freq_SEL3D","Freq_CTR8C",
				"Pval","Pval_BF")

sa[ , 14] <-  gsub("1", "*",  sa[, 14])
sa[ , 14] <-  gsub("2", "**", sa[, 14])
sa[ , 14] <-  gsub("30", "-", sa[, 14])
sa[ , 22] <-  gsub("1", "*", sa[, 22])
sa[ , 22] <-  gsub("2", "**", sa[, 22])
sa[ , 22] <-  gsub("30", "-", sa[, 22])
sa[ , 30] <-  gsub("1", "*", sa[, 30])
sa[ , 30] <-  gsub("2", "**", sa[, 30])
sa[ , 30] <-  gsub("30", "-", sa[, 30])
sa[ , 40] <-  gsub("1", "*", sa[, 40])
sa[ , 40] <-  gsub("2", "**", sa[, 40])
sa[ , 40] <-  gsub("30", "-", sa[, 40])
sa[ , 48] <-  gsub("1", "*", sa[, 48])
sa[ , 48] <-  gsub("2", "**", sa[, 48])
sa[ , 48] <-  gsub("30", "-", sa[, 48])
sa[ , 56] <-  gsub("1", "*", sa[, 56])
sa[ , 56] <-  gsub("2", "**", sa[, 56])
sa[ , 56] <-  gsub("30", "-", sa[, 56])
sa[ , 66] <-  gsub("1", "*", sa[, 66])
sa[ , 66] <-  gsub("2", "**", sa[, 66])
sa[ , 66] <-  gsub("30", "-", sa[, 66])
sa[ , 74] <-  gsub("1", "*", sa[, 74])
sa[ , 74] <-  gsub("2", "**", sa[, 74])
sa[ , 74] <-  gsub("30", "-", sa[, 74])
sa[ , 82] <-  gsub("1", "*", sa[, 82])
sa[ , 82] <-  gsub("2", "**", sa[, 82])
sa[ , 82] <-  gsub("30", "-", sa[, 82])

write.table(sa, file=paste(parent.o, "Freqs_All_SEL-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)
sa <- read.table(file=paste(parent.o, "Freqs_All_SEL-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), 
				header=T, sep="\t")

on <- tw <- tr <- NULL
for (i in 1:length(sa[,1])) {

	if (!is.na(as.numeric(sa[i,5])) & !is.na(as.numeric(sa[i,31])) & !is.na(as.numeric(sa[i,57]))) {
		tr <- rbind(tr, sa[i, ])
	}
	if (is.na(as.numeric(sa[i,5])) & !is.na(as.numeric(sa[i,31])) & !is.na(as.numeric(sa[i,57]))) {
		tw <- rbind(tw, sa[i, ])
	}
	if (!is.na(as.numeric(sa[i,5])) & !is.na(as.numeric(sa[i,31])) & is.na(as.numeric(sa[i,57]))) {
		tw <- rbind(tw, sa[i, ])
	}
	if (!is.na(as.numeric(sa[i,5])) & is.na(as.numeric(sa[i,31])) & !is.na(as.numeric(sa[i,57]))) {
		tw <- rbind(tw, sa[i, ])
	}
	if (!is.na(as.numeric(sa[i,5])) & is.na(as.numeric(sa[i,31])) & is.na(as.numeric(sa[i,57]))) {
		on <- rbind(on, sa[i, ])
	}
	if (is.na(as.numeric(sa[i,5])) & !is.na(as.numeric(sa[i,31])) & is.na(as.numeric(sa[i,57]))) {
		on <- rbind(on, sa[i, ])
	}
	if (is.na(as.numeric(sa[i,5])) & is.na(as.numeric(sa[i,31])) & !is.na(as.numeric(sa[i,57]))) {
		on <- rbind(on, sa[i, ])
	}
}	
write.table(tr, file=paste(parent.o, "Freqs_3pools_SEL-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)
write.table(tw, file=paste(parent.o, "Freqs_2pools_SEL-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)
write.table(on, file=paste(parent.o, "Freqs_1pools_SEL-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), 
			quote=F, sep="\t", row.names=F, col.names=T)

### Get the frequencies of other selection pools corresponfing to TEs that are significant in one selection pool										
saa <- read.table(file=paste(parent.o, "Freqs_AK2_1D-3CTRs_f0.10.Pval_BF_reads_temp.txt", sep=""), header=T, sep="\t", stringsAsFactors = FALSE)
sbb <- read.table(file=paste(parent.o, "Freqs_AK2_2D-3CTRs_f0.10.Pval_BF_reads_temp.txt", sep=""), header=T, sep="\t", stringsAsFactors = FALSE)
scc <- read.table(file=paste(parent.o, "Freqs_AK2_3D-3CTRs_f0.10.Pval_BF_reads_temp.txt", sep=""), header=T, sep="\t", stringsAsFactors = FALSE)

oni <- read.table(file=paste(parent.o, "Freqs_1pools_SEL-3CTRs_f0.10.Pval_BF_reads_increase.txt", sep=""), 
					sep="\t", header=T, stringsAsFactors = FALSE)
ond <- read.table(file=paste(parent.o, "Freqs_1pools_SEL-3CTRs_f0.10.Pval_BF_reads_decrease.txt", sep=""), 
					sep="\t", header=T, stringsAsFactors = FALSE)

sa.i <- oni[!is.na(oni[,6]) & is.na(oni[,31]) & is.na(oni[,57]), ]
sb.i <- oni[is.na(oni[,6]) & !is.na(oni[,31]) & is.na(oni[,57]), ]
sc.i <- oni[is.na(oni[,6]) & is.na(oni[,31]) & !is.na(oni[,57]), ]

sa.d <- ond[!is.na(ond[,6]) & is.na(ond[,31]) & is.na(ond[,57]), ]
sb.d <- ond[is.na(ond[,6]) & !is.na(ond[,31]) & is.na(ond[,57]), ]
sc.d <- ond[is.na(ond[,6]) & is.na(ond[,31]) & !is.na(ond[,57]), ]

## 1D pool
# Increase in frequency
same <- pool <- NULL
for (i in 1:length(sbb[,1])) {
	for (j in 1:length(sa.i[,1])) {
		if (sbb[i,1] == sa.i[j,1] && sbb[i,2] == sa.i[j,2]) {
			if (c(sbb[i,3],sbb[i,4]) %overlaps% c(sa.i[j,3], sa.i[j,4])) {
				same <- rbind(same, sbb[i,])
				pool <- c(pool, "2D")
			} 
		}	
	}	
}

colnames(same) <- colnames(scc)

for (i in 1:length(scc[,1])) {
	for (j in 1:length(sa.i[,1])) {
		if (scc[i,1] == sa.i[j,1] && scc[i,2] == sa.i[j,2]) {
			if (c(scc[i,3],scc[i,4]) %overlaps% c(sa.i[j,3], sa.i[j,4])) {
				same <- rbind(same, scc[i,])
				pool <- c(pool, "3D")
			} 
		}	
	}	
}
saa.i <- cbind(same, pool)
colnames(saa.i) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTRA",
					"Stop_CTRA","Freq_SEL","Freq_CTRA","Pval","Pval_BF","Start_SEL.1","Stop_SEL.1",
					"Start_CTRB","Stop_CTRB","Freq_SEL.1","Freq_CTR","Pval.1","Pval_BF.1","Start_SEL.2",
					"Stop_SEL.2","Start_CTRC","Stop_CTRC","Freq_SEL.2","Freq_CTRC","Pval.2","Pval_BF.2", 
					"other_pool_non_sign")

write.table(saa.i, file=paste(parent.o, "One_sign_1D_increase_freqs_in_other_pools_one_sign_1D_f0.10.Pval_BF_reads.txt", sep=""), quote=F, col.names=T, row.names=F, sep="\t")

# Decrease
same.d <- pool <- NULL

for (i in 1:length(sbb[,1])) {
	for (j in 1:length(sa.d[,1])) {
		if (sbb[i,1] == sa.d[j,1] && sbb[i,2] == sa.d[j,2]) {
			if (c(sbb[i,3],sbb[i,4]) %overlaps% c(sa.d[j,3], sa.d[j,4])) {
				same.d <- rbind(same.d, sbb[i,])
				pool <- c(pool, "2D")
			} 
		}	
	}	
}

colnames(same.d) <- colnames(scc)

for (i in 1:length(scc[,1])) {
	for (j in 1:length(sa.d[,1])) {
		if (scc[i,1] == sa.d[j,1] && scc[i,2] == sa.d[j,2]) {
			if (c(scc[i,3],scc[i,4]) %overlaps% c(sa.d[j,3], sa.d[j,4])) {
				same.d <- rbind(same.d, scc[i,])
				pool <- c(pool, "3D")
			} 
		}	
	}	
}
saa.d <- cbind(same.d, pool)

colnames(saa.d) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTRA",
					"Stop_CTRA","Freq_SEL","Freq_CTRA","Pval","Pval_BF","Start_SEL.1","Stop_SEL.1",
					"Start_CTRB","Stop_CTRB","Freq_SEL.1","Freq_CTR","Pval.1","Pval_BF.1","Start_SEL.2",
					"Stop_SEL.2","Start_CTRC","Stop_CTRC","Freq_SEL.2","Freq_CTRC","Pval.2","Pval_BF.2", 
					"other_pool_non_sign")
write.table(saa.d, file=paste(parent.o, "One_sign_1D_decrease_freqs_in_other_pools_one_sign_1D_f0.10.Pval_BF_reads.txt", sep=""), 
			quote=F, col.names=T, row.names=F, sep="\t")

## 2D pool
# Increase
same <- pool <- NULL
for (i in 1:length(saa[,1])) {
	for (j in 1:length(sb.i[,1])) {
		if (saa[i,1] == sb.i[j,1] && saa[i,2] == sb.i[j,2]) {
			if (c(saa[i,3],saa[i,4]) %overlaps% c(sb.i[j,3], sb.i[j,4])) {
				same <- rbind(same, saa[i,])
				pool <- c(pool, "1D")
			} 
		}	
	}	
}

colnames(same) <- colnames(scc)

for (i in 1:length(scc[,1])) {
	for (j in 1:length(sb.i[,1])) {
		if (scc[i,1] == sb.i[j,1] && scc[i,2] == sb.i[j,2]) {
			if (c(scc[i,3], scc[i,4]) %overlaps% c(sb.i[j,3], sb.i[j,4])) {
				same <- rbind(same, scc[i,])
				pool <- c(pool, "3D")
			} 
		}	
	}	
}

sbb.i <- cbind(same, pool)
colnames(sbb.i) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTRA",
					"Stop_CTRA","Freq_SEL","Freq_CTRA","Pval","Pval_BF","Start_SEL.1","Stop_SEL.1",
					"Start_CTRB","Stop_CTRB","Freq_SEL.1","Freq_CTR","Pval.1","Pval_BF.1","Start_SEL.2",
					"Stop_SEL.2","Start_CTRC","Stop_CTRC","Freq_SEL.2","Freq_CTRC","Pval.2","Pval_BF.2", 
					"other_pool_non_sign")

write.table(sbb.i, file=paste(parent.o, "One_sign_2D_increase_freqs_in_other_pools_one_sign_1D_f0.10.Pval_BF_reads.txt", sep=""), 
			quote=F, col.names=T, row.names=F, sep="\t")

# Decrease
same.d <- pool <- NULL

for (i in 1:length(saa[,1])) {
	for (j in 1:length(sb.d[,1])) {
		if (saa[i,1] == sb.d[j,1] && saa[i,2] == sb.d[j,2]) {
			if (c(saa[i,3],saa[i,4]) %overlaps% c(sb.d[j,3], sb.d[j,4])) {
				same.d <- rbind(same.d, saa[i,])
				pool <- c(pool, "1D")
			} 
		}	
	}	
}

colnames(same.d) <- colnames(scc)

for (i in 1:length(scc[,1])) {
	for (j in 1:length(sb.d[,1])) {
		if (scc[i,1] == sb.d[j,1] && scc[i,2] == sb.d[j,2]) {
			if (c(scc[i,3],scc[i,4]) %overlaps% c(sb.d[j,3], sb.d[j,4])) {
				same.d <- rbind(same.d, scc[i,])
				pool <- c(pool, "3D")
			} 
		}	
	}	
}
sbb.d <- cbind(same.d, pool)
colnames(sbb.d) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTRA",
					"Stop_CTRA","Freq_SEL","Freq_CTRA","Pval","Pval_BF","Start_SEL.1","Stop_SEL.1",
					"Start_CTRB","Stop_CTRB","Freq_SEL.1","Freq_CTR","Pval.1","Pval_BF.1","Start_SEL.2",
					"Stop_SEL.2","Start_CTRC","Stop_CTRC","Freq_SEL.2","Freq_CTRC","Pval.2","Pval_BF.2", 
					"other_pool_non_sign")
write.table(sbb.d, file=paste(parent.o, "One_sign_2D_decrease_freqs_in_other_pools_one_sign_1D_f0.10.Pval_BF_reads.txt", sep=""), 
			quote=F, col.names=T, row.names=F, sep="\t")

## 3D pool
# Increase
same <- pool <- NULL
for (i in 1:length(saa[,1])) {
	for (j in 1:length(sc.i[,1])) {
		if (saa[i,1] == sc.i[j,1] && saa[i,2] == sc.i[j,2]) {
			if (c(saa[i,3],saa[i,4]) %overlaps% c(sc.i[j,3], sc.i[j,4])) {
				same <- rbind(same, saa[i,])
				pool <- c(pool, "1D")
			} 
		}	
	}	
}

colnames(same) <- colnames(sbb)

for (i in 1:length(sbb[,1])) {
	for (j in 1:length(sc.i[,1])) {
		if (sbb[i,1] == sc.i[j,1] && sbb[i,2] == sc.i[j,2]) {
			if (c(sbb[i,3],sbb[i,4]) %overlaps% c(sc.i[j,3], sc.i[j,4])) {
				same <- rbind(same, sbb[i,])
				pool <- c(pool, "2D")
			} 
		}	
	}	
}
scc.i <- cbind(same, pool)

colnames(scc.i) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTRA",
					"Stop_CTRA","Freq_SEL","Freq_CTRA","Pval","Pval_BF","Start_SEL.1","Stop_SEL.1",
					"Start_CTRB","Stop_CTRB","Freq_SEL.1","Freq_CTR","Pval.1","Pval_BF.1","Start_SEL.2",
					"Stop_SEL.2","Start_CTRC","Stop_CTRC","Freq_SEL.2","Freq_CTRC","Pval.2","Pval_BF.2", 
					"other_pool_non_sign")

write.table(scc.i, file=paste(parent.o, "One_sign_3D_increase_freqs_in_other_pools_one_sign_1D_f0.10.Pval_BF_reads.txt", sep=""), 
			quote=F, col.names=T, row.names=F, sep="\t")

# Decrease
same.d <- pool <- NULL

for (i in 1:length(saa[,1])) {
	for (j in 1:length(sc.d[,1])) {
		if (saa[i,1] == sc.d[j,1] && saa[i,2] == sc.d[j,2]) {
			if (c(saa[i,3],saa[i,4]) %overlaps% c(sc.d[j,3], sc.d[j,4])) {
				same.d <- rbind(same.d, saa[i,])
				pool <- c(pool, "1D")
			} 
		}	
	}	
}

colnames(same.d) <- colnames(sbb)

for (i in 1:length(sbb[,1])) {
	for (j in 1:length(sc.d[,1])) {
		if (sbb[i,1] == sc.d[j,1] && sbb[i,2] == sc.d[j,2]) {
			if (c(sbb[i,3],sbb[i,4]) %overlaps% c(sc.d[j,3], sc.d[j,4])) {
				same.d <- rbind(same.d, sbb[i,])
				pool <- c(pool, "2D")
			} 
		}	
	}	
}
scc.d <- cbind(same.d, pool)

colnames(scc.d) <- c("Chr","TE_ID","Start_SEL_new","Stop_SEL_new","Start_SEL","Stop_SEL","Start_CTRA",
					"Stop_CTRA","Freq_SEL","Freq_CTRA","Pval","Pval_BF","Start_SEL.1","Stop_SEL.1",
					"Start_CTRB","Stop_CTRB","Freq_SEL.1","Freq_CTR","Pval.1","Pval_BF.1","Start_SEL.2",
					"Stop_SEL.2","Start_CTRC","Stop_CTRC","Freq_SEL.2","Freq_CTRC","Pval.2","Pval_BF.2", 
					"other_pool_non_sign")
write.table(scc.d, file=paste(parent.o, "One_sign_3D_decrease_freqs_in_other_pools_one_sign_1D_f0.10.Pval_BF_reads.txt", sep=""), 
			quote=F, col.names=T, row.names=F, sep="\t")