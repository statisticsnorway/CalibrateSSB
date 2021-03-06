#   wregw i impvekt bør endres ...bereging av "*" mellom matrise og vektor
#   Kan se ut til at det blir riktig p.g.a beregningsrekkefølge, men det bør endres ....
#



#' Calibration weighting and estimation
#' 
#' Compute weights by calibration and corresponding estimates, totals and
#' residuals
#' 
#' When popTotals as input is NULL, population totals are computed from popData
#' (when available) or from grossSample. Some elements of popTotals may be
#' missing (not allowed when using ReGenesees). When using "ReGenesees", both
#' weiging and estimation are done by that package. When using "survey", only
#' calibration weiging are done by that package.
#' The parameters \code{wave}, \code{id} and \code{extra} have no effect on the 
#' computations, but result in extra elements in output 
#' (to be used by WideFromCalibrate() later).  
#' 
#' 
#' @encoding UTF8
#' 
#' @param grossSample Data frame.
#' @param calmodel Formula defining the linear structure of the calibration
#' model.
#' @param response Variable name of response indicator (net sample when 1).
#' @param popTotals Population totals (similar to population totals as output).
#' @param y Names of variables of interest. Can be a list similar to "by"
#' below.
#' @param by Names of the variables that define the "estimation domains". If
#' NULL (the default option) or NA estimates refer to the whole population. Use
#' list for multiple specifications (resulting in list as output).
#' @param partition Names of the variables that define the "calibration
#' domains" for the model. NULL (the default) implies no calibration domains.
#' @param lRegmodel Formula defining the linear structure of a logistic
#' regression model.
#' @param popData Data frame of population data.
#' @param samplingWeights Name of the variable with initial weights for the
#' sampling units.
#' @param usePackage Specifying the package to be used: "survey" (the default),
#' "ReGenesees" or "none".
#' @param bounds Bounds for the calibration weights. When ReGenesees: Allowed
#' range for the ratios between calibrated and initial weights. The default is
#' c(-Inf,Inf).
#' @param calfun The distance function for the calibration process; the default
#' is 'linear'.
#' @param onlyTotals When TRUE: Only population totals are returned.
#' @param onlyw When TRUE: Only the calibrated weights are returned.
#' @param uselRegWeights When TRUE: Weighted logistic regression is performed
#' as a first calibration step.
#' @param ids Name of sampling unit identifier variable.
#' @param residOutput Residuals in output when TRUE. FALSE is default.
#' @param leverageOutput Leverages in output when TRUE. FALSE is default.
#' @param yOutput y in output when TRUE. FALSE is default.
#' @param samplingWeightsOutput samplingWeights in output when TRUE. FALSE is
#' default.
#' @param dropResid2 When TRUE (default) and when no missing population totals
#' - only one set of residuals in output.
#' @param wGrossOutput wGross in output when TRUE (default) and when NA
#' popTotals.
#' @param wave Time or another repeat variable (to be included in output).
#' @param id Identifier variable (to be included in output).
#' @param extra Variables for the extra dataset (to be included in output).
#' @param allowNApopTotals When TRUE missing population totals are allowed.
#' Results in error when FALSE and warning when NULL.
#' @param partitionPrint When TRUE partition progress is printed. 
#' Automatic decision when NULL (about 1 min total computing time).  
#' 
#' @param ... Further arguments sent to underlying functions.
#' @return Unless onlyTotals or onlyw is TRUE, the output is an object of class calSSB. That is, a list with 
#' elements: \item{popTotals}{Population totals.} \item{w}{The calibrated
#' weights.} \item{wGross}{Calibrated gross sample weights when NA popTotals.}
#' \item{estTM}{Estimates (with standard error).} \item{resids}{Residuals,
#' reduced model when NA popTotals.} \item{resids2}{Residuals, full model.}
#' \item{leverages}{Diagonal elements of hat-matrix, reduced model when NA
#' popTotals.} \item{leverages2}{Diagonal elements of hat-matrix, full model.}
#' \item{y}{as input} \item{samplingWeights}{as input}
#' \item{wave}{as input or via CrossStrata}
#' \item{id}{as input}
#' \item{extra}{as input}
#' 
#' @export
#' @importFrom methods formalArgs
#' @importFrom stats aggregate as.formula binomial glm lm lm.influence model.frame model.matrix predict resid update weights
#' @importFrom utils head tail capture.output
#' @importFrom survey svydesign calibrate
#' 
#' @seealso \code{\link{CalSSBobj}}, \code{\link{WideFromCalibrate}},  \code{\link{PanelEstimation}}, \code{\link{CalibrateSSBpanel}}.
#' 
#' @examples
#' 
#' # Generates data  - two years
#' z    <- AkuData(3000)  # 3000 in each quarter
#' zPop <- AkuData(10000)[,1:7]
#' 
#' # Calibration using "survey"
#' a <- CalibrateSSB(z, calmodel = "~ sex*age",
#'                  partition = c("year","q"),  # calibrate within quarter
#'                  popData = zPop, y = c("unemployed","workforce"),
#'                  by = c("year","q")) # Estimate within quarter
#' head(a$w) # calibrated weights
#' a$estTM   # estimates
#' a$popTotals   # popTotals used as input below
#' 
#' 
#' # Calibration, no package, popTotals as input
#' b <- CalibrateSSB(z, popTotals=a$popTotals, calmodel="~ sex*age",
#'       partition = c("year","q"), usePackage = "none", y = c("unemployed","workforce"))
#' max(abs(a$w-b$w)) # Same weights as above
#' 
#' print(a)
#' print(b)
#' 
#' \dontrun{
#' require(ReGenesees)
#' # Calibration and estimation via ReGenesees
#' CalibrateSSB(z, calmodel = "~ sex*age",
#'              partition = c("year","q"),  # calibrate within quarter
#'              popData = zPop, usePackage = "ReGenesees",
#'              y = c("unemployed","workforce"),
#'              by = c("year","q")) # Estimate within quarter
#' }
#' 
CalibrateSSB = function(grossSample,calmodel=NULL,response="R",popTotals=NULL,y=NULL,by = NULL,partition=NULL,lRegmodel=NULL,
                        popData=NULL,samplingWeights=NULL,
                        usePackage="survey",bounds=c(-Inf,Inf),calfun="linear",
                        onlyTotals=FALSE,onlyw=FALSE,uselRegWeights=FALSE,ids=NULL,
                        residOutput = TRUE,
                        leverageOutput = FALSE,
                        yOutput = TRUE,
                        samplingWeightsOutput = FALSE,
                        dropResid2 = TRUE,
                        wGrossOutput = TRUE,
                        wave=NULL,
                        id=NULL,
                        extra=NULL,
                        allowNApopTotals = NULL,
                        partitionPrint = NULL,
                        ...){
  #if(hasArg("residOutput"))
  #  warning("residOutput is an old argument not in use")
  timeLimit = 60
  if(!is.null(allowNApopTotals)){
    checkAnyNApopTotals = !allowNApopTotals
  } else{
    checkAnyNApopTotals = TRUE
  }
    
  if(leverageOutput) residOutput = TRUE
  if(is.null(y)) residOutput = FALSE
  if(residOutput & is.list(y)) stop("residOutput & is.list(y) NOT IMPLEMENTED")
  if(yOutput & is.list(y)) stop("yOutput & is.list(y) NOT IMPLEMENTED")

  n = NROW(grossSample)
  R = grossSample[,response]

  if(is.null(samplingWeights)){
    samplingWeights = "Wei5652503017"
    grossSample[,samplingWeights] = 1
    samplingW = NULL
  } else samplingW = grossSample[[samplingWeights]]

  if(is.null(popData)){
    popData = grossSample
    wPop = samplingW
  } else wPop=NULL  # Avoid copy?


  ######## START ReGenesees
  if(tolower(usePackage)=="regenesees"){
    if(!is.null(lRegmodel))
      stop("lRegmodel when ReGenesees NOT IMPLEMENTED")
    #if(residOutput)
    #  stop("residOutput when ReGenesees NOT IMPLEMENTED")
    #if(yOutput)
    #  stop("yOutput when ReGenesees NOT IMPLEMENTED")
    #if(samplingWeightsOutput)
    #  stop("samplingWeightsOutput when ReGenesees NOT IMPLEMENTED")
    if(is.null(ids)){
      ids = "ids5652503017"
      grossSample[,ids] = 1:n
    }

    retur =CalibratePackageReGenesees(netSample=grossSample[R==1,],calmodel=calmodel,popTotals=popTotals,y=y,
                                          by=by,partition=partition,
                                          popData=popData,samplingWeights=samplingWeights,bounds=bounds,calfun=calfun,
                                          onlyTotals=onlyTotals,ids=ids,...)
    w = retur$w
    retur$w = rep(0,n)
    retur$w[R==1] = w
    if(onlyw) return(retur$w)
    resids = retur$resids
    retur$resids = matrix(NaN,n,dim(resids)[2])
    retur$resids[R==1,] = resids
    #return(retur)
    if(yOutput) retur$y = grossSample[,y,drop=FALSE]
    if(samplingWeightsOutput) retur$samplingWeights = samplingWeights
    
    #if(!residOutput | !yOutput)
    #  return(retur)
    #return(structure(retur, class = "calSSB", n=n, nY=length(y)))
  }######## END ReGenesees
  else {


  bigStrataLevels=NULL
  createPopTotals = is.null(popTotals)
  partitionPop =FALSE
  bigStrataPop = rep(1,NROW(popData))

  if(!is.null(partition))  {
    partitionPop = sum(partition %in% names(popData))>0

    if(partitionPop & createPopTotals){
      cs = CrossStrata(grossSample[,partition],returnb=TRUE,asNumeric=TRUE,byExtra=popData[,partition])
      bigStrataPop = cs$aExtra
    } else {
      cs = CrossStrata(grossSample[,partition],returnb=TRUE,asNumeric=TRUE)
    }

    bigStrata       = cs$a
    bigStrataLevels = cs$b
    if(length(bigStrataLevels)==1) names(bigStrataLevels) = partition # Hindre at navnet blir "by"
  }
  else bigStrata = rep(1,n)

  nBig    = max(bigStrata)

  calModel=NULL
  lRegModel=NULL
  if(!is.null(calmodel))   calModel = update(as.formula(calmodel),paste(response,"~."))
  if(!is.null(lRegmodel)) lRegModel = update(as.formula(lRegmodel),paste(response,"~."))



  if(!createPopTotals){
    if(is.vector(popTotals)) popTotals = matrix(popTotals,nrow = 1,dimnames=list(" ",names(popTotals)))
    popTotalsInput = popTotals
    if(nBig>1 & NROW(popTotals)>1) popTotalsInput = mergeSort(popTotals,bigStrataLevels,remov=TRUE)
    popTotalsInput = as.matrix(popTotalsInput)
    popTotals=NULL
  }

  w = rep(NaN,n)
  if(wGrossOutput)   wGross = rep(NaN,n)

  if(residOutput){
    e1 = NaN+grossSample[,y,drop=FALSE]
    e2=e1
    etos = etos_e1_e2
    if(leverageOutput){
      h1=e1[,1]
      h2=h1
      etos = etos_e1_e2_by_lm
    }
  }
  
  if(is.null(partitionPrint))
    pPrint = TRUE
  else
    pPrint = partitionPrint
  
  if(nBig<=1)
    pPrint = FALSE
  
  if(pPrint)
    printi = capture.output(print(bigStrataLevels,row.names=FALSE))

  
  for(i in 1:nBig)
  {
    if(i==1 & pPrint){
      if(is.null(partitionPrint)){
        timeStart = Sys.time()
      } else {
        cat(printi[1],"\n")
      }
    }
    rows    = bigStrata  ==i
    lm_model = lm(c(calModel,as.formula(paste(response,"~1")))[[1]],data=grossSample[rows,])   # ~1 when calModel=NULL

    if(createPopTotals)
    {
      if(partitionPop|i==1)
      {
        rowsPop = bigStrataPop==i
        if(is.null(wPop)) wPopi = NULL
          else wPopi = wPop[rowsPop]
        tp = getTotal(popData[rowsPop,,drop=FALSE],lm_model,wPopi)
        popTotals_ =  tp$N*tp$colSum/tp$colN
      } else
        popTotals_ = NULL
    }
    else
    {
      popTotals_=setTotal(popTotalsInput[min(i,dim(popTotalsInput)[1]),,drop=TRUE],lm_model)
    }

    popTotals = rbind(popTotals,popTotals_)


    if(checkAnyNApopTotals){
      if(anyNA(popTotals[dim(popTotals)[1],])){
        if(!is.null(allowNApopTotals))
          stop("Missing population totals not allowed according to parameter allowNApopTotals.")
        else
          warning("Special methodology since missing population totals (warning according to parameter allowNApopTotals)")
        checkAnyNApopTotals = FALSE
      }
    }

    if(!onlyTotals & !(tolower(usePackage)=="nocalibration")){
      a = calibrateSSB(grossSample[rows,],calModel, popTotals[dim(popTotals)[1],],response=NULL,lRegModel,
                              popData=NULL,samplingW[rows],tolower(usePackage)=="survey",bounds=bounds,calfun= calfun, ##### "linear",
                              totalReturn=0,uselRegWeights=uselRegWeights,...)
      w[rows] = a$w
      if(wGrossOutput & !is.null(a$wGross))  wGross[rows] = a$wGross
    }
    if(residOutput){
      xFromModel = model.matrix(lm_model)
      rFromModel = model.frame(lm_model)[1]
      rowsNetto = rows
      rowsNetto[rowsNetto][!rFromModel==1] = FALSE
      e1_e2=etos(xFromModel[rFromModel==1,],
                       data.matrix(grossSample[rowsNetto,y]),
                       is.finite(popTotals[dim(popTotals)[1],]),
                       w=(samplingW[rowsNetto]))
      e1[rowsNetto,]=e1_e2$e1
      e2[rowsNetto,]=e1_e2$e2
      if(leverageOutput){
        h1[rowsNetto]=e1_e2$h1
        h2[rowsNetto]=e1_e2$h2
      }
    }
    
    if(i==1 & pPrint & is.null(partitionPrint)){
      if(difftime(Sys.time(),timeStart,units = "secs")>timeLimit/nBig)
        cat(printi[1],"\n")
      else
        pPrint = FALSE
    }
    if(pPrint)
      cat(printi[1+i],"\n")
    

  }
  if(wGrossOutput) if(sum(is.finite(wGross))==0) wGross = NULL

  rownames(popTotals) =NULL
  popTotals = cbind(bigStrataLevels,popTotals)

  if(onlyTotals) return(popTotals)
  if(onlyw) return(w)


  ############## Almost same as in CalibratePackageReGenesees
  estTM=NULL
  if(!is.null(y)){
    if(is.list(y) | is.list(by)){
      if(is.list(y) & is.list(by)) {if(length(y)!=length(by)) stop("length(y)==length(by) must be TRUE")}
      else{
        if(is.list(y)){
          if(is.null(by))
            by = vector("list",length(y))
          else{
            by_ = by
            by = y
            for(i in 1:length(y)) by[[i]] = by_
          }
        }else{
          y_ = y
          y = by
          for(i in 1:length(y)) y[[i]] = y_
        }

      }
      estTM = y
      for(i in 1:length(y)) estTM[[i]] = MYestTM(grossSample,y[[i]],w,by[[i]])
    } else
    {
      estTM =  MYestTM(grossSample,y,w,by)
    }
  }

  dropResid2 = dropResid2  & (sum(is.na(popTotals))==0)

  retur=list(popTotals=popTotals,w=w)
  if(!is.null(estTM)) retur$estTM = estTM
  if(residOutput) {
    retur$resids=e1
    if(!dropResid2) retur$resids2=e2
    if(leverageOutput){
      retur$leverages=h1
      if(!dropResid2) retur$leverages2=h2
    }
  }
  if(yOutput) retur$y = grossSample[,y,drop=FALSE]
  if(samplingWeightsOutput) retur$samplingWeights = samplingWeights
  if(wGrossOutput) retur$wGross = wGross
  } ######## END NOT ReGenesees
  
  if(!is.null(wave)){
    if(length(wave)>1)
      retur$wave = CrossStrata(grossSample[,wave])
    else
      retur$wave = grossSample[,wave, drop=TRUE]
  }
  if(!is.null(id)) retur$id = grossSample[,id, drop=TRUE]
  if(!is.null(extra)) retur$extra = grossSample[,extra,drop=FALSE]
  if(!residOutput | !yOutput)
    return(retur)
  return(structure(retur, class = "calSSB", n=n, nY=length(y)))
}



