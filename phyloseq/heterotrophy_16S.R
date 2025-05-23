## Heterotrophy bacteria community analysis ##

# Preparing the data
# Using the data file "hetero_data.txt" and one of the taxonomy files, we will go through phyloseq to look at the data and make figures. First, make sure you are in the right folder by running:

# read OTU data, calling this 'dat' 
# use the 'stringsAsFactors' argument to read OTU names as character
dat <- read.delim('hetero_data.txt', stringsAsFactors=F)

dat$timepoint <- factor(dat$timepoint, levels=c('T0','T1','T2', 'none'))
dat$treatment <- factor(dat$treatment, levels=c('Control', 'Rotifers', 'BMC', 'BMC_rotifers', 'none'))
str(dat[, 1:5])

# read in the taxonomy, use 'stringsAsFactors=F' to keep text as 'character'
tax <- read.delim('hetero_taxonomy_SILVA_cleaned.txt', stringsAsFactors=F)

## Creating phyloseq object
# We need to specify the different components to create a phyloseq (https://github.com/joey711/phyloseq) object.

# load phyloseq, dplyr(to manipulate data)
library(phyloseq)
library(dplyr)

# extract the OTU data from 'dat' and convert to matrix format
# using 'starts_with' with 'select' allows us to chose all columns containing OTU counts
otus <- as.matrix(select(dat, starts_with('Zotu')))

# rows need to be named with the sample names from 'dat', which we can do directly because they are in the same order
rownames(otus) <- dat$XOTUID

# extract the sample data from from 'dat' and keep as dataframe format (mix of character and numeric variables)
samps <- select(dat, XOTUID:treatment)

# rows need to be named with the sample names from 'dat', which we can do directly because they are in the same order
rownames(samps) <- dat$XOTUID

# extract the taxonomy info for each OTU from 'tax' and convert to matrix format
taxonomy <- as.matrix(select(tax, kingdom:species))

# rows need to be named with the OTU names from 'tax', which we can do directly because they are in the same order
rownames(taxonomy) <- tax$XOTUID

# merge the three objects into a single phyloseq object using 'merge_phyloseq'
# each function nexted within the call to 'merge_phyloseq' creates a special object for that type of data
# because of how the OTU matrix is oriented, we have to specify 'taxa_are_rows=F' 
phy <- merge_phyloseq(otu_table(otus, taxa_are_rows=F), 
                sample_data(samps),
                tax_table(taxonomy))

# remove extra objects to keep workspace tidy
rm(otus, samps, taxonomy)

# remove the Blank sample
phy <- prune_samples(sample_names(phy) != "Blank_S142", phy)

# remove archaea/eukarya
phy <- subset_taxa(phy, kingdom=="Bacteria")

# remove OTUs with abundance zero
phy <- prune_samples(sample_sums(phy)>0, phy)

# remove OTUs that hit to Chloroplast or Mitochondria (because they are showing eukarya)
phy <- subset_taxa(phy, order != "o_Chloroplast")
phy <- subset_taxa(phy, family != "f_Mitochondria")

## Analyzing the data
# Now that we have the phyloseq object, we can look at the different aspects of the data and make figures.

# first load the ggplot2 library
library(ggplot2)

#------------------------------------------------------------------------------------------------

# we can look at the alpha diversity in each of the samples
# t2 is a subset created later in the script, can use without t2 for all samples
rich<-estimate_richness(phy)

# we can plot at the alpha diversity in each of the samples
l<-plot_richness(phy, x="treatment", measures=c("Shannon"), color="treatment") +
  geom_boxplot(fill=NA) +
  facet_wrap(~timepoint) +
  theme_bw() +
  theme(axis.text.x=element_text(angle=45,hjust=1,vjust=1)) +
  scale_y_continuous(name="Shannon diversity", limits=c(0,5.5), breaks = seq(0,6,1))
print(l)

# run statistical test to determine the significant difference between groups
hist(rich$Shannon)
shapiro.test(rich$Shannon)

#two-way ANOVA
res.aov <- aov(rich$Shannon ~ sample_data(phy)$timepoint + sample_data(phy)$treatment)
summary(res.aov)
TukeyHSD(res.aov)

#one-way
res.aov.2 <- aov(rich.t2$Shannon ~ sample_data(phy.t2)$treatment)
summary(res.aov.2)
TukeyHSD(res.aov.2)

#------------------------------------------------------------------------------------------------

## Next, we can make a barplot with the data
# create a dummy variable with both the categories to make a relative abundance plot
sample_data(phy)$dummy <- paste0(sample_data(phy)$timepoint, sample_data(phy)$treatment)
phym = merge_samples(phy, "dummy")

# repair the variables that you just destroyed
sample_data(phym)$timepoint <- levels(sample_data(phy)$timepoint)[get_variable(phym, "timepoint")]
sample_data(phym)$treatment <- levels(sample_data(phy)$treatment)[get_variable(phym, "treatment")]

# to do relative abundance (out of 100%), we need to also transform the counts to percents
phy.prop <- transform_sample_counts(phym, function(otu) 100 * otu/sum(otu))

