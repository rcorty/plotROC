#' Key for PRC geom
#' 
#' @keywords Internal
#' @param data Data created by stat
#' @param params parameters
#' @param size Size
#' 
prc_key <- function(data, params, size) {
  
  grobTree(
    draw_key_path(data, params, size), 
    pointsGrob(0.5, 0.5,
               pch = data$shape,
               size = unit(data$size * .pt * 2, 'pt'),
               gp = gpar(
                 col = alpha(data$colour, data$alpha),
                 fontsize = data$size * .pt * 4,
                 lwd = data$stroke 
               )
    )
  )
}




#' @export
#' @rdname stat_prc

StatPrc <- 
  ggproto(`_class` = 'StatPrc',
          `_inherit` = Stat,
          required_aes = c('m', 'd'),
          default_aes = aes(x = ..recall..,
                            y = ..precision..,
                            label = ..cutoffs..),
          
          setup_data = function(data, params){
            data$d <- verify_d(data$d)
            data$group <- NULL
            disc <- vapply(data, is.discrete, logical(1))
            disc[names(disc) %in% c('label', 'PANEL')] <- FALSE
            
            if (any(disc)) {
              data$group <- plyr::id(data[disc], drop = TRUE)
            } else {
              data$group <- -1L
            } 
            data
          },
          
          compute_group = function(data,
                                   scales, 
                                   na.rm = TRUE, 
                                   max.num.points = 1e3, 
                                   increasing = TRUE) {
            
            if(na.rm) {
              data <- subset(data, !is.na(d) & !is.na(m))
            }
            
            T.order <- order(data$m, decreasing = !increasing)
            obs_in_order <- data$m[T.order]
            preds_in_order <- data$d[T.order]
            
            TP_count <- cumsum(data$d[T.order] == 1)
            FN_count <- rev(cumsum(rev(data$d[T.order]) == 1))
            
            dups <- rev(duplicated(rev(obs_in_order)))
            obs_in_order <- obs_in_order[!dups]
            
            l <- length(obs_in_order)
            p <- max.num.points
            
            TP_count <- TP_count[!dups]
            FN_count <- FN_count[!dups]
            
            if (!is.null(max.num.points)) {
              obs_in_order <- obs_in_order[seq(from = 1, to = l, length.out = p)]
              TP_count <- TP_count[seq(from = 1, to = l, length.out = p)]
              FN_count <- FN_count[seq(from = 1, to = l, length.out = p)]
            }
            
            TPR <- c(0, TP_count)/sum(data$d == 1)
            PPV <- c(TP_count[1], TP_count/seq(from = 1, to = min(l, max.num.points)))
            
            Lowest <- ifelse(test = increasing, yes = Inf, no = -Inf)
            
            cutoffs <- c(Lowest, obs_in_order)
            
            data.frame(recall = TPR, 
                       precision = PPV,
                       cutoffs = cutoffs)
            
            
          }
  )

#' Calculate the empirical Receiver Operating Characteristic curve
#' 
#' Given a binary outcome d and continuous measurement m, computes the empirical
#' PRC curve for assessing the classification accuracy of m
#' 
#' @inheritParams ggplot2::stat_identity
#' @param na.rm Remove missing observations
#' @param max.num.points maximum number of points to plot
#' @param increasing TRUE (default) if M is positively associated with Pr(D = 1), if FALSE, assumes M is negatively associated with Pr(D = 1)
#' @section Aesthetics:
#' \code{stat_prc} understands the following aesthetics (required aesthetics
#' are in bold):
#' \itemize{
#'   \item \strong{\code{m}} The continuous biomarker/predictor
#'   \item \strong{\code{d}} The binary outcome, if not coded as 0/1, the 
#'   smallest level in sort order is assumed to be 0, with a warning
#'   \item \code{alpha} Controls the label alpha, see also \code{linealpha} and \code{pointalpha}
#'   \item \code{color}
#'   \item \code{linetype} 
#'   \item \code{size} Controls the line weight, see also \code{pointsize} and \code{labelsize}
#' }
#' @section Computed variables:
#' \describe{
#'   \item{false_positive_fraction}{estimate of false positive fraction}
#'   \item{true_positive_fraction}{estimate of true positive fraction}
#'   \item{cutoffs}{values of m at which estimates are calculated}
#' }
#' @export
#' @rdname stat_prc
#' @examples
#' D.ex <- rbinom(50, 1, .5)
#' rocdata <- data.frame(D = c(D.ex, D.ex), 
#'                    M = c(rnorm(50, mean = D.ex, sd = .4), rnorm(50, mean = D.ex, sd = 1)), 
#'                    Z = c(rep('A', 50), rep('B', 50)))
#'
#' ggplot(rocdata, aes(m = M, d = D)) + stat_prc()

