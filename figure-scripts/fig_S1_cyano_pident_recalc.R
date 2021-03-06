# RRR 8-9-16 ----

# Supplemental Figure 1 demonstrates why a pident conversion is important.
# It takes the example of cyanobacteria, a phylum we know is present in the lake
# and absent from the FreshTrain. It shows that without recalculating the BLAST
# pident some cyanos would be included in the FreshTrain classification.

# In the "quick looks" the phylum these cyano reads would be forced into is shown,
# but it's not actually very interesting or pretty. The entire dataset's pidents
# vs. pident recalcs are also shown, but effect is most obvious with cyano phylum.

# NOTE: some of the files needed for this figure are considered "intermediate" and 
# are deleted by step 16. (so hold off on step 16 clean-up if making this figure)

# ---- Define File Paths ----
file.path.blast.table <- "~/Desktop/2018-05-10_taxass_server_results_for_resubmission/Mendota/TaxAss-Mendota/otus.custom.blast.table.modified" # blast table w/ calculations generated by step 4
file.path.taxa.table <- "~/Desktop/2018-05-10_taxass_server_results_for_resubmission/Mendota/TaxAss-Mendota/otus.98.80.80.taxonomy" # final taxonomy table generated by step 15
file.path.FW_only.taxa.table <- "~/Desktop/2018-05-10_taxass_server_results_for_resubmission/Mendota/TaxAss-Mendota/otus.custom.80.taxonomy" # taxonomy table of classifications using custom database only generated in step 15.5.b          
file.path.seqid.reads <- "~/Desktop/2018-05-10_taxass_server_results_for_resubmission/Mendota/TaxAss-Mendota/total.reads.per.seqID.csv" # table generated by step 14, or by sep call in step 15.5.a

# ---- Define Functions ----

import.blast.table <- function(FilePath){
  blast <- read.table(file = FilePath, colClasses = "character")
  colnames(blast) <- c("qseqid","pident","length","qlen","q.align","true.pids","hit.num")
  blast[ ,-1] <- apply(blast[ ,-1], 2, as.numeric)
  return(blast)
}

import.taxa.table <- function(FilePath, Delimitor = ","){
  taxa <- read.table(file = FilePath, header = T, colClasses = "character", sep = Delimitor)
  remove.parentheses <- function(x){
    fixed.name <- sub(pattern = '\\(.*\\)' , replacement = '', x = x)
    return(fixed.name)
  }
  taxa <- apply(taxa, 2, remove.parentheses)
  return(taxa)
}

import.seqID.reads <- function(FilePath){
  seqID.reads <- read.csv(file = FilePath, colClasses = "character")
  seqID.reads[ ,2] <- as.numeric(seqID.reads[ ,2])
  return(seqID.reads)
}

pull.out.taxon <- function(Blast, Taxonomy, TaxaName, TaxaLevel){
  # for the level, this is the column in the taxonomy table: 2=k, 3=p, 4=c, 5=o, 6=l/f, 7=c/g, 8=t/s
  tax.index <- which(Taxonomy[ ,TaxaLevel] == TaxaName)
  seq.ids <- Taxonomy[tax.index,1]
  seq.ids <- data.frame(qseqid = seq.ids, stringsAsFactors = F)
  blast.subset <- merge(x = seq.ids, y = Blast)
  cat("There were ", nrow(seq.ids), " ", TaxaName, " in the final taxonomy file.\n", 
      nrow(blast.subset), " or ", nrow(blast.subset) / nrow(seq.ids) * 100, "% had a blast result reported.\n")
  return(blast.subset)
}

density.overlay <- function(BlastData, WorkflowData, MinX = min(c(density(WorkflowData)$x, density(BlastData)$x)), PlotTitle){
  black <- density(BlastData)
  red <- density(WorkflowData)
  max.x <- max(black$x, red$x)
  max.y <- max(black$y, red$y)
  plot(c(black, red), type = "n", xlim = c(MinX, max.x), ylim = c(0, max.y), main = PlotTitle, xlab = "Percent Identity", ylab = "Density")
  lines(black, col = "black")            
  lines(red, col = "red")
  mtext(text = c("BLAST pident","Workflow-Conversion"), side = 3, line = c(-3,-4), at = MinX, col = c("black", "red"), adj = 0)
}

