% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/hmi_wrapper_2017-01-05.R
\name{hmi}
\alias{hmi}
\title{hmi: Hierarchical Multilevel Imputation.}
\usage{
hmi(data, model_formula = NULL, M = 10, maxit = 5, nitt = 3000,
  thin = 100, burnin = 1000)
}
\arguments{
\item{data}{A \code{data.frame} with all variables appearing in \code{model_formula}.}

\item{model_formula}{A \code{\link[stats]{formula}} used for the analysis model.
Currently the package is designed to handle formula used in
\code{lm}, \code{glm} and \code{lmer}.}

\item{M}{An integer defining the number of imputations that should be made.}

\item{maxit}{An integer defining the number of times the imputation cycle
(imputing \eqn{x_1|x_{-1} then x_2|x_{-2}, ... x_p|x_{-p}}) shall be repeated.
The task of checking convergence is left to the user, by evaluating the chainMean and chainVar!}

\item{nitt}{An integer defining number of MCMC iterations (see \code{MCMCglmm}).}

\item{thin}{An integer defining the thinning interval (see \code{MCMCglmm}).}

\item{burnin}{An integer defining the percentage of draws from the gibbs sampler
that should be discarded as burn in (see \code{MCMCglmm}).}
}
\value{
The function returns a \code{mids} object. See \code{mice} for further information.
}
\description{
The user has to pass his data to the function.
Optionally he passes his analysis model formula so that \code{hmi} runs the imputation model
in line with his analysis model formula.\cr
And of course he can specify some parameters for the imputation routine
(like the number of imputations and iterations) including Gibbs-sampler parameters
(number of iterations, burnin and thinning.\cr
}
\examples{
my.formula <- Reaction ~ Days + (1 + Days|Subject)
my_analysis <- function(complete_data){
 # In this list, you can write all the parameters you are interested in.
 # Those will be averaged.
 # So make sure that averaging makes sense and that you only put in single numeric values.
 parameters_of_interest <- list()

 # ---- write in the following lines, what you are interetest in to do with your complete_data
 # the following lines are an example where the analyst is interested in the fixed intercept
 # and fixed slope and the random intercepts variance,
 # the random slopes variance and their covariance
 my_model <- lmer(my.formula, data = complete_data)

 parameters_of_interest[[1]] <- fixef(my_model)[1]
 parameters_of_interest[[2]] <- fixef(my_model)[2]
 parameters_of_interest[[3]] <- VarCorr(my_model)[[1]][1, 1]
 parameters_of_interest[[4]] <- VarCorr(my_model)[[1]][1, 2]
 parameters_of_interest[[5]] <- VarCorr(my_model)[[1]][2, 2]
 names(parameters_of_interest) <- c("beta_intercept", "beta_Days", "sigma0", "sigma01", "sigma1")

 # ---- do change this function below this line.
 return(parameters_of_interest)
}
require("lme4")
require("mice")
data(sleepstudy, package = "lme4")
test <- sleepstudy
test$Intercept <- 1
test[sample(1:nrow(test), size = 20), "Reaction"] <- NA
hmi_imp <- hmi(data = test, model_formula = my.formula)
hmi_pool(mids = hmi_imp, analysis_function = my_analysis)
#if you are interested in fixed effects only, consider pool from mice:
pool(with(data = hmi_imp, expr = lmer(Reaction ~ Days + (1 + Days | Subject))))
}

