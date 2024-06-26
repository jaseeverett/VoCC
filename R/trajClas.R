#' Climate velocity trajectory classification
#'
#' Function for the spatial classification of cells based on VoCC trajectories after Burrows et al. (2014). The function performs
#' a hierarchical sequential classification based on length of trajectories, geographical features, and the relative abundance of
#' trajectories ending in, starting from and flowing through each cell. Essentially, cells are first classified as non-moving,
#' slow-moving and fast-moving relative to the distance a trajectory will cover over the projection period based on local climate velocities.
#' Two types of climate sinks are then identified among the fast-moving cells: (i) boundary (e.g., coastal) cells disconnected from cooler (warmer)
#' neighbouring cells under a locally warming (cooling) climate, and (ii) locations with endorheic spatial gradients where the velocity angles of
#' neighbouring cells converge towards their central point of intersection. Finally, the remaining cells are classified by reference to the total
#' number of trajectories per cell based on the proportions of the number of trajectories starting from (Nst), ending in (Nend), and flowing
#' through (NFT) a cell over the period. Based on these proportions, cells are classified into five classes: (1) climate sources, when no
#' trajectories end in a cell (Nend = 0); (2) relative climate sinks, when the relative number of trajectories ending in a cell is high and the
#' proportion of starting trajectories is low; (3) corridors as cells with a high proportion of trajectories passing through; and (4) divergence
#' and (5) convergence cells identified from the remaining cells as those where fewer/more trajectories ended than started in that
#' cell, respectively.
#'
#' @param traj \code{data.frame} as retuned by voccTraj containing the coordinates
#' and identification number for each trajectory.
#' @param vel \code{raster} with the magnitude of gradient-based climate velocity.
#' @param ang \code{raster} with velocity angles.
#' @param mn \code{raster} with mean climatic values for the study period.
#' @param trajSt \code{integer} number of trajectories starting from each cell or spatial unit.
#' @param tyr \code{integer} number of years comprising the projected period.
#' @param nmL \code{numeric} upper threshold (distance units as per vel object) up to which
#' a trajectory is considered to have traveled a negligible distance over the study period (non-moving).
#' @param smL \code{numeric} upper threshold up to which a trajectory is considered to have traveled a small
#' distance over the study period (slow-moving).
#' @param Nend \code{numeric} the percentage of trajectories ending to be used as threshold in the classification.
#' @param Nst \code{numeric} the percentage of trajectories starting to be used as threshold in the classification.
#' @param NFT \code{numeric} the percentage of trajectories flowing through to be used as threshold in the classification.
#' @param DateLine \code{logical} does the raster extent cross the international date line? (default "FALSE").
#'
#' @return A \code{raster.stack} containing the trajectory classification ("TrajClas"),
#' as well as those based on trajectory length ("ClassL"; 1 non-moving, 2 slow-moving, 3 fast-moving cells),
#' boundrary ("BounS") and internal sinks ("IntS"), and the proportion of trajectories ending("PropEnd"),
#' flowing through ("PropFT") and starting ("PropSt"). The trajectory classes ("TrajClas") are (1) non-moving,
#' (2) slow-moving, (3) internal sinks, (4) boundary sinks, (5) sources, (6) relative sinks, (7) corridors,
#' (8) divergence and (9) convergence.
#'
#' @references \href{https://www.nature.com/articles/nature12976}{Burrows et al. 2014}. Geographical limits to species-range shifts are suggested by climate velocity. Nature, 507, 492-495.
#'
#' @seealso{\code{\link{voccTraj}}}
#'
#' @export
#' @author Jorge Garcia Molinos
#' @examples
#'
#' HSST <- VoCC_get_data("HSST.tif")
#'
#' # input raster layers
#' yrSST <- sumSeries(HSST,
#'   p = "1960-01/2009-12", yr0 = "1955-01-01", l = terra::nlyr(HSST),
#'   fun = function(x) colMeans(x, na.rm = TRUE), freqin = "months", freqout = "years"
#' )
#'
#' mn <- terra::mean(yrSST, na.rm = TRUE)
#' tr <- tempTrend(yrSST, th = 10)
#' sg <- spatGrad(yrSST, th = 0.0001, projected = FALSE)
#' v <- gVoCC(tr, sg)
#' vel <- v[[1]]
#' ang <- v[[2]]
#'
#' # Get the set of starting cells for the trajectories and calculate trajectories
#' # at 1/4-deg resolution (16 trajectories per 1-deg cell)
#' mnd <- terra::disagg(mn, 4)
#' veld <- terra::disagg(vel, 4)
#' angd <- terra::disagg(ang, 4)
#' lonlat <- stats::na.omit(data.frame(
#'   terra::xyFromCell(veld, 1:terra::ncell(veld)),
#'   veld[], angd[], mnd[]
#' ))[, 1:2]
#'
#' traj <- voccTraj(lonlat, vel, ang, mn, tyr = 50, correct = TRUE)
#'
#' # Generate the trajectory-based classification
#' clas <- trajClas(traj, vel, ang, mn,
#'   trajSt = 16, tyr = 50, nmL = 20, smL = 100,
#'   Nend = 45, Nst = 15, NFT = 70, DateLine = FALSE
#' )
#'
#' # Define first the colour palette for the full set of categories
#' my_col <- c(
#'   "gainsboro", "darkseagreen1", "coral4", "firebrick2", "mediumblue", "darkorange1",
#'   "magenta1", "cadetblue1", "yellow1"
#' )
#' # Keep only the categories present in our raster
#' my_col <- my_col[sort(unique(clas[[7]][]))]
#'
#' # Classify raster / build attribute table
#' clasr <- ratify(clas[[7]])
#' rat_r <- levels(clasr)[[1]]
#' rat_r$trajcat <- c(
#'   "N-M", "S-M", "IS", "BS", "Srce",
#'   "RS", "Cor", "Div", "Con"
#' )[sort(unique(clas[[7]][]))]
#' levels(clasr) <- rat_r
#' # Produce the plot using the rasterVis levelplot function
#' rasterVis::levelplot(clasr,
#'   col.regions = my_col,
#'   xlab = NULL, ylab = NULL, scales = list(draw = FALSE)
#' )
trajClas <- function(traj, vel, ang, mn, trajSt, tyr, nmL, smL, Nend, Nst, NFT, DateLine = FALSE) {
  ang1 <- ang2 <- ang3 <- ang4 <- d1 <- d2 <- d3 <- d4 <- NULL # Fix devtools check warnings
  isink <- .SD <- .N <- cid <- coastal <- val <- NULL # Fix devtools check warnings

  TrajEnd <- TrajFT <- TrajSt <- IntS <- BounS <- TrajClas <- terra::rast(ang)
  browser()

  # add cell ID to the data frame
  traj <- data.table::data.table(traj)
  traj$cid <- terra::cellFromXY(ang, traj[, 1:2])

  # A. Number of traj starting from each cell
  TrajSt[!is.na(ang[])] <- trajSt

  # B. Number of traj ending in each cell
  tr <- traj[, data.table::.SD[.N], by = trajIDs] # subset last point of each trajectory
  enTraj <- tr[, .N, by = cid]
  TrajEnd[!is.na(vel)] <- 0
  TrajEnd[enTraj$cid] <- enTraj$N

  # C. Number of traj flowing through each cell
  cxtrj <- unique(traj, by = c("trajIDs", "cid"))
  TotTraj <- cxtrj[, .N, by = cid] # total number of trajectories per cell
  TrajFT[!is.na(vel)] <- 0
  TrajFT[TotTraj$cid] <- TotTraj$N
  TrajFT <- TrajFT - TrajEnd - TrajSt # subtract traj starting and ending to get those actually transversing the cell
  TrajFT[TrajFT[] < 0] <- 0 # to avoid negative values in ice covered cells

  # C. Identify cell location for internal sinks (groups of 4 endorheic cells with angles pointing inwards)
  ll <- data.table::data.table(terra::xyFromCell(ang, 1:terra::ncell(ang)))
  ll[, 1:2] <- ll[, 1:2] + 0.1 # add small offset to the centroid

  # TODO There isn't a direct replaceyment for fourCellsFromXY. Need to look at equivalent code options
  a <- fourCellsFromXY(ang, as.matrix(ll[, 1:2]))
  a <- t(apply(a, 1, sort))

  # If date line crossing, correct sequences on date line
  if (DateLine == TRUE) {
    a[seq(ncol(ang), by = ncol(ang), length = nrow(ang)), ] <- t(apply(a[seq(ncol(ang), by = ncol(ang), length = nrow(ang)), ], 1, function(x) {
      x[c(2, 1, 4, 3)]
    }))
  }

  # Extract the angles for each group of 4 cells
  b <- matrix(terra::extract(ang, as.vector(a)), nrow = terra::ncell(ang), ncol = 4, byrow = FALSE)
  ll[, c("c1", "c2", "c3", "c4", "ang1", "ang2", "ang3", "ang4") := data.frame(a, b)]

  # now look if the 4 angles point inwards (internal sink)
  ll[, c("d1", "d2", "d3", "d4") := list(((ang1 - 180) * (90 - ang1)), ((ang2 - 270) * (180 - ang2)), ((ang3 - 90) * (0 - ang3)), ((ang4 - 360) * (270 - ang4)))]
  ll[, isink := 0L]
  ll[d1 > 0 & d2 > 0 & d3 > 0 & d4 > 0, isink := 1L]

  # get the cids for the cells contained in the sinks
  celdas <- ll[isink == 1, 3:6]
  IntS[!is.na(vel)] <- 0
  IntS[c(celdas[[1]], celdas[[2]], celdas[[3]], celdas[[4]])] <- 1

  # D. Identify cell location for boundary sinks (coastal cells which are disconected from cooler climates under warming or warmer climates under cooling)
  # detect coastal cells
  coast <- suppressWarnings(terra::boundaries(vel, type = "inner", asNA = TRUE)) # to avoid warning for coercing NAs via asNA = TRUE

  # make a list of vel values and SST values for each coastal cells and their marine neighbours
  cc <- stats::na.omit(data.table::data.table(cid = 1:terra::ncell(vel), coast = coast[]))
  ad <- terra::adjacent(vel, cc$cid, 8, sorted = TRUE, include = TRUE) # matrix with adjacent cells
  ad <- data.table::data.table(
    coastal = ad[, 1],
    adjacent = ad[, 2],
    cvel = vel[ad[, 1]],
    ctemp = mn[ad[, 1]],
    atemp = mn[ad[, 2]]
  )

  # locate the sinks
  ad <- stats::na.omit(ad[ad$cvel != 0, ]) # remove cells with 0 velocity (ice) and with NA (land neighbours)
  j <- ad[, ifelse(.SD$cvel > 0, all(.SD$ctemp <= .SD$atemp), all(.SD$ctemp >= .SD$atemp)), by = coastal]
  data.table::setkey(j)
  j <- unique(j)
  BounS[!is.na(vel)] <- 0
  BounS[unique(subset(j$coastal, j$V == TRUE))] <- 1

  # Total number of trajectories per cell and proportions per cell
  TrajTotal <- sum(c(TrajSt, TrajFT, TrajEnd), na.rm = TRUE)
  TrajTotal[is.na(ang[])] <- NA
  PropTrajEnd <- (TrajEnd / TrajTotal) * 100
  PropTrajFT <- (TrajFT / TrajTotal) * 100
  PropTrajSt <- (TrajSt / TrajTotal) * 100

  # reclassify by traj length
  rclM <- matrix(c(0, (nmL / tyr), 1, (nmL / tyr), (smL / tyr), 2, (smL / tyr), Inf, 3), ncol = 3, byrow = TRUE)
  v <- terra::rast(vel)
  v[] <- abs(vel[])
  ClassMov <- terra::classify(v, rclM)

  # Classify the cells
  TrajClas[!is.na(vel)] <- 0

  # capture non-moving (1)
  TrajClas[ClassMov[] == 1] <- 1

  # capture slow-moving (2)
  TrajClas[ClassMov[] == 2] <- 2

  # capture internal (3) and (4) boundary sinks
  TrajClas[IntS[] == 1] <- 3
  TrajClas[BounS[] == 1] <- 4

  # Classify remaining cells into sources(5), rel sinks(6), corridors(7), divergence(8) and convergence(9)
  d <- stats::na.omit(data.table::data.table(cid = 1:terra::ncell(TrajClas), val = TrajClas[]))
  d <- d[val == 0, 1]
  d[, Nend := PropTrajEnd[d$cid]]
  d[, Nst := PropTrajSt[d$cid]]
  d[, NFT := PropTrajFT[d$cid]]
  d$clas <- ifelse(d$Nend == 0, 5, ifelse(d$Nend > Nend & d$Nst < Nst, 6, ifelse(d$NFT > NFT, 7, ifelse(d$Nend < d$Nst, 8, 9))))
  TrajClas[d$cid] <- d$clas

  # return raster
  s <- c(PropTrajEnd, PropTrajFT, PropTrajSt, ClassMov, IntS, BounS, TrajClas)
  names(s) <- c("PropEnd", "PropFT", "PropSt", "ClassL", "IntS", "BounS", "TrajClas")
  return(s)
}