histogram.overlay <- function(BlastData, WorkflowData, NumBreaks, MinX = "min", PlotTitle){
  if (MinX == "min"){
    MinX <- min(BlastData, WorkflowData)
  }
  hist.info <- hist(c(BlastData, WorkflowData), plot = F, breaks = NumBreaks)
  hist.info.b <- hist(BlastData, plot = F, breaks = hist.info$breaks)
  hist.info.w <- hist(WorkflowData, plot = F, breaks = hist.info$breaks)
  max.y <- max(hist.info.b$counts, hist.info.w$counts)
  col.blast <- c("black", adjustcolor("black", alpha.f = .2))
  col.wkflow <- c("red", adjustcolor("red", alpha.f = .2))
  
  hist(BlastData, breaks = hist.info$breaks, ylim = c(0, max.y), xlim = c(MinX, 100), border = col.blast[1], col = col.blast[2], main = PlotTitle, xlab = "Percent Identity")
  par(new = TRUE)
  hist(WorkflowData, breaks = hist.info$breaks, ylim = c(0, max.y), xlim = c(MinX, 100), border = col.wkflow[1], col = col.wkflow[2], ann = FALSE, axes = FALSE)
  mtext(text = c("BLAST pident","Workflow-Conversion"), side = 3, line = c(-3,-4), at = MinX, col = c("black", "red"), adj = 0)
}

find.seqIDs.conversion.removed <- function(BlastData, Cutoff, FWTax){
  index.blast <- which(BlastData$pident >= Cutoff & BlastData$true.pids < Cutoff)
  seq.ids <- BlastData[index.blast, 1]
  return(seq.ids)
}

find.taxonomies <- function(SeqIDs, Tax){
  seqids <- data.frame(seqID.fw = SeqIDs, stringsAsFactors = F)
  tax <- as.data.frame(Tax, stringsAsFactors = F)
  seqids.tax <- merge(x = seqids, y = tax)
  return(seqids.tax)
}

count.up.tax.names.by.otu <- function(ForcedTax, TaxLevel, TotReads){
  tax.names <- unique(ForcedTax[ ,TaxLevel])
  tax.nums <- NULL
  for (n in 1:length(tax.names)){
    index <- which(ForcedTax[ ,TaxLevel] == tax.names[n])
    tax.nums[n] <- length(index)
  }
  names(tax.nums) <- tax.names
  tot.otus <- nrow(TotReads)
  tax.nums.norm <- tax.nums / tot.otus * 100
  return(tax.nums.norm)
}

count.up.tax.names.by.read <- function(ForcedTax, TaxLevel, TotReads){
  tax.tots <- merge(x = ForcedTax, y = TotReads, by.x = "seqID.fw", by.y = "seqID")
  tax.level <- tax.tots[ ,c(TaxLevel,9)]
  level.tots <- aggregate(x = tax.level[ ,2], by = list(tax.level[ ,1]), FUN = sum)
  colnames(level.tots) <- c("Forced.Into", "Perc.Dataset.Reads")
  return(level.tots)
}

single.stacked.bar <- function(FWCdata, DataType, Direction){
  # FWC = Forced Without blast Conversion
  FWCdata <- sort(FWCdata, decreasing = TRUE)
  fwc.matrix <- as.matrix(FWCdata) # needs to be a matrix to be plotted as stacked bar
  x.label <- paste("The Phylum they would have been forced", Direction)
  y.label <- paste("Percent total", DataType)
  plot.title <- paste(DataType, "removed from freshwater classification\nby percent identity conversion")
  phyla.colors <- rainbow(n = 4, alpha = .5, v = .8)
  phyla.colors <- c(phyla.colors, rep(phyla.colors[4], times = 3))
  y.intersects <- c(0, cumsum(fwc.matrix))
  y.labels <- round(y.intersects, digits = 1)
  y.labels <- as.character(y.labels)
  y.labels <- y.labels[-c(4:6)]
  legend.locs <- y.intersects[-8] + .1
  legend.locs[4:7] <- c(1.8, 1.9, 2, 2.1)
  
  par(mar = c(2,4,5,10))
  barplot(fwc.matrix, las = 2, beside = FALSE, col = phyla.colors, axes = FALSE)
  axis(side = 2, at = y.intersects[-c(4:6)], las = 2, labels = y.labels)
  mtext(text = y.label, side = 2, line = 2.5)
  mtext(text = plot.title, side = 3, at = .5, line = 2.5, cex = 1.2)
  mtext(text = x.label, side = 1, at = 1.2, line = .5)
  mtext(text = rownames(fwc.matrix), side = 4, at = legend.locs, line = 0, las = 2, col = phyla.colors)
}

