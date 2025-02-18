#' Calculate Extreme Minimum Temperature (EMT)
#' @param m month of the year
#' @param tmin monthly mean minimum air temperature
#' @param tmax monthly mean maximum air temperature
#' @param latitude point latitudes
#' @return Reference evaporation (Eref)
calc_Eref <- function(m, tmin, tmax, latitude) {
  
  Eref <- numeric(length(tmax))
  tmean <- (tmax + tmin)/2
  i <- which(tmean >= 0)
  day_month <- c(31,28.25,31,30,31,30,31,31,30,31,30,31)
  day_julian <- c(15,45,74,105,135,166,196,227,258,288,319,349)
  # Paper unclear, 1.18 - 0.0065 in Appendix, 1.18 - 0.0067 in paper
  # Wangetal2012_ClimateWNA_JAMC-D-11-043.pdf
  # Probably missing
  Eref[i] <- 0.0023 * day_month[m] *
    calc_S0_I(day_julian[m], tmean[i], latitude[i]) *
    (tmean[i] + 17.8) * sqrt(tmax[i] - tmin[i]) * 
    (1.18 - 0.0065 * latitude[i])
  return(Eref)
  
}

#' Calculate climatic moisture deficit (CMD)
#' @param Eref Reference evaporation
#' @param PPT Precipitation mm
#' @return Climatic moisture deficit
calc_CMD <- function(Eref, PPT) {
  CMD <- numeric(length(Eref))
  i <- which(Eref > PPT)
  CMD[i] <- Eref[i]-PPT[i]
  return(CMD)
}

#' PROGRAM I From Hargreaves 1985
#' @param d julian day of the year (January 1 = 1, Decembre 31 = 365)
#' @param tmean mean temperature for that month
#' @param latitude point latitudes
#' @return Extraterrestrial radiation estimation in mm/day
calc_S0_I <- function(d, tmean, latitude) {
  # BASIC COMPUTER PROGRAM FOR ESTIMATING DAILY RA VALUES
  # D=JULIAN DAY (JANUARY 1=1)
  # DEC=DECLINATION OF THE SUN IN RADIANS
  # ES=MEAN MONTHLY DISTANCE OF THE SUN TO THE EARTH DIVIDED BY THE MEAN ANNUAL DISTANCE
  # LD=LATITUDES IN DEGREES
  # LDM=MINUTES OF LATITUDES
  # RA=MEAN MONTHLY EXTRATERRESTRIAL RADIATION IN MM/DAY
  # RAL=MEAN MONTHLY EXTRATERRESTRIAL RADIATION IN LANGLEYS/DAY
  # TC=MEAN DAILY TEMPERATURE IN DEGREE CELSIUS
  Y = cos(0.0172142 * (d + 192L))
  DEC = 0.40876 * Y
  ES = 1.0028 + 0.03269 * Y
  XLR = latitude / 57.2958
  Z <- -tan(XLR) * tan(DEC)
  OM <- -atan(Z/sqrt(-Z*Z+1)) + pi/2
  # CALCULATE THE DAILY EXTRATERRESTRIAL RADIATION IN LANGLEYS/DAY
  DL <- OM / 0.1309
  RAL <- 120 * (DL * sin(XLR) * sin(DEC) + 7.639 * cos(XLR) * cos(DEC) * sin(OM))/ES
  # CALCULATE THE EXTRATERRESTRIAL RADIATION IN MM/DAY
  RA <- RAL * 10 / (595.9 - 0.55 * tmean)
  
  return(RA)
}

#' PROGRAM II From Hargreaves 1985
#' @param m month of the year
#' @param tmean mean temperature for that month
#' @param latitude point latitudes
#' @return Extraterrestrial radiation estimation in mm/day
calc_S0_II <- function(m, tmean, latitude) {
  # BASIC COMPUTER PROGRAM FOR ESTIMATING MONTHLY RA VALUES
  # DEC=DECLINATION OF THE SUN IN RADIANS
  # ES=MEAN MONTHLY DISTANCE OF THE SUN TO THE EARTH DIVIDED BY THE MEAN ANNUAL DISTANCE
  # LD=LATITUDES IN DEGREES
  # LDM=MINUTES OF LATITUDES
  # RA=MEAN MONTHLY EXTRATERRESTRIAL RADIATION IN MM/DAY
  # RAL=MEAN MONTHLY EXTRATERRESTRIAL RADIATION IN LANGLEYS/DAY
  # TC=MEAN MONTHLY TEMPERATURE IN DEGREE CELSIUS
  # DEC <- numeric(12)
  # ES <- numeric(12)
  DEC <- - 0.00117 - 0.40117 * cos(pi*m) -
    0.042185 * sin(pi*m) + 0.00163 * 
    cos(2*pi*m) + 0.00208 * sin(2*pi*m)
  # CALCULATE THE RELATIVE DISTANCE OF THE SUN TO THE EARTH
  ES <- 1.00016 - 0.032126 * cos(pi*m) -
    0.0033535 * sin(pi*m)
  XLR <- latitude / 57.2958
  Z <- -tan(XLR) * tan(DEC)
  OM <- -atan(Z/sqrt(-Z*Z+1)) + pi/2
  # CALCULATE THE DAILY EXTRATERRESTRIAL RADIATION IN LANGLEYS/DAY
  RAL <- 916.732 * (OM * sin(XLR) * sin(DEC) + cos(XLR) * cos(DEC) * sin(OM))/ES
  # CALCULATE THE EXTRATERRESTRIAL RADIATION IN MM/DAY
  RA <- RAL * 10 / (595.9 - 0.55 * tmean)
  
  return(RA)
}
