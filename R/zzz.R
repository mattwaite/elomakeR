#' @importFrom rlang .data
NULL

.onLoad <- function(libname, pkgname) {
  register_s3_autoplot()
}

register_s3_autoplot <- function() {
  register <- function(...) {
    registerS3method("autoplot", "elo_tbl", elo_autoplot_impl, envir = asNamespace("ggplot2"))
  }
  setHook(packageEvent("ggplot2", "onLoad"), register)
  if (isNamespaceLoaded("ggplot2")) register()
}
