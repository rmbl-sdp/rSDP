#' Download SDP Datasets Locally
#'
#' @param urls character vector of URLs for files to download
#' @param output_dir character vector of destination file paths or single path for output files.
#' @param return_status logical. Should the function return a data frame with results from the download session?
#' @param resume logical. Should the function resume partial downloads?
#' @param overwrite logical. Should the function overwrite existing files?
#' @param ... arguments passed to `curl::multi_download()`
#'
#' @export
#'
#'
download_data <- function(urls,output_dir, return_status=TRUE, resume=FALSE, overwrite=FALSE, ...) {
  dest_files <- paste0(file.path(normalizePath(output_dir)),"/",basename(urls))
  ##Checks to see if files exist.
  files_exist <- file.exists(dest_files)
  files_big <- file.size(dest_files) > 1000
  files_legit <- files_exist & files_big
  if(all(files_legit) & overwrite==FALSE){
    message("All files exist locally. Specify `overwrite=TRUE` to overwrite existing files.")
    if(return_status==TRUE){
      return(data.frame(path=dest_files,exists="exists",success=TRUE))
    }else{
      stop()
    }
  }else if(all(files_legit) & overwrite==TRUE){
    warning("Downloads overwriting all existing files. Specify `overwrite=FALSE` to skip existing files.")
    dl_results <- curl::multi_download(urls=urls,destfiles=dest_files,
                                       resume=resume, ...)
  }else if(sum(files_legit) > 0 & overwrite==TRUE){
    message(paste("Downloads overwriting",sum(files_legit),"existing files. Specify `overwrite=FALSE` to skip existing files."))
    dl_results <- curl::multi_download(urls=urls,destfiles=dest_files,
                                       resume=resume, ...)
  }else if(sum(files_legit) > 0 & overwrite==FALSE){
    message(paste("Skipping download for",sum(files_legit),"existing files. Specify `overwrite=TRUE` to overwrite existing files."))
    dl_results <- curl::multi_download(urls=urls[!files_legit],destfiles=dest_files[!files_legit],
                                       resume=resume, ...)
  }else{
    dl_results <- curl::multi_download(urls=urls,destfiles=dest_files,
                                       resume=resume, ...)
  }
  if(all(dl_results$success == TRUE & dl_results$status_code %in% c(200,206))){
    message(paste("Successfully downloaded",nrow(dl_results),"files."))
    if(return_status==TRUE){
      return(dl_results)
    }
  }else{
    warning("Not all files downloaded successfully")
    if(return_status==TRUE){
      return(dl_results)
    }
  }
}