# Create new levels by crossing levels in "by"
# When returnb=TRUE an overview of original variabels according to new levels are also retuned
# byExtra contains the same variables as by and represents another data set.


#' Crossing several factor variables
#' 
#' Create new factor variable by crossing levels in several variables
#' 
#' 
#' @param by Dataframe or matrix with several variables
#' @param sep Used to create new level names
#' @param returnb When TRUE an overview of original variabels according to new
#' levels are also retuned.
#' @param asNumeric When TRUE the new variable is numeric.
#' @param byExtra Contains the same variables as by and represents another data
#' set.
#' @return \item{a}{The new variable} \item{aExtra}{New variable according to
#' byExtra} \item{b}{Overview of original variabels according to new levels}
#' @examples
#' 
#' CrossStrata(cbind(factor(rep(1:3,2)),c('A',rep('B',5)) ))
#' 
#' @export CrossStrata
CrossStrata = function(by,sep = "-",returnb=FALSE,asNumeric=FALSE,byExtra=NULL){
  by = as.data.frame(by)
  byList = as.list(by)
  b = sortrows(as.data.frame(aggregate(byList[[1]],byList,length)[,1:length(byList)]))
  rownames(b)=NULL
  names(b) = names(by)
  levels = apply(b,1,paste,collapse=sep)
  a      = factor(apply(by,1,paste,collapse=sep),levels = levels)
  if(asNumeric){
    levels_ = levels(a)
    a=as.numeric(a)
    attr(a,"levels") = levels_
  }
  if(!is.null(byExtra)) {
    aExtra = factor(apply(as.data.frame(byExtra),1,paste,collapse=sep),levels = levels)
    if(asNumeric){
      levels_ = levels(aExtra)
      aExtra=as.numeric(aExtra)
      attr(aExtra,"levels") = levels_
    }
    if(returnb) return(list(a=a,aExtra=aExtra,b=b))
    return(list(a=a,aExtra=aExtra))
  }
  if(returnb) return(list(a=a,b=b))
  a
}




