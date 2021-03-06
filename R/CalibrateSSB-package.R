#' Weighting and Estimation for Panel Data with Non-Response
#' 
#' CalibrateSSB is an R-package that handles repeated surveys with partially
#' overlapping samples. Initially the samples are weighted by linear
#' calibration using known or estimated population totals. A robust model based
#' covariance matrix for all relevant estimated totals is calculated from the
#' residuals according to the calibration model. Alternatively a design based
#' covariance matrix is calculated in a very similar way. A cluster robust
#' version is also possible. In the case of estimated populations totals the
#' covariance matrix is adjusted by utilizing the theory of Särndal and
#' Lundström (2005). Variances of linear combinations (changes and averages)
#' and ratios are calculated from this covariance matrix. The linear
#' combinations and ratios can involve variables within and/or between sample
#' waves. \cr
#' 
#' @name CalibrateSSB-package
#' @docType package
#' 
#' @references Langsrud, Ø (2016): \dQuote{A variance estimation R-package for
#' repeated surveys - useful for estimates of changes in quarterly and annual
#' averages}, \emph{Romanian Statistical Review} nr. 2 / 2016, pp. 17-28.
#' CONFERENCE: \emph{New Challenges for Statistical Software - The Use of R in
#' Official Statistics}, Bucharest, Romania, 7-8 April. \cr
#' 
#' Särndal, C.-E. and Lundström, S. (2005): \emph{Estimation in Surveys with
#' Nonresponse}, John Wiley and Sons, New York.
#' @keywords calibration
#' @encoding UTF8
NULL