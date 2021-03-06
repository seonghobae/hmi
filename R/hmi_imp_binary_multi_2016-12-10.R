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
# Mit devtools::document() auch eine .RD Datei erstellt.

#' The function for hierarchical imputation of binary variables.
#'
#' The function is called by the wrapper.
#' @param y_imp_multi A Vector with the variable to impute.
#' @param X_imp_multi A data.frame with the fixed effects variables.
#' @param Z_imp_multi A data.frame with the random effects variables.
#' @param clID A vector with the cluster ID.
#' @param model_formula A \code{\link[stats]{formula}} used for the analysis model.
#' @param M An integer defining the number of imputations that should be made.
#' @param nitt An integer defining number of MCMC iterations (see MCMCglmm).
#' @param thin An integer defining the thinning interval (see MCMCglmm).
#' @param burnin An integer defining the percentage of draws from the gibbs sampler
#' that should be discarded as burn in (see MCMCglmm).
#' @return A n x M matrix. Each column is one of M imputed y-variables.
imp_binary_multi <- function(y_imp_multi,
                      X_imp_multi,
                      Z_imp_multi,
                      clID,
                      model_formula,
                      M = 10,
                      nitt = 3000,
                      thin = 10,
                      burnin = 1000){

  # -----------------------------preparing the data ------------------
  # -- standardise the covariates in X (which are numeric and no intercept)

  X_imp_multi_stand <- X_imp_multi

  n <- nrow(X_imp_multi_stand)
  blob <- sample(0:1, size = n, replace = TRUE)
  tmp_0 <- data.frame(y_binary = blob, X_imp_multi_stand)

  X_model_matrix_1 <- stats::model.matrix(y_binary ~ 0 + ., data = tmp_0)
  # Remove ` from the variable names
  colnames(X_model_matrix_1) <- gsub("`", "", colnames(X_model_matrix_1))


  # -- standardise the covariates in Z (which are numeric and no intercept)

  Z_imp_multi_stand <- Z_imp_multi


  # If the user wants a fixed intercept, the wrapper function assures that X_imp_multi
  # includes such a variable

  # Get the number of random effects variables
  n.par.rand <- ncol(Z_imp_multi_stand)
  length.alpha <- length(table(clID)) * n.par.rand


  # -------------- calling the gibbs sampler to get imputation parameters----

  tmp_1 <- data.frame(target = blob)
  xnames_1 <- paste("X", 1:ncol(X_model_matrix_1), sep = "")
  znames_1 <- paste("Z", 1:ncol(Z_imp_multi_stand), sep = "")
  tmp_1[, xnames_1] <- X_model_matrix_1
  tmp_1[, znames_1] <- Z_imp_multi_stand
  tmp_1[, "ClID"] <- clID

  fixformula_1 <- stats::formula(paste("target~", paste(xnames_1, collapse = "+"), "- 1", sep = ""))
  randformula_1 <- stats::as.formula(paste("~us(", paste(znames_1, collapse = "+"), "):ClID", sep = ""))

  lmer_fixpart_1 <- paste("target~ 0 + ", paste(xnames_1, collapse = "+"), sep = "")

  reg_1 <- stats::glm(stats::formula(lmer_fixpart_1), data = tmp_1,
                      family = stats::binomial(link = "logit"))

  #remove linear dependent variables

  tmp_2 <- data.frame(target = blob)

  xnames_2 <- xnames_1[!is.na(stats::coefficients(reg_1))]
  znames_2 <- znames_1

  tmp_2[, xnames_2] <- X_model_matrix_1[, !is.na(stats::coefficients(reg_1)), drop = FALSE]
  tmp_2[, znames_2] <- Z_imp_multi_stand
  tmp_2[, "ClID"] <- clID

  lmfixformula_2 <- stats::formula(paste("target ~ 0 +", paste(xnames_2, collapse = "+"), sep = ""))
  reg_2 <- stats::glm(lmfixformula_2, data = tmp_2, family = stats::binomial(link = "logit"))
  X_model_matrix_2 <- stats::model.matrix(reg_2)

  fixformula_2 <- stats::formula(paste("target~", paste(xnames_2, collapse = "+"), "- 1", sep = ""))
  randformula_2 <- stats::as.formula(paste("~us(0+", paste(znames_2, collapse = "+"), "):ClID", sep = ""))

  #Fix residual variance R at 1
  # cf. http://stats.stackexchange.com/questions/32994/what-are-r-structure-g-structure-in-a-glmm
  prior <- list(R = list(V = 1, fix = 1),
                G = list(G1 = list(V = diag(n.par.rand), nu = 0.002)))

  MCMCglmm_draws <- MCMCglmm::MCMCglmm(fixed = fixformula_2,
                                       random = randformula_2,
                                       data = tmp_2,
                                       family = "categorical",
                                       verbose = FALSE, pr = TRUE, prior = prior,
                                       saveX = TRUE, saveZ = TRUE,
                                       nitt = nitt,
                                       thin = thin,
                                       burnin = burnin)

  # correction. see:
  # http://stats.stackexchange.com/questions/32994/what-are-r-structure-g-structure-in-a-glmm
  k <- ((16*sqrt(3))/(15*pi))^2

  pointdraws <- MCMCglmm_draws$Sol /sqrt(1 + k)
  xdraws <- pointdraws[, 1:ncol(X_model_matrix_2), drop = FALSE]
  zdraws <- pointdraws[, ncol(X_model_matrix_2) + 1:length.alpha, drop = FALSE]
  variancedraws <- MCMCglmm_draws$VCV

  number_of_draws <- nrow(pointdraws)
  select_record <- sample(1:number_of_draws, M, replace = TRUE)

  # -------------------- drawing samples with the parameters from the gibbs sampler --------


  linkfunction <- function(x){
    ret <- boot::inv.logit(x)
    return(ret)
  }

  y_imp <- array(NA, dim = c(n, M))

  ###start imputation
  for (j in 1:M){

    rand_eff_imp <- matrix(zdraws[select_record[j],],
                           ncol = n.par.rand)


    fix_eff_imp <- matrix(xdraws[select_record[j], ], nrow = ncol(X_model_matrix_2))

    sigma_y_imp <- sqrt(variancedraws[select_record[j], ncol(variancedraws)])

    linearpredictor <- stats::rnorm(n, X_model_matrix_2 %*% fix_eff_imp +
                      apply(Z_imp_multi_stand * rand_eff_imp[clID,], 1, sum), 0*sigma_y_imp)


    one_prob <- linkfunction(linearpredictor)


    y_temp <- as.numeric(stats::runif(n) < one_prob)

    y_imp[, j] <- ifelse(is.na(y_imp_multi), y_temp, y_imp_multi)
  }

  # --------- returning the imputed data --------------
  return(y_imp)
}
