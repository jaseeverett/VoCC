% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tempTrend.R
\name{tempTrend}
\alias{tempTrend}
\title{Long-term local climatic trends}
\usage{
tempTrend(r, th)
}
\arguments{
\item{r}{\code{RasterStack} containing a time series of (annual, seasonal, monthly...) values of
the climatic variable for the period of interest.}

\item{th}{\code{Integer} minimum number of observations in the series needed to
calculate the trend at each cell.}
}
\value{
A \code{RasterStack} containing the cell-specific temporal trends
extracted from simple linear regressions of the climatic variable against time
("slpTrends" in degree Celsius per year), together with their standard
errors ("seTrends") and statistical significance ("sigTrends").
}
\description{
Function to calculate temporal trend from a raster series
of a climatic variable. This trend is to be used for the calculation of the
gradient-based climate velocity using gVoCC.
}
\examples{

HSST <- VoCC_get_data("HSST.tif")

yrSST <- sumSeries(HSST,
  p = "1969-01/2009-12", yr0 = "1955-01-01", l = terra::nlyr(HSST),
  fun = function(x) colMeans(x, na.rm = TRUE), freqin = "months", freqout = "years"
)

# Mean annual SST trend (minimum threshold of 10 years of data), with SE and p-values.

tr <- tempTrend(yrSST, th = 10)

terra::plot(tr)
}
\seealso{
{\code{\link{spatGrad}}, \code{\link{gVoCC}}}
}
\author{
Jorge Garcia Molinos and Christopher J. Brown
}
