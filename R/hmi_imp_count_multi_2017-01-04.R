# You can learn more about package authoring with RStudio at:
#
#   http://r-pkgs.had.co.nz/
#
# Some useful keyboard shortcuts for package authoring:
#
#   Build and Reload Package:  'Ctrl + Shift + B'
#   Check Package:             'Ctrl + Shift + E'
#   Test Package:              'Ctrl + Shift + T'
#
# MS: All other shortcuts are shown when pressing 'Alt + Shift + K'
# MS: Hinweis: es wird zu jeder R-Datei im Projekordner\R, die eine Documentation hat,
#Mit devtools::document() auch eine .RD Datei erstellt.


#' The function for hierarchical imputation of variables with count data.
#'
#' The function is called by the wrapper.
#' @param y_imp_multi A Vector with the variable to impute.
#' @param X_imp_multi A data.frame with the fixed effects variables.
#' @param Z_imp_multi A data.frame with the random effects variables.
#' @param clID A vector with the cluster ID.
#' @param M An integer defining the number of imputations that should be made.
#' @param nitt An integer defining number of MCMC iterations (see MCMCglmm).
#' @param thin An integer defining the thinning interval (see MCMCglmm).
#' @param burnin An integer defining the percentage of draws from the gibbs sampler
#' that should be discarded as burn in (see MCMCglmm).
#' @return A n x M matrix. Each column is one of M imputed y-variables.
imp_count_multi <- function(y_imp_multi,
                      X_imp_multi,
                      Z_imp_multi,
                      clID,
                      M = 10,
                      nitt = 3000,
                      thin = 10,
                      burnin = 1000){


  # -----------------------------preparing the data ------------------
  # -- standardise the covariates in X (which are numeric and no intercept)
  need_stand_X <- apply(X_imp_multi, 2, get_type) %in% c("cont", "count")
  X_imp_multi_stand <- X_imp_multi
  X_imp_multi_stand[, need_stand_X] <- scale(X_imp_multi[, need_stand_X])

  #generate model.matrix (from the class matrix)
  n <- nrow(X_imp_multi_stand)
  #X_model_matrix <- stats::model.matrix(stats::rnorm(n) ~ 0 + ., data = X_imp_multi_stand)
  # Remove ` from the variable names
  #colnames(X_model_matrix) <- gsub("`", "", colnames(X_model_matrix))

  # -- standardise the covariates in Z (which are numeric and no intercept)
  need_stand_Z <- apply(Z_imp_multi, 2, get_type) %in% c("cont", "count")
  Z_imp_multi_stand <- Z_imp_multi
  Z_imp_multi_stand[, need_stand_Z] <- scale(Z_imp_multi[, need_stand_Z])

  # Get the number of random effects variables
  n.par.rand <- ncol(Z_imp_multi_stand)
  length.alpha <- length(table(clID)) * n.par.rand


  # -------------- calling the gibbs sampler to get imputation parameters----


  n <- length(y_imp_multi)
  lmstart <- stats::lm(stats::rnorm(n) ~ 0 +., data = X_imp_multi_stand)

  X_model_matrix_1 <- stats::model.matrix(lmstart)
  xnames_1 <- paste("X", 1:ncol(X_model_matrix_1), sep = "")
  znames <- paste("Z", 1:ncol(Z_imp_multi_stand), sep = "")

  tmp_1 <- data.frame(y = stats::rnorm(n))
  tmp_1[, xnames_1] <- X_model_matrix_1

  reg_1 <- stats::lm(y ~ 0 + . , data = tmp_1)

  blob <- y_imp_multi
  tmp_2 <- data.frame(target = blob)

  xnames_2 <- xnames_1[!is.na(stats::coefficients(reg_1))]
  X_model_matrix_2 <- X_model_matrix_1[, !is.na(stats::coefficients(reg_1)), drop = FALSE]
  tmp_2[, xnames_2] <- X_model_matrix_2
  tmp_2[, znames] <- Z_imp_multi_stand
  tmp_2[, "ClID"] <- clID

  fixformula <- stats::formula(paste("target~", paste(xnames_2, collapse = "+"), "- 1", sep = ""))
  randformula <- stats::as.formula(paste("~us(", paste(znames, collapse = "+"), "):ClID", sep = ""))


  prior <- list(R = list(V = 1e-07, nu = -2),
                G = list(G1 = list(V = diag(ncol(Z_imp_multi_stand)), nu = 0.002)))


  MCMCglmm_draws <- MCMCglmm::MCMCglmm(fixformula, random = randformula, data = tmp_2,
                                       verbose = FALSE, pr = TRUE, prior = prior,
                                       family = "poisson",
                                       saveX = TRUE, saveZ = TRUE,
                                       nitt = 3000,
                                       thin = 10,
                                       burnin = 1000)


  pointdraws <- MCMCglmm_draws$Sol
  xdraws <- pointdraws[, 1:ncol(X_model_matrix_2), drop = FALSE]
  zdraws <- pointdraws[, ncol(X_model_matrix_2) + 1:length.alpha, drop = FALSE]
  variancedraws <- MCMCglmm_draws$VCV
  # the last column contains the variance (not standard deviation) of the residuals

  number_of_draws <- nrow(pointdraws)
  select.record <- sample(1:number_of_draws, M, replace = TRUE)

  # -------------------- drawing samples with the parameters from the gibbs sampler --------
  y_imp <- array(NA, dim = c(n, M))
  ###start imputation
  for (j in 1:M){

    rand.eff.imp <- matrix(zdraws[select.record[j],],
                           ncol = n.par.rand)

    fix.eff.imp <- matrix(xdraws[select.record[j], ], nrow = ncol(X_model_matrix_2))

    sigma.y.imp <- sqrt(variancedraws[select.record[j], ncol(variancedraws)])

    lambda <- exp(stats::rnorm(n, X_model_matrix_2 %*% fix.eff.imp +
                      apply(Z_imp_multi_stand * rand.eff.imp[clID,], 1, sum), sigma.y.imp))

    y_imp[, j] <- ifelse(is.na(y_imp_multi), stats::rpois(n, lambda), y_imp_multi)
  }

  # --------- returning the imputed data --------------
  return(y_imp)

}


# Generate documentation with devtools::document()
# Build package with devtools::build() and devtools::build(binary = TRUE) for zips