#' Rearrange output from CalibrateSSB (calSSB object). Ready for input to PanelEstimation.
#' 
#' One row for each id and one column for each wave.
#' 
#' When wave, id or extra is NULL, corresponding elements in the input object (\code{a}) will be used if available,
#' 
#' 
#' @param a A calSSB object. That is, output from CalibrateSSB() or CalSSBobj().
#' @param wave Time or another repeat variable.
#' @param id Identifier variable.
#' @param subSet Grouping variable for splitting ouput.
#' @param extra Dataset with extra variables not in \code{a}.
#' @return Output has the same elements (+ extra) as input (a), but rearranged.
#' When subSet is input otput is alist according to the subSet levels.
#' 
#' @export
#' 
#' @seealso \code{\link{CalibrateSSB}}, \code{\link{CalSSBobj}}, \code{\link{PanelEstimation}}.
#' 
#' 
#' @examples
#' 
#' # See examples in PanelEstimation and CalSSBobj
#' 
WideFromCalibrate = function(a,wave=NULL,id=NULL,subSet=NULL,extra=NULL){    # wave instead of bigStrata, extra is list
  if(class(a)[1] != "calSSB")
    stop("a must be an object of class calSSB")
  if(is.null(wave))
    wave = a$wave
  if(is.null(wave))
    stop("wave neeed")
  if(is.null(id))
    id = a$id
  if(is.null(id))
    stop("id neeed")
  x=structure(list(),class = "calSSBwide")
  
  if(!is.null(a$y))          x$y          = wideDataMatrix(a$y,wave,id,asList=TRUE)
  if(!is.null(a$w))          x$w          = wideDataMatrix(a$w,wave,id,asList=FALSE)
  if(!is.null(a$resids))     x$resids     = wideDataMatrix(a$resids,wave,id,asList=TRUE)
  if(!is.null(a$resids2))    x$resids2    = wideDataMatrix(a$resids2,wave,id,asList=TRUE)
  if(!is.null(a$leverages))  x$leverages  = wideDataMatrix(a$leverages,wave,id,asList=FALSE)
  if(!is.null(a$leverages2)) x$leverages2 = wideDataMatrix(a$leverages2,wave,id,asList=FALSE)
  if(!is.null(a$samplingWeights)) x$samplingWeights = wideDataMatrix(a$samplingWeights,wave,id,asList=FALSE)
  if(!is.null(a$wGross))     x$wGross = wideDataMatrix(a$wGross,wave,id,asList=FALSE)
  if(!is.null(extra))        x$extra = wideDataMatrix(extra,wave,id,asList=TRUE)
  else
    if(!is.null(a$extra))      x$extra = wideDataMatrix(a$extra,wave,id,asList=TRUE)
  if(is.null(subSet)) return(x)
  s123 = make123(subSet)
  s = wideDataMatrix(s123,wave,id,asList=FALSE)
  k = vector("list",max(s123))
  k = structure(k,class = "calSSBwideList") # Ny her
  names(k) = levels(s123)
  for(i in 1:max(s123)){
    si = s==i
    rowsi = rowSums(si,na.rm=TRUE)>0
    k[[i]] = x
    for(j in 1:length(k[[i]]$y)) k[[i]]$y[[j]] = MakeSubSet(x$y[[j]],si,rowsi)
    for(j in 1:length(k[[i]]$resids)) k[[i]]$resids[[j]] = MakeSubSet(x$resids[[j]],si,rowsi)
    for(j in 1:length(k[[i]]$resids2)) k[[i]]$resids2[[j]] = MakeSubSet(x$resids2[[j]],si,rowsi)
    for(j in 1:length(k[[i]]$extra)) k[[i]]$extra[[j]] = MakeSubSet(x$extra[[j]],si,rowsi)
    k[[i]]$w = MakeSubSet(x$w,si,rowsi)
    k[[i]]$leverages = MakeSubSet(x$leverages,si,rowsi)
    k[[i]]$leverages2 = MakeSubSet(x$leverages2,si,rowsi)
    k[[i]]$samplingWeights = MakeSubSet(x$samplingWeights,si,rowsi)
    k[[i]]$wGross = MakeSubSet(x$wGross,si,rowsi)
  }
  k
}

