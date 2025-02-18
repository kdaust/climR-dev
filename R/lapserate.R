# Recycle the borders of matrix to expand the matrix by one cell in each directions
# It will help later with the offset approach.
#' @param mat A matrix to recycle borders from.
#' @param nr The number of rows in the matrix.
#' @param nc The number of columns in the matrix.
#' @noRd
recycle_borders <- function(mat, nr, nc) {
  
  # Instantiate an extended border representation
  res <- matrix(nrow = nr + 2L, ncol = nc + 2L)
  
  # Fill the representation starting with the original data in the center
  res[2L:(nr + 1L), 2L:(nc + 1L)] <- mat
  
  # Recycle the borders
  # North
  res[1L, 2L:(nc + 1L)] <- mat[1L,]
  # South
  res[(nr + 2L), 2L:(nc + 1L)] <- mat[nr,]
  # West
  res[2L:(nr + 1L), 1L] <- mat[,1L]
  # East
  res[2L:(nr + 1L), nc + 2L] <- mat[,nc]
  
  # Recycle the corners
  # North-West
  res[1L, 1L] <- mat[1L, 1L]
  # North-East
  res[1L, (nc + 2L)] <- mat[1L, nc]
  # South-West
  res[(nr + 2L), 1L] <- mat[nr, 1L]
  # South-East
  res[(nr + 2L), (nc + 2L)] <- mat[nr, nc]
  
  return(res)
  
}

# This returns a single matrix containing the sums of matching row, cell
# in the list of matrices.
#' @param x A list of matrices of the same dimensions
#' @noRd
sum_matrix <- function(x) {
  Reduce(`+`, x)
}

# This returns a list of matrices corresponding to the products of
# individual corresponding cells from each x matrices and y matrices
#' @param x A list of matrices of the same dimensions.
#' @param y A list of matrices of the same dimensions as x and the same
#' length as x.
#' @noRd
prod_matrix <- function(x, y) {
  mapply(`*`, x, y, SIMPLIFY = FALSE)
}

# This returns a list of matrices corresponding to the differences of
# individual corresponding cells from each x matrices and y matrices
#' @param x A list of matrices of the same dimensions.
#' @param y A list of matrices of the same dimensions as x and the same
#' length as x.
#' @noRd
delta_matrix <- function(x, y) {
  mapply(`-`, x, y, SIMPLIFY = FALSE)
}

# This returns a list of matrices after applying exponent `exp` to each
# matrix cells
#' @param x A list of matrices.
#' @param exp A numeric vector of length 1.
#' @noRd
sup <- function(x, exp) {
  lapply(x, `^`, exp)
}

# This returns the fitted simple linear regression values using 
# a pre-calculated beta coefficient matrix.
#' @param x A list of matrices of the same dimensions.
#' @param beta_coef A matrix of the same dimensions as a matrix in x.
#' @noRd
fitted <- function(x, beta_coef) {
  lapply(x, function(x) x*beta_coef)
}

# This compute a list of matrices. Each matrix represents differences between
# surrounding cells and the reference cells.
# It uses an offset approach to compute surrounding cells in each directions.
#' @param mat A matrix previously ran through `recycle_borders`
#' @param nr The number of rows in the original matrix used by `recycle_borders`
#' @param nc The number of columns in the original matrix used by `recycle_borders`
#' @param NA_replace A boolean. Should NA delta results be replaced by zeros. Default to TRUE.
#' @noRd
deltas <- function(mat, nr, nc, NA_replace = TRUE) {
  
  # Reference values
  ref <- mat[c(-1L,-(nr+2L)), c(-1L,-(nc+2L))]
  
  # Surrounding values
  res <- list(
    northwest = mat[-(nr + 1L):-(nr + 2L), -(nc + 1L):-(nc + 2L)] - ref,
    north     = mat[-(nr + 1L):-(nr + 2L), c(-1L,-(nc + 2L))] - ref,
    northeast = mat[-(nr + 1L):-(nr + 2L), -1L:-2L] - ref,
    east      = mat[c(-1L,-(nr + 2L)), -1L:-2L] - ref,
    southeast = mat[-1L:-2L, -1L:-2L] - ref,
    south     = mat[-1L:-2L, c(-1L,-(nc + 2L))] - ref,
    southwest = mat[-1L:-2L, -(nc + 1L):-(nc + 2L)] - ref,
    west      = mat[c(-1L,-(nr + 2L)), -(nc + 1L):-(nc + 2L)] - ref
  )
  
  # Replace NA/NaN by 0
  # Only the deltas are replaced by 0.
  NArep <- function(x) {
    x[is.na(x)] <- 0L
    return(x)
  }
  if (isTRUE(NA_replace)) {
    res <- lapply(res, NArep)
  }
  
  return(res)
}

