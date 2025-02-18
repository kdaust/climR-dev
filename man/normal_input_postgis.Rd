% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/normal.R
\name{normal_input_postgis}
\alias{normal_input_postgis}
\title{Create normal baseline input for \code{downscale} from postgis database.}
\usage{
normal_input_postgis(
  dbCon,
  bbox = NULL,
  normal = list_normal()[1],
  cache = TRUE
)
}
\arguments{
\item{dbCon}{A db connection object created by \code{data_connect}.}

\item{bbox}{Numeric vector of length 4 giving bounding box of study region, create by \code{get_bb()}}

\item{normal}{A character or a SpatRaster. For character, label of the normal baseline to use.
Can be obtained from \code{list_normal()}. For SpatRaster, 36 layers normal climate variables with
names PPT01:PPT12, Tmax01:Tmax12 and Tmin01:Tmin12. Default to \code{list_normal()[1]}.}
}
\value{
A normal baseline to use with \code{downscale}. A \code{SpatRaster} containing normals, lapse rates
and digital elevation model layers.
}
\description{
Create normal baseline input for \code{downscale} from postgis database.
}