stat_prc <- function(mapping = NULL,
                     data = NULL,
                     geom = 'prc',
                     position = 'identity',
                     show.legend = NA,
                     inherit.aes = TRUE,
                     na.rm = TRUE,
                     max.num.points = 1e3,
                     increasing = TRUE,
                     ...) {
  layer(
    stat = StatPrc,
    data = data,
    mapping = mapping,
    geom = geom,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list(na.rm = na.rm,
                  max.num.points = max.num.points,
                  increasing = TRUE,
                  ...)
  )
  
}

#' @param n.cuts Number of cutpoints to display along each curve
#' @param lineend Line end style (round, butt, square)
#' @param linejoin Line join style (round, mitre, bevel)
#' @param linemitre Line mitre limit (number greater than 1)
#' @param arrow Arrow specification, as created by \code{\link[grid]{arrow}}
#' @param linealpha Alpha level for the lines, alpha.line is deprecated
#' @param pointalpha Alpha level for the cutoff points, alpha.point is deprecated
#' @param pointsize Size of cutoff points, size.point is deprecated
#' @param labels Logical, display cutoff text labels
#' @param labelsize Size of cutoff text labels
#' @param labelround Integer, number of significant digits to round cutoff labels
#' @param na.rm Remove missing values from curve
#' @param cutoffs.at Vector of user supplied cutoffs to plot as points. If non-NULL, 
#' it will override the values of n.cuts and plot the observed cutoffs closest to the user-supplied ones.
#' @param cutoff.labels vector of user-supplied labels for the cutoffs.  Must be a character vector of
#' the same length as cutoffs.at.
#' @section Computed variables:
#' \describe{
#'   \item{false_positive_fraction}{estimate of false positive fraction}
#'   \item{true_positive_fraction}{estimate of true positive fraction}
#'   \item{cutoffs}{values of m at which estimates are calculated}
#' }
#' @export
#' @rdname geom_prc
#' @examples
#' D.ex <- rbinom(50, 1, .5)
#' rocdata <- data.frame(D = c(D.ex, D.ex), 
#'                    M = c(rnorm(50, mean = D.ex, sd = .4), rnorm(50, mean = D.ex, sd = 1)), 
#'                    Z = c(rep('A', 50), rep('B', 50)))
#'
#' ggplot(rocdata, aes(m = M, d = D)) + geom_prc()
#' \donttest{
#' ggplot(rocdata, aes(m = M, d = D, color = Z)) + geom_prc()
#' ggplot(rocdata, aes(m = M, d = D)) + geom_prc() + facet_wrap(~ Z)
#' ggplot(rocdata, aes(m = M, d = D)) + geom_prc(n.cuts = 20)
#' ggplot(rocdata, aes(m = M, d = D)) + geom_prc(cutoffs.at = c(1.5, 1, .5, 0, -.5))
#' ggplot(rocdata, aes(m = M, d = D)) + geom_prc(labels = FALSE)
#' ggplot(rocdata, aes(m = M, d = D)) + geom_prc(size = 1.25)
#' }