# Old name bigData
# Can be simplified
wideDataMatrix = function(data,bigStrata=rep(1,n),id,nameSep="-",dropSingleName=TRUE,asList=FALSE)
{
  n <- NROW(data)
  if(!is.matrix(data)) data = data.matrix(data)
  if(!is.null(colnames(data))) varNames = colnames(data)
    else varNames = paste("y",1:dim(data)[2],sep="")
  if(asList){
    k = vector("list",dim(data)[2])
    names(k) = varNames
    for(i in 1:dim(data)[2])
      k[[i]] = wideDataMatrix(data=data[,i,drop=FALSE],bigStrata=bigStrata,id=id,dropSingleName=TRUE)
    return(k)
  }
  dropName = (dim(data)[2]==1 & dropSingleName)
  if(dropName) nameSep=""
  bigStrata = make123(bigStrata)
  id=make123(id)
  nBig    = max(bigStrata)
  bigNames  = paste(nameSep,levels(bigStrata),sep="")
  x0 = matrix(NaN,nrow=max(id),ncol=dim(data)[2])
  z=NULL
  for(i in 1:nBig)
  {
    x=x0
    datai = data[bigStrata==i,,drop=FALSE]
    x[id[bigStrata==i],] = datai
    if(dropName) colnames(x) = bigNames[i]
      else colnames(x) = paste(varNames,bigNames[i],sep="")
    z=cbind(z,x)
  }
  z
}