# ---- Import Data ----

blast <- import.blast.table(FilePath = file.path.blast.table)
taxa <- import.taxa.table(FilePath = file.path.taxa.table)
fw.taxa <- import.taxa.table(FilePath = file.path.FW_only.taxa.table, Delimitor = ";")
seqid.reads <- import.seqID.reads(FilePath = file.path.seqid.reads)

# ---- Quick Looks (can skip to paper figure section w/out sourcing) ----

# before & after pidents for all OTUs
density.overlay(BlastData = blast$pident, WorkflowData = blast$true.pids, PlotTitle = "All OTUs")
density.overlay(BlastData = blast$pident, WorkflowData = blast$true.pids, MinX = 90, PlotTitle = "All OTUs")
histogram.overlay(BlastData = blast$pident, WorkflowData = blast$true.pids, PlotTitle = "All OTUs", NumBreaks = 100, MinX = "min")
histogram.overlay(BlastData = blast$pident, WorkflowData = blast$true.pids, PlotTitle = "All OTUs", NumBreaks = 100, MinX = 90)

# which taxa excluded by pident recalc? (not very useful)
removed.seqids <- find.seqIDs.conversion.removed(BlastData = blast, Cutoff = 98)
forced.into.taxonomy <- find.taxonomies( SeqIDs = removed.seqids, Tax = fw.taxa)
forced.into.phyla.perc.otus <- count.up.tax.names.by.otu(ForcedTax = forced.into.taxonomy, TaxLevel = 3, TotReads = seqid.reads)
forced.into.phyla.perc.reads <- count.up.tax.names.by.read(ForcedTax = forced.into.taxonomy, TaxLevel = 3, TotReads = seqid.reads)
forced.from.taxonomy <- find.taxonomies(SeqIDs = removed.seqids, Tax = taxa)
forced.from.phyla.perc.otus <- count.up.tax.names.by.otu(ForcedTax = forced.from.taxonomy, TaxLevel = 3, TotReads = seqid.reads)
forced.from.phyla.perc.reads <- count.up.tax.names.by.read(ForcedTax = forced.from.taxonomy, TaxLevel = 3, TotReads = seqid.reads)

single.stacked.bar(FWCdata = forced.into.phyla.perc.otus, DataType = "OTUs", Direction = "into")
single.stacked.bar(FWCdata = forced.into.phyla.perc.reads, DataType = "Reads", Direction = "into")
single.stacked.bar(FWCdata = forced.from.phyla.perc.reads, DataType = "Reads", Direction = "from")

par(mar = c(10,5,4,2))
barplot(forced.into.phyla.perc.otus, las = 2, ylab = "percent all OTUs", main = "OTUs that would be forced\nwithout the BLAST conversion", xlab = "")
title(xlab = "The Phylum they would be forced into", line = 8.5)
barplot(forced.into.phyla.perc.reads, las = 2, ylab = "percent all reads", main = "Reads that would be forced\nwithout the BLAST conversion", xlab = "", beside = FALSE)
title(xlab = "The Phylum they would be forced into", line = 8.5)

true.taxonomy <- count.up.tax.names.by.read(ForcedTax = taxa, TaxLevel = 3, TotReads = seqid.reads)
barplot(true.taxonomy[1:5], las = 2, ylab = "percent all reads", main = "breakdown of final taxonomy")
fw.taxonomy <- count.up.tax.names.by.read(ForcedTax = fw.taxa, TaxLevel = 3, TotReads = seqid.reads)
barplot(fw.taxonomy[1:5], las = 2, ylab = "percent all reads", main = "breakdown of all-FW taxonomy")