GeomPrc <- ggproto(`_class` = 'GeomPrc',
                   `_inherit` = Geom, 
                   required_aes = c('x', 'y', 'label'), 
                   default_aes = aes(shape = 19, colour = 'black', alpha = 1, size = 1, linetype = 1,
                                     angle = 0, hjust = 1,
                                     vjust = 1, family = '', fontface = 1, lineheight = 1.2),
                   non_missing_aes = c('size', 'shape'),
                   draw_group = function(data, panel_scales, coord, n.cuts = 10, arrow = NULL,
                                         lineend = 'butt', linejoin = 'round', linemitre = 1, 
                                         linealpha = 1, pointalpha = 1, size.point, alpha.point, alpha.line, 
                                         pointsize = .5, labels = TRUE, labelsize = 3.88, labelround = 1,
                                         na.rm = TRUE, cutoffs.at = NULL, cutoff.labels = NULL, ...){
                     
                     if(!missing(alpha.line)) linealpha <- alpha.line
                     if(!missing(alpha.point)) pointalpha <- alpha.point
                     if(!missing(size.point)) pointsize <- size.point
                     
                     
                     if(!is.null(cutoffs.at)) {
                       ## find the index of the points closest to the supplied cutoffs
                       dex <- sapply(cutoffs.at, function(x){ 
                         in.dx <- abs(data$cutoffs - x)
                         which.min(in.dx)
                       })
                       
                       
                     } else {
                       if(nrow(data) < n.cuts){ 
                         dex <- 1:nrow(data)
                       } else {
                         dex <- as.integer(seq(1, nrow(data), length.out = n.cuts))
                       }
                     }
                     
                     coords <- coord$transform(data, panel_scales)
                     coordsp <- coord$transform(data[dex, ], panel_scales)
                     
                     if(n.cuts > 0) { 
                       pg <- pointsGrob(
                         coordsp$x, coordsp$y,
                         pch = coordsp$shape,
                         size = unit(pointsize, 'char'),
                         gp = gpar(
                           col = coordsp$colour,
                           fill = coordsp$fill,
                           alpha = pointalpha
                         )
                       )
                       
                       
                     } else{ 
                       pg <- nullGrob()
                       
                     }
                     
                     keep <- function(x) {
                       # from first non-missing to last non-missing
                       first <- match(FALSE, x, nomatch = 1) - 1
                       last <- length(x) - match(FALSE, rev(x), nomatch = 1) + 1
                       c(
                         rep(FALSE, first),
                         rep(TRUE, last - first),
                         rep(FALSE, length(x) - last))
                     }
                     # Drop missing values at the start or end of a line - can't drop in the
                     # middle since you expect those to be shown by a break in the line
                     missing <- !stats::complete.cases(data[c('x', 'y', 'size', 'colour',
                                                              'linetype')])
                     kept <- stats::ave(missing, data$group, FUN = keep)
                     data <- data[kept, ]
                     # must be sorted on group
                     data <- plyr::arrange(data, group)
                     
                     if (!all(kept) && !na.rm) {
                       warning('Removed ', sum(!kept), ' rows containing missing values',
                               ' (geom_path).', call. = FALSE)
                     }
                     
                     munched <- coord_munch(coord, data, panel_scales)
                     
                     # Silently drop lines with less than two points, preserving order
                     rows <- stats::ave(seq_len(nrow(munched)), munched$group, FUN = length)
                     munched <- munched[rows >= 2, ]
                     if (nrow(munched) < 2) return(zeroGrob())
                     
                     # Work out whether we should use lines or segments
                     attr <- plyr::ddply(munched, 'group', function(df) {
                       data.frame(
                         solid = identical(unique(df$linetype), 1),
                         constant = nrow(unique(df[, c('alpha', 'colour','size', 'linetype')])) == 1
                       )
                     })
                     solid_lines <- all(attr$solid)
                     constant <- all(attr$constant)
                     if (!solid_lines && !constant) {
                       stop('geom_path: If you are using dotted or dashed lines',
                            ', colour, size and linetype must be constant over the line',
                            call. = FALSE)
                     }
                     
                     # Work out grouping variables for grobs
                     n <- nrow(munched)
                     group_diff <- munched$group[-1] != munched$group[-n]
                     start <- c(TRUE, group_diff)
                     end <-   c(group_diff, TRUE)
                     
                     if (!constant) {
                       lg <- segmentsGrob(
                         munched$x[!end], munched$y[!end], munched$x[!start], munched$y[!start],
                         default.units = 'native', arrow = arrow,
                         gp = gpar(
                           col = alpha(munched$colour, linealpha)[!end],
                           fill = alpha(munched$colour, linealpha)[!end],
                           lwd = munched$size[!end] * .pt,
                           lty = munched$linetype[!end],
                           lineend = lineend,
                           linejoin = linejoin,
                           linemitre = linemitre
                         )
                       )
                     } else {
                       id <- match(munched$group, unique(munched$group))
                       lg <- polylineGrob(
                         munched$x, munched$y, id = id,
                         default.units = 'native', arrow = arrow,
                         gp = gpar(
                           col = alpha(munched$colour, linealpha)[start],
                           fill = alpha(munched$colour, linealpha)[start],
                           lwd = munched$size[start] * .pt,
                           lty = munched$linetype[start],
                           lineend = lineend,
                           linejoin = linejoin,
                           linemitre = linemitre
                         )
                       )
                     }
                     
                     if (labels & (n.cuts > 0 | !is.null(cutoffs.at))) {
                       
                       if (is.null(cutoff.labels)) {
                         lab <- round(coordsp$label, labelround)
                       } else {
                         lab <- cutoff.labels
                       }
                       
                       
                       if (is.character(coordsp$vjust)) {
                         coordsp$vjust <- compute_just(coordsp$vjust, coordsp$y)
                       }
                       if (is.character(coordsp$hjust)) {
                         coordsp$hjust <- compute_just(coordsp$hjust, coordsp$x)
                       }
                       
                       cg <- textGrob(
                         lab,
                         coordsp$x - .01, coordsp$y + .02, default.units = 'native',
                         hjust = coordsp$hjust, vjust = coordsp$vjust,
                         rot = coordsp$angle,
                         gp = gpar(
                           col = alpha(coordsp$colour, coordsp$alpha),
                           fontsize = labelsize * .pt,
                           fontfamily = coordsp$family,
                           fontface = coordsp$fontface,
                           lineheight = coordsp$lineheight
                         )
                       )
                       
                     } else cg <- nullGrob()
                     
                     gList(pg, lg, cg)
                     
                     
                   }, 
                   draw_key = prc_key 
)

