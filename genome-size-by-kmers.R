rm(list=ls())

histfile <- "scratch/count_51mers.histo"
df <- read.table(histfile)

k <- regmatches(histfile, regexpr("[0-9]+", histfile))
xlab <- paste0(k, '-mers')
ylab <- 'frequency'

plot(df[1:21,], type = "l", xlab = xlab, ylab = ylab)
points(df[1:21,])     


cutoff <- df[which.min(df[1:10,2]),1]

# genome size calculation
total_kmers <- sum(as.numeric(df[cutoff:21,1] * df[cutoff:21,2]))
peak1 <- df[which.max(df[cutoff:12,2]),1]
size <- total_kmers / peak1

# the single-copy region is the main peak, can be calculated as
single_copy <- sum(as.numeric(df[cutoff:12,1] * df[cutoff:12,2])) / peak1

single_copy / total_kmers

# plot Poisson distribution
plot(1:20, dpois(1:20, peak1) * single_copy, type = "l", col=3, lty=2)
lines(df[1:20,], type="l")


# all in tidyverse
library(tidyverse)
library(cowplot)
histos <- read_tsv(histfile, col_names = c("count", "freq"))
ggplot(histos, aes(x = count, y = freq)) + geom_line() + geom_point()