# look only at phylum cyanobacteria OTUs (==> supp figure 1)
cyano.blast <- pull.out.taxon(Blast = blast, Taxonomy = taxa, TaxaName = "Cyanobacteria", TaxaLevel = 3) # need p__Cyanobacteria for Greengenes
density.overlay(BlastData = cyano.blast$pident, WorkflowData = cyano.blast$true.pids, PlotTitle = "Cyanobacteria")
histogram.overlay(BlastData = cyano.blast$pident, WorkflowData = cyano.blast$true.pids, NumBreaks = 100, PlotTitle = "Cyanobacteria")
histogram.overlay(BlastData = cyano.blast$pident, WorkflowData = cyano.blast$true.pids, NumBreaks = 100, PlotTitle = "Cyanobacteria", MinX = 97)
mtext(text = "no cyanos matching at cutoff after correction, some did before pident recalc", side = 1, line = 5)
histogram.overlay(BlastData = cyano.blast$pident, WorkflowData = cyano.blast$true.pids, NumBreaks = 100, PlotTitle = "Cyanobacteria", MinX = 90)
mtext(text = "no cyanos matching at cutoff after correction, some did before pident recalc", side = 1, line = 5)

# which cyanos have these BLAST hits above the TaxAss cutoff?
index.high.cyanos <- which(cyano.blast$pident >= 98)
cyano.blast.ex <- cyano.blast[index.high.cyanos, ]
nrow(cyano.blast.ex) # only 22 sequences in greengenes, but 693 with silva run- oh diff is unique seqs used?
summary(cyano.blast.ex[ ,-1]) # most very short, all 1st hit

# what would those cyanos be forced into? (the ones with high BLAST hits)
cyano.forced <- find.taxonomies(SeqIDs = cyano.blast$qseqid, Tax = fw.taxa)
cyano.phyla <- count.up.tax.names.by.read(ForcedTax = cyano.forced, TotReads = seqid.reads, TaxLevel = 3)
barplot(cyano.phyla$Perc.Dataset.Reads, names.arg = cyano.phyla$Forced.Into, beside = FALSE, las =2, cex.names = .5) # mostly just unclassified

# what is the overall impact of forcing on cyanos? (including ones excluded from BLAST results)
index <- order(taxa[ ,1])
taxa <- taxa[index, ]
index <- order(seqid.reads[ ,1])
seqid.reads <- seqid.reads[index, ]
index <- order(fw.taxa[ ,1])
fw.taxa <- fw.taxa[index, ]
all.equal(taxa[ ,1], seqid.reads[ ,1], fw.taxa[ ,1])
index.cyanos <- which(taxa[ ,3] == "Cyanobacteria")
cyanos.all.taxa <- taxa[index.cyanos, ]
cyanos.all.reads <- seqid.reads[index.cyanos, ]
cyanos.all.fw <- fw.taxa[index.cyanos, ]
all.equal(cyanos.all.taxa[ ,1], cyanos.all.reads[ ,1], cyanos.all.fw[ ,1])
unique(cyanos.all.taxa[ ,3])
unique(cyanos.all.fw[ ,3])
cyanos.all.forced.into <- data.frame(cyanos.all.fw, cyanos.all.reads[ ,2], stringsAsFactors = F)
cyanos.all.forced.into <- aggregate(x = cyanos.all.forced.into[ ,9], by = list(cyanos.all.forced.into[ ,3]), FUN = sum)
barplot(cyanos.all.forced.into$x, names.arg = cyanos.all.forced.into$Group.1)
perc.cyano.classifications <- cyanos.all.forced.into$x / sum(cyanos.all.forced.into$x) * 100
names(perc.cyano.classifications) <- cyanos.all.forced.into$Group.1
perc.cyano.classifications