make123 = function(x)
{
  x=as.factor(x)
  levels_x = levels(x)
  x=as.numeric(x)
  attr(x,"levels") = levels_x
  x
}

rBind = function(x,y) rbind(data.frame(x),data.frame(y))[[1]]


uniqueIndex = function(x,useRev=FALSE){
  if(useRev) x = rev(x)
  ix = unique(match(x,x))
  if(!useRev) return(ix)
  sort((length(x):1)[ix])
}

uniqueCol= function(x,useRev=FALSE){
  if(is.null(dim(x))) {
    namesx=names(x)
    x=matrix(x,nrow=1)
    colnames(x)=namesx
  }
  x[,uniqueIndex(colnames(x),useRev),drop=FALSE]
}

sortrows <- function(m, cols = 1:dim(m)[2], index.return = FALSE) {
  ix <- eval(parse(text = paste("order(", paste("m[[", cols, "]]", sep = "", collapse = ","),  ")")))
  if (index.return) 
    return(ix)
  m[ix, , drop = FALSE]
}

sortrowsOld = function(m,cols=1:dim(m)[2],index.return=FALSE)
{
  ix=eval(parse(text=paste("order(",paste("m[,",cols,"]",sep="", collapse=","),")")))
  if(index.return) return(ix)
  m[ix, ,drop=FALSE]
}


