% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/hmi_imp_cat_single_2016-12-23.R
\name{imp_cat_single}
\alias{imp_cat_single}
\title{The function to impute categorical variables}
\usage{
imp_cat_single(y_imp_multi, X_imp_multi)
}
\arguments{
\item{y_imp_multi}{A Vector with the variable to impute.}

\item{X_imp_multi}{A data.frame with the fixed effects variables.}
}
\value{
A n x 1 data.frame
}
\description{
The function uses regression trees for imputation implemented in \code{mice}.
The principle is the following:
For each observation it is calculated at wich leave it would end.
Then one (randomly selected) observation of the other observations found on this leave,
functions as a donor.
}

