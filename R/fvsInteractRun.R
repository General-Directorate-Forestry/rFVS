#' @title FVS Interact Run
#' @description This function is used to provide for functional interaction 
#'   between R and FVS. Most of the arguments (all those listed in the table 
#'   below), when specified, refer to names of stop points; each provides R 
#'   code that is run when the stop point is reached. One additional optional 
#'   argument may be added that that is trace=[TRUE|FALSE]. When `trace=TRUE` 
#'   is specified, informative messages are output during the function call. 
#'   Setting `trace = FALSE` has the same effect as not specifying it at all.
#'   
#'   `BeforeEM1`: R code to run at the stop point just before the first call to 
#'     the Event Monitor
#'   `AfterEM1`: R code to run at the stop point just after the first call to 
#'     the Event Monitor
#'   `BeforeEM2`: R code to run at the stop point just before the second call 
#'     to the Event Monitor
#'   `AfterEM2`: R code to run at the stop point just after the second call to 
#'     the Event Monitor
#'   `BeforeAdd`: R code to run at the stop point after growth and mortality has 
#'     been computed, but prior to applying them
#'   `BeforeEstab`: R code to run at the stop point just before the Regeneration 
#'     Establishment Model is called
#'   `SimEnd`: R code to run at the stop point at the end of one stand's 
#'     simulaton and prior to the beginning of the next
#'  
#'  The value of arguments can be either:
#'    1) a quoted character string containing a valid R expression (more than 
#'       one can be specified if separated by semicolons (;) or 
#'    2) an R function with no arguments. The expression is evaluated (or the 
#'       function is called) when the corresponding stop point is reached. Note 
#'       that using fvsInteractRun() without arguments is functionally 
#'       equivalent to using fvsRun() without arguments.
#'
#' @param ... named arguments selected from the above list.
#'
#' @return A named list where the names are automatically generated using the 
#'   `standid`, `mgmtid`, and `year.` In the case where the return value 
#'   corresponds to the end of the simulation, the string SimEnd is used in 
#'   place of year.
#'   
#'   The objects in this returned list are also a named lists. Each contains 
#'   the values of the expressions (or functions) when they are computed. The 
#'   values are named using the argument names.
#' @export

fvsInteractRun <- function(...) {
  args <- list(...)

  # set up trace
  tm <- match("trace", names(args))
  trace <- as.logical(
    if (is.na(tm)) {
      FALSE
    } else {
      tr <- args[tm]
      args <- args[-tm]
      tr
    }
  )

  argnames <- names(args)
  needed <- c(
    "BeforeEM1", "AfterEM1", "BeforeEM2", "AfterEM2",
    "BeforeAdd", "BeforeEstab", "SimEnd"
  )
  toCall <- vector("list", length(needed))
  names(toCall) <- needed
  toCall[needed] <- args[needed]
  ignored <- setdiff(names(args), needed)
  if (length(ignored) > 0) {
    warning(
      "argument(s) ignored: ",
      paste(ignored, collapse = ", ")
    )
  }
  if (trace) {
    for (name in needed) {
      cat(
        "arg=", name, "value=",
        if (is.null(toCall[[name]])) {
          "NULL"
        } else if (
          class(toCall[[name]]) == "function") {
          "function"
        } else {
          toCall[[name]]
        }, "\n"
      )
    }
  }
  ntoc <- length(needed)
  allCases <- list()
  oneCase <- NULL
  setNextStopPoint <- function(toCall, currStopPoint) {
    pts <- (currStopPoint + 1):(ntoc - 1) # set up a circlular sequence
    if (length(pts) < ntoc) {
      pts <- c(pts, 1:(ntoc - length(pts) - 1))
    }
    for (i in pts) {
      if (i == 0) next
      if (!is.null(toCall[[i]])) { # args are: spptcd,spptyr
        .Fortran("fvsSetStoppointCodes", as.integer(i), as.integer(-1))
        break
      }
    }
  }
  setNextStopPoint(toCall, 0)

  repeat  {
    # run fvs, capture the return code
    if (trace) {
      cat("calling fvs\n")
    }
    rtn <- .Fortran("fvs", as.integer(0))[[1]]
    if (trace) {
      cat("rtn=", rtn, "\n")
    }
    if (rtn != 0) break # this will signal completion.

    # if the current stop point is < zero, then the last call
    # is a reload from a stoppoint file.
    stopPoint <- .Fortran("fvsGetRestartCode", as.integer(0))[[1]]
    if (stopPoint < 0) {
      stopPoint <- -stopPoint
      setNextStopPoint(toCall, stopPoint)
    }
    if (trace) {
      yr <- fvsGetEventMonitorVariables("year")
      ids <- fvsGetStandIDs()
      cat("called fvs, stopPoint=", stopPoint, " yr=", yr, " ids=", ids, "\n")
    }

    if (stopPoint == 100) {
      if (!is.null(toCall[["SimEnd"]])) {
        ans <- if (is.function(toCall[["SimEnd"]])) {
          toCall[["SimEnd"]]()
        } else {
          eval(parse(text = toCall[["SimEnd"]]))
        }
        if (!is.null(ans)) {
          onePtr <- length(allCases) + 1
          allCases[[onePtr]] <- ans
          ids <- fvsGetStandIDs()
          caseID <- paste(ids[1], ids[3], "SimEnd", sep = ":")
          names(allCases)[onePtr] <- caseID
        }
      }
      setNextStopPoint(toCall, 0)
    }
    else {
      if (!is.null(toCall[[stopPoint]])) {
        ans <- if (is.function(toCall[[stopPoint]])) {
          toCall[[stopPoint]]()
        } else {
          eval(parse(text = toCall[[stopPoint]]))
        }
        if (!is.null(ans)) {
          if (is.null(oneCase)) oneCase <- list()
          onePtr <- length(oneCase) + 1
          oneCase[[onePtr]] <- ans
          names(oneCase)[onePtr] <- names(toCall)[stopPoint]
        }
      }
      setNextStopPoint(toCall, if (stopPoint == ntoc - 1) 0 else stopPoint)
    }
    if (!is.null(oneCase)) {
      yr <- fvsGetEventMonitorVariables("year")
      ids <- fvsGetStandIDs()
      caseID <- paste(ids[1], ids[3], as.character(yr), sep = ":")
      onePtr <- length(allCases) + 1
      allCases[[onePtr]] <- oneCase
      names(allCases)[onePtr] <- caseID
    }
    oneCase <- NULL
  }
  allCases
}
