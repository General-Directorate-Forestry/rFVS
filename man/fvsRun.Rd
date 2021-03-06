% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fvsRun.R
\name{fvsRun}
\alias{fvsRun}
\title{run FVS program}
\usage{
fvsRun(stopPointCode = NA, stopPointYear = NA)
}
\arguments{
\item{stopPointCode}{The value of the next stop point, see Stop Points for a
list of valid codes.}

\item{stopPointYear}{The simulation year the stop point is requested. Code -1
to signal the that the stop point should be immediate.}
}
\value{
A return code from FVS, see Return code state. If the return code is
  zero, then it is often very useful to use fvsGetRestartcode() to fetch the
  restart code that resulted in FVS returning. When fvsRun() is called again,
  it will continue processing where it left off. Repeating the call to
  fvsRun() until it is non-zero is how to create a simple simulation.
}
\description{
Run FVS program
}