MYestTMold = function(grossSample,y,w,by){
  if(!is.null(by)) if(is.na(by[1])) by = NULL
  estTM =aggregate(grossSample[,y]*w,grossSample[,by,drop=FALSE],sum_)
  if(!is.null(by)) estTM = sortrows(estTM,1:length(by))
  if(length(y)==1) names(estTM)[length(names(estTM))] = y
  estTM
}

MYestTM = function(grossSample,y,w,by){
  if(!is.null(by)) if(is.na(by[1])) by = NULL
  #grossSample <<- grossSample
  #w <<- w
  #y <<- y
  #estTM =aggregate(grossSample[,y, drop = TRUE]*w,grossSample[,by,drop=FALSE],sum_)
  
  
  if(!is.null(by)){
    #cat("#")
    estTM = sortrows(aggregate(grossSample[,y, drop = TRUE]*w,grossSample[,by,drop=FALSE],sum_),1:length(by))
  } else {
    #cat("0")
    estTM =aggregate(grossSample[,y, drop = TRUE]*w,grossSample[,integer(0),drop=FALSE],sum_)
  }
  
  if(length(y)==1) names(estTM)[length(names(estTM))] = y
  estTM
}



mergeSort = function(x,y,useRev=FALSE,remov=FALSE){
  x=as.data.frame(x)
  y=as.data.frame(y)
  if(NROW(x)!=NROW(y)) stop("Not exact match")
  colnamesx   = colnames(x)
  colnames(x) = paste(colnamesx,"_",sep="")
  uniqueIndex_ = uniqueIndex(colnamesx,useRev)
  colnames(x)[uniqueIndex_] = colnamesx[uniqueIndex_]
  mergeSortNr123 = 1:NROW(x)
  mergeSortNr345 = 1:NROW(x)
  names_y=names(y)
  z=merge(cbind(x,mergeSortNr345),cbind(y,mergeSortNr123),names_y)
  if(NROW(x)!=NROW(z)) stop("Not exact match")
  k=dim(z)[2]
  if(remov) cols = !(colnames(x) %in% names_y)
  else cols = rep(TRUE,length(colnamesx))
  colnames(x) = colnamesx
  x[z[order(z[,"mergeSortNr123"]),"mergeSortNr345"],cols]
}