# make the variables ordered factors so that they are in the correct order when plotting
sample_data(phy.prop)$treatment <- factor(sample_data(phy.prop)$treatment, levels = c("Control", "Rotifers", "BMC", "BMC_rotifers"))

# convert phyloseq object to dataframe to make figures in ggplot2
phy.propdf<-psmelt(phy.prop)

#keep the same levels on the x axis
phy.propdf$family <- factor(phy.propdf$family,levels=rev(unique(phy.propdf$family)))

#you can define the colors
#colours <- c("#808080", "#0075DC","#993F00","#4C005C","#2BCE48","#FFCC99","#F0A3FF","#94FFB5","#8F7C00","#9DCC00","#C20088","#003380","#FFA405","#FFA8BB","#426600","#FF0010","#5EF1F2","#00998F","#740AFF","#990000","#FF8000")

# plot
m <- ggplot(phy.propdf, aes(x=treatment, fill = family, y=Abundance)) +
  facet_wrap(~timepoint) +
  geom_bar(aes(color=family), stat = 'identity', position = 'stack', colour = NA) +
  #scale_fill_manual(values = colours) +
  scale_y_continuous(expand = c(0,0), limits=c(0,100)) + theme(strip.background = element_rect(fill="black")) +
  theme_bw() +
  theme(axis.text.x=element_text(angle=45,hjust=1,vjust=1))
print(m)

## We can also make a barplot with just the top taxa at each level. Below shows the top ten order. The numbers can be changed.

# agglomerate at order level
phyg <- tax_glom(phy.prop, "order", NArm = FALSE)

# get just the top 10 order in the samples
top10otus = names(sort(taxa_sums(phyg), TRUE)[1:10])
taxtab10 = cbind(tax_table(phyg), phy10 = NA)
taxtab10[top10otus, "phy10"] <- as(tax_table(phyg)[top10otus, "order"], 
    "character")
tax_table(phyg) <- tax_table(taxtab10)

# alternatively get all the order that had abundances >1% in the samples
#x = taxa_sums(phyg) 
#keeptaxa = taxa_names(phyg)[which((x / sum(x)) > 0.01)]
#phyg1 = prune_taxa(keeptaxa, phyg)

# prune samples
phyg10 = prune_taxa(top10otus, phyg)

# make the variables ordered factors so that they are in the correct order when plotting
sample_data(phyg10)$treatment <- factor(sample_data(phyg10)$treatment, levels = c("Control", "Rotifers", "BMC", "BMC_rotifers"))

# convert phyloseq object to dataframe to make figures in ggplot2
phyg10df<-psmelt(phyg10)

#keep the same levels on the x axis
phyg10df$phy10 <- factor(phyg10df$phy10,levels=rev(unique(phyg10df$phy10)))

#you can define the colors
colours <- c("#FFA8BB","#426600","#FF0010","#5EF1F2","#00998F","#740AFF","#990000","#FF8000", "#993F00","#4C005C","#2BCE48")
# "#808080", "#0075DC","#FFCC99","#F0A3FF","#94FFB5","#8F7C00","#9DCC00","#C20088","#003380","#FFA405",

# plot
n <- ggplot(phyg10df, aes(x=treatment, fill = phy10, y=Abundance)) +
  facet_wrap(~timepoint) +
  geom_bar(aes(color=phy10), stat = 'identity', position = 'stack', colour = NA) +
  scale_fill_manual(values = colours) +
  scale_y_continuous(expand = c(0,0), limits=c(0,100)) + theme(strip.background = element_rect(fill="black")) +
  theme_bw() +
  theme(axis.text.x=element_text(angle=45,hjust=1,vjust=1))
print(n)

#------------------------------------------------------------------------------------------------

## Now we want to check the beta diversity by making a nMDS or PCoA (Eslam did PCoA), and run some tests.

# we can just use a subset of the samples so that we don't clog the plot
phy.t2 = subset_samples(phy, timepoint == "T2")

# this is to normalize the abundances of the samples (here used as a percent)
phy.t2.norm = transform_sample_counts(phy.t2, function(x) 100 * x/sum(x))

# calculate the distance matrix
phy.dist.t2 = phyloseq::distance(phy.t2.norm, method="bray")

# calculate the ordination (using NMDS, PCoA, PCA) using distance (bray, euclidean)
ord <- ordinate(phy.t2.norm, method="PCoA", distance=phy.dist.t2)

# see the eigen value of the axes
plot_scree(ord)

# plot
p <- plot_ordination(phy.t2.norm, ord, color = "treatment", shape = "timepoint")+
  geom_point(size=2, alpha=0.8)+
  scale_shape_manual(values=c(16, 17,18))+
  theme_bw()+
  scale_color_manual(values = c('#d7191c','#fdae61','#abdda4','#2b83ba'))+
  stat_ellipse()
plot(p)

# calculate the beta diversity
library(vegan)
adonis(phy.dist.t2 ~ sample_data(phy.t2.norm)$treatment, permutations = 9999)

# use simper to find the taxa that are driving the differences between samples
simp <- simper(otu_table(phy.t2.norm), sample_data(phy.t2.norm)$treatment, permutations = 999)
summary(simp, ordered = TRUE)