# look only at phylum actionbacteria OTUs (only some changed by pident recalc, most full-length matches already)
actino.blast <- pull.out.taxon(Blast = blast, Taxonomy = taxa, TaxaName = "Actinobacteria", TaxaLevel = 3)
density.overlay(BlastData = actino.blast$pident, WorkflowData = actino.blast$true.pids, PlotTitle = "Actinobacteria")
histogram.overlay(BlastData = actino.blast$pident, WorkflowData = actino.blast$true.pids, NumBreaks = 100, PlotTitle = "Actinobacteria")
density.overlay(BlastData = actino.blast$pident, WorkflowData = actino.blast$true.pids, PlotTitle = "Actinobacteria", MinX = 90)
histogram.overlay(BlastData = actino.blast$pident, WorkflowData = actino.blast$true.pids, NumBreaks = 100, PlotTitle = "Actinobacteria", MinX = 97)


# ---- Supplemental Figure 1 ----

# save.to <- "~/Dropbox/PhD/Write It/draft 7/re-submission_figures/Supplemental_cyano-recalc.pdf"

cyano.blast <- pull.out.taxon(Blast = blast, Taxonomy = taxa, TaxaName = "Cyanobacteria", TaxaLevel = 3) 
blast.pid <- cyano.blast$pident
recalc.pid <- cyano.blast$true.pids

plot.title <- "Cyanobacteria Percent Identity Recalculations"
x.label <- "Percent Identity"
y.label <- "Frequency"
legend.labels <- c("TaxAss recalculated percent identity", "BLAST percent identity (pident)")

col.blast <- "red"
col.recalc <- "black"
col.blast.shade <- adjustcolor(col.blast, alpha.f = .2)
col.recalc.shade <- adjustcolor(col.recalc, alpha.f = .2)

num.breaks <- 100
hist.info <- hist(c(blast.pid, recalc.pid), plot = F, breaks = num.breaks)
hist.info.b <- hist(blast.pid, plot = F, breaks = hist.info$breaks)
hist.info.r <- hist(recalc.pid, plot = F, breaks = hist.info$breaks)

max.y <- max(hist.info.b$counts, hist.info.r$counts) 
min.x <- min(blast.pid, recalc.pid)

# start plotting
pdf(file = save.to, width = 6.875, height = 3, family = "Helvetica", title = "TaxAss Fig 2", colormodel = "srgb")
par(mai = c(.4, .55, .3, 0), omi = c(0, 0, 0, 0)) # bottom, left, top, right
# add data 
hist(blast.pid, breaks = hist.info$breaks, freq = TRUE, ylim = c(0, max.y), xlim = c(min.x, 100), xpd = NA, border = col.blast, col = col.blast.shade, ann = FALSE, axes = FALSE)
par(new = TRUE)
hist(recalc.pid, breaks = hist.info$breaks, freq = TRUE, ylim = c(0, max.y), xlim = c(min.x, 100), border = col.recalc, col = col.recalc.shade, ann = FALSE, axes = FALSE)
# add axes
x.ticks <- axis(side = 1, labels = FALSE, line = -.25, tck = -.025, lwd = 0, lwd.ticks = 1)
mtext(text = x.ticks, side = 1, line = 0, at = x.ticks)
axis(side = 1, at = c(min.x, 100), labels = FALSE, line = -.25, tck = 0) # make line extend full range
y.ticks <- c(0,1000,2000,3000) # manually make fewer total ticks
axis(side = 2, at = y.ticks, labels = FALSE, line = -1, tck = -.025, lwd = 0, lwd.ticks = 1)
mtext(text = y.ticks, side = 2, line = -.5, at = y.ticks, las = 1)
axis(side = 2, at = c(0,max.y), labels = FALSE, line = -1, tck = 0)
# add titles
mtext(text = plot.title, side = 3, line = .5, cex = 1.2, at = 60)
mtext(text = x.label, side = 1, line = 1, cex = 1)
mtext(text = y.label, side = 2, line = 1.8, cex = 1)
# add legend
text(x = 48, y = c(2800,3100), labels = legend.labels, adj = 0, xpd = NA, cex = .9)
rect(xleft = 46, xright = 47, ybottom = 3050, ytop = 3200, col = col.blast.shade, border = col.blast, xpd = NA)
rect(xleft = 46, xright = 47, ybottom = 2750, ytop = 2900, col = col.recalc.shade, border = col.recalc, xpd = NA)

# box(which = "plot", col=adjustcolor("purple", alpha.f = .5), lwd = 3)
# box(which = "figure", col=adjustcolor("orange", alpha.f = .5), lwd = 3)

dev.off()