#' Lapse rate computation
#' @param normal Normal rasters to compute lapse rates for. Build with this package functions.
#' @param dem A digital elevation model with matching normal extent.
#' @param NA_replace A boolean. Should NA lapse rate results be replaced by zeros. Default to TRUE.
#' @param nthread An integer. Number of parallel threads to use to compute lapse rates.
#' @param rasterize Return an object of the same class category as normal with the same extend.
#' @details Formulas
#' Simple linear regression without the intercept term
#' beta_coef = sum(xy) / sum(x²)
#' mss = sum(x * beta_coef)², sum of squared fitted values
#' rss = sum(ε²), sum of squared (y minus fitted), sum of absolute errors
#' R² = mss / (mss + rss)
#' Lapse rate = beta_coef * R²
#' @return Lapse rate values.
#' @importFrom terra as.list as.matrix ext nlyr  compareGeom resample rast crs
#' @importFrom parallel makeForkCluster makePSOCKcluster stopCluster parLapply
#' @export
lapse_rate <- function(normal, dem, NA_replace = TRUE, nthread = 1L, rasterize = TRUE) {
  
  # Transform normal to list, capture names before
  normal_names <- names(normal)
  
  # Validation
  if (terra::nlyr(normal) != 36L || !all(sprintf(c("PPT%02d", "Tmax%02d", "Tmin%02d"),sort(rep(1:12,3))) %in% names(normal))) {
    stop(
      "Normal raster does not have the required 36 layers. Required layers are ",
      paste(sort(sprintf(c("PPT%02d", "Tmax%02d", "Tmin%02d"),sort(rep(1:12,3)))), collapse = ", "),
      "."
    )
  }
  if (terra::nlyr(dem) != 1L) {
    stop(
      "Digital elevation model raster has to have one layer only."
    )
  }
  # Matching geometries check
  if (!terra::compareGeom(normal, dem)) {
    warning("Normal and Digital elevation model rasters have different extents. They must be the same. Resampling dem to match.")
    dem <- terra::resample(dem, normal, method = "bilinear")
  }
  
  # Compute everything related to the dem and independant of normal
  n_r <- nrow(dem)
  n_c <- ncol(dem)
  x_i <- shush(terra::as.matrix(dem, wide = TRUE))
  # Expand and recycle borders
  x_i <- recycle_borders(x_i, n_r, n_c)
  # Compute surrounding cells deltas
  x_i <- deltas(x_i, n_r, n_c, NA_replace)
  # Number of surrounding cells
  n_sc <- length(x_i)
  # Sums of x squared
  sum_xx <- sum_matrix(sup(x_i,2))
  
  # For the lapse rate, x is the elevation, and y is the normal
  lapse_rate_redux <- function(y_i, x_i, n_r, n_c, n_sc, sum_xx, NA_replace) {
    
    # Expand and recycle borders
    y_i <- recycle_borders(y_i, n_r, n_c)
    # Compute surrounding cells deltas
    y_i <- deltas(y_i, n_r, n_c)
    # This is the regression coefficient matrix
    beta_coef <- sum_matrix(prod_matrix(x_i, y_i)) / sum_xx
    # We need the fitted values to compute the
    # coefficient of determination
    f <- fitted(x_i, beta_coef)
    # We use the same approach as stats::summary.lm
    # applied to a list matrices
    mss <- sum_matrix(sup(f,2))
    rss <- sum_matrix(sup(delta_matrix(y_i,f),2))
    # We can combine the resulting matrices to get the
    # coefficient of determination and multiply by beta coefficient
    lapse_rate <- beta_coef * mss / (mss + rss)
    
    if (isTRUE(NA_replace)) {
      lapse_rate[is.na(lapse_rate)] <- 0L  
    }
    
    # And we can return the lapse rate
    return(lapse_rate)
    
  }
  
  if (isTRUE(nthread > 1L)) {
    
    # initiate cluster
    if (Sys.info()['sysname'] != "Windows") {
      cl <- parallel::makeForkCluster(nthread)
    } else {
      cl <- parallel::makePSOCKcluster(nthread)
    }
    
    # destroy cluster on exit
    on.exit(parallel::stopCluster(cl), add = TRUE)
    
    res <- parallel::parLapply(
      cl = cl,
      X = shush(lapply(terra::as.list(normal), terra::as.matrix, wide = TRUE)),
      fun = lapse_rate_redux,
      x_i = x_i,
      n_r = n_r,
      n_c = n_c,
      n_sc = n_sc,
      sum_xx = sum_xx,
      NA_replace = NA_replace
    )
    
  } else {
    
    # Use regular lapply
    res <- lapply(
      X = shush(lapply(terra::as.list(normal), terra::as.matrix, wide = TRUE)),
      FUN = lapse_rate_redux,
      x_i = x_i,
      n_r = n_r,
      n_c = n_c,
      n_sc = n_sc,
      sum_xx = sum_xx,
      NA_replace = NA_replace
    )
    
  }
  
  # Transform back into SpatRaster
  if (isTRUE(rasterize)) {
    res <- shush(
      terra::rast(
        lapply(
          res,
          terra::rast,
          extent = terra::ext(normal)
        )
      )
    )
    terra::crs(res) <- terra::crs(normal)
  }
  
  # Set names of lapse rates to match normal
  names(res) <- normal_names
  
  return(res)
  
}