MakeSubSet = function(x,subSet,rows){
  if(is.null(x)) return(x)
  x[!subSet] = NaN
  x[rows,,drop=FALSE]
}


sum_ = function(x) sum(x,na.rm=TRUE)



asFormula = function(s) {
  if(is.null(s)) return(NULL)
  if(class(s)[1]=="formula") return(s)
  if(is.na(s)[1]) return(NULL)
  as.formula(paste("~",paste(s,collapse="+"),sep=""))
}


CalibratePackageReGeneseesCRANversion = function(netSample,calmodel=NULL,popTotals=NULL,y=NULL,by = NULL,partition=NULL,
                          popData=NULL,samplingWeights=NULL,bounds=c(-Inf,Inf),calfun="linear",
                          onlyTotals=FALSE,ids,...){
  stop("Use of ReGenesees is not implemented in this version since ReGenesees is not on CRAN.")
}





calibrateSSB = function(grossSample,calModel=NULL,
                        popTotals=NULL,response=NULL,lRegModel=NULL,
                        popData=NULL,samplingWeights=NULL,
                        usePackageSurvey=TRUE,bounds=c(-Inf,Inf),calfun="linear",
                        totalReturn=0,uselRegWeights=FALSE,...)                ### Merk: uselRegWeights=FALSE
{
  n = NROW(grossSample)

  w=samplingWeights

  if(uselRegWeights) lRegWeights=samplingWeights
  else lRegWeights=NULL


  if(!is.null(lRegModel))
  {
    if(is.null(lRegWeights)) glm_modell = glm(as.formula(lRegModel),data=grossSample,family = binomial())
    else glm_modell = glm(as.formula(lRegModel),data=grossSample,family = binomial(),weights=lRegWeights)
    lRegW = 1/predict(glm_modell,type = "response")
    lRegW[model.frame(glm_modell)[1]==0] = 0
    if(is.null(w)) w=1
    w = w*lRegW

    if(length(popTotals)>0)
    {
      w = w*popTotals[1]/sum(w)
    }
  }
  a = list(w=w,wGross=NULL)

  if(!is.null(calModel))
  {
    if(usePackageSurvey)
    {
      a=calibratePackageSurvey(grossSample=grossSample,modelformula=calModel,
                               popTotals=popTotals,response=response,popData=popData,samplingWeights=w,
                               bounds=bounds,calfun=calfun,totalReturn=totalReturn,returnwGross=TRUE,...)
    } else


    {
      if(!(calfun=="linear")) stop("Method not implemented")
      if(!is.null(popTotals)) popData=popTotals
      a=lagVekter(calModel,grossSample,popData,min_w = bounds[1],
                  max_w = bounds[2],totalReturn=totalReturn,samplingWeights=w,returnwGross=TRUE)
    }
  }
  a
}
