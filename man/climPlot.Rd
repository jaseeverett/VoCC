% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/climPlot.R
\name{climPlot}
\alias{climPlot}
\title{Binned scatter plot for 2-dimensional climate space}
\usage{
climPlot(xy, x.binSize, y.binSize, x.name = "V1", y.name = "V2")
}
\arguments{
\item{xy}{\code{data.frame} with cells as rows and 4 columns representing the present and future local values for the two variables (V1p, V1f, V2p, V2f).}

\item{x.binSize}{\code{numeric} the bin size for the first variable.}

\item{y.binSize}{\code{numeric} the bin size for the second variable.}

\item{x.name}{\code{character} the variable name for the first variable. Used to label the plot.}

\item{y.name}{\code{character} the variable name for the second variable. Used to label the plot.}
}
\value{
A series of \code{plot} objects displaying the (i) present and (ii) future
cell frequency for each combination of local climates,
and (iii) the location of remnant, novel and disappearing climates between both periods.
}
\description{
Function to create a binned scatter plot of two climate variables.
}
\examples{

JapTC <- VoCC_get_data("JapTC.tif")

# Plot climate space for the two first variables(annual precipitation and maximum temperature)
xy <- stats::na.omit(data.frame(
  terra::values(JapTC[[1]]),
  terra::values(JapTC[[2]]),
  terra::values(JapTC[[3]]), terra::values(JapTC[[4]])
))

out <- climPlot(xy,
  x.binSize = 5, y.binSize = 0.2, x.name = "Precipitation (mm)",
  y.name = "Temperature max (°C)"
)

\dontrun{
# output plots can be saved as:
ggplot2::ggsave(
  plot = out, filename = file.path(getwd(), "example_plot.pdf"),
  width = 17, height = 17, unit = "cm"
)
}
}
\seealso{
{\code{\link{dVoCC}}, \code{\link{climPCA}}}
}
\author{
Jorge Garcia Molinos and Naoki H. Kumagai
}