#' Empirical Receiver Operating Characteristic Curve
#' 
#' Display the empirical PRC curve. Useful for characterizing the classification
#' accuracy of continuous measurements for predicting binary states
#' 
#' @section Aesthetics:
#' \code{geom_prc} understands the following aesthetics (required aesthetics
#' are in bold):
#' \itemize{
#'   \item \strong{\code{x}} The FPF estimate. This is automatically mapped by \link{stat_prc}
#'   \item \strong{\code{y}} The TPF estimate. This is automatically mapped by \link{stat_prc}
#'   smallest level in sort order is assumed to be 0, with a warning
#'   \item \code{alpha}
#'   \item \code{color}
#'   \item \code{fill}
#'   \item \code{linetype}
#'   \item \code{size}
#' }
#'
#' @param stat Use to override the default connection between
#'   \code{geom_prc} and \code{stat_prc}.
#' @inheritParams ggplot2::geom_point
#' @export
#' 

geom_prc <- function(mapping = NULL, data = NULL, stat = 'prc', n.cuts = 10, arrow = NULL,
                     lineend = 'butt', linejoin = 'round', linemitre = 1, 
                     linealpha = 1, pointalpha = 1, 
                     pointsize = .5, labels = TRUE, labelsize = 3.88, labelround = 1,
                     na.rm = TRUE, cutoffs.at = NULL, cutoff.labels = NULL, position = 'identity', show.legend = NA, inherit.aes = TRUE, ...) {
  
  
  layer(
    geom = GeomPrc, mapping = mapping, data = data, stat = stat, 
    position = position, show.legend = show.legend, inherit.aes = inherit.aes, 
    params = list(na.rm = na.rm, n.cuts = n.cuts, arrow = arrow,
                  lineend = lineend, linejoin = linejoin, linemitre = linemitre, 
                  linealpha = linealpha, pointalpha = pointalpha,
                  pointsize = pointsize, labels = labels, labelsize = labelsize, labelround = labelround, 
                  cutoffs.at = cutoffs.at, cutoff.labels = cutoff.labels, ...)
  )
}


