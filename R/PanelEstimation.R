#' Variance estimation for panel data
#'
#' Variance estimation of linear combinations of totals and ratios based on
#' output from wideFromCalibrate
#'
#' When denominator=NULL, only estimates for a single y-variable (numerator)
#' are calculated. When denominator is specified, estimates for numerator,
#' denominator and ratio are calculated. The default estimation type parameter,
#' "robustModel", is equation (12) in paper. "ssbAKU" is (16), "robustModelww"
#' is (9) and "robustModelGroup" and "robustModelGroupww" are cluster robust
#' variants based on \eqn{(w-1)^2} and \eqn{w^2} .
#'
#' @param x Output from wideFromCalibrate.
#' @param numerator y variable name or number.
#' @param denominator y variable name or number.
#' @param linComb Matrix defining linear combinations of waves.
#' @param linComb0 Linear combination matrix to be used prior to ratio
#' calculations.
#' @param estType Estimation type: "robustModel" (default), "ssbAKU",
#' "robustModelww", "robustModelGroup" or "robustModelGroupww" (see below)
#' @param leveragePower Power used when adjusting residuals using leverages.
#' @param group Extra variable name or number for cluster robust estimation.
#' @param returnCov Return covariance matrices instead of variance vectors.
#' @param usewGross Use wGross (if avaliable) instead of design weights to
#' adjust covariance matrix in the case of NA popTotals
#' @return \item{wTot}{Sum of weights} \item{estimates}{Ordinary estimates}
#' \item{linCombs}{Estimates of linear combinations}
#' \item{varEstimates}{Variance of estimates} \item{varLinCombs}{Variance of
#' estimates of linear combinations} When denominator is specified the above
#' output refer to ratios. Then, similar output for numerator and denominator
#' are also included.
#' 
#' @seealso \code{\link{CalibrateSSB}}, \code{\link{CalSSBobj}}, \code{\link{WideFromCalibrate}}, \code{\link{CalibrateSSBpanel}}. 
#' 
#' @examples
#'
#' # Generates data  - two years
#' z    = AkuData(3000)  # 3000 in each quarter
#' zPop = AkuData(10000)[,1:7]
#'
#' # Calibration and "WideFromCalibrate"
#' b = CalibrateSSB(z,calmodel="~ sex*age", partition=c("year","q"),
#'         popData=zPop, y=c("unemployed","workforce"))
#' bWide = WideFromCalibrate(b,CrossStrata(z[,c("year","q")]),z$id)
#'
#' # Define linear combination matrix
#' lc = rbind(LagDiff(8,4),PeriodDiff(8,4))
#' rownames(lc) = c("diffQ1","diffQ2","diffQ3","diffQ4","diffYearMean")
#' colnames(lc) = colnames(head(bWide$y[[1]]))
#' lc
#'
#' # Unemployed: Totals and linear combinations
#' d1=PanelEstimation(bWide,"unemployed",linComb=lc)  #
#'
#' # Table of output
#' cbind(tot=d1$estimates,se=sqrt(d1$varEstimates))
#' cbind(tot=d1$linCombs,se=sqrt(d1$varLinCombs))
#'
#' # Ratio: Totals and linear combinations
#' d=PanelEstimation(bWide,numerator="unemployed",denominator="workforce",linComb=lc)
#' cbind(tot=d$estimates,se=sqrt(d$varEstimates))
#' cbind(tot=d$linCombs,se=sqrt(d$varLinCombs))
#'
#' \dontrun{
#' # Calibration when som population totals unknown (edu)
#' # Leverages in output (will be used to adjust residuals)
#' # Cluster robust estimation (families/famid)
#' b2 = CalibrateSSB(z,popData=zPop,calmodel="~ edu*sex + sex*age",
#'            partition=c("year","q"), y=c("unemployed","workforce"),
#'            leverageOutput=TRUE)
#' b2Wide = WideFromCalibrate(b2,CrossStrata(z[,c("year","q")]),z$id,extra=z$famid)
#' d2 = PanelEstimation(b2Wide,"unemployed",linComb=lc,group=1,estType = "robustModelGroup")
#' cbind(tot=d2$linCombs,se=sqrt(d2$varLinCombs))
#' }
#'
#'
#' # Yearly mean before ratio calculation (linComb0)
#' # and difference between years (linComb)
#' g=PanelEstimation(bWide,numerator="unemployed",denominator="workforce",
#'     linComb= LagDiff(2),linComb0=Period(8,4))
#' cbind(tot=g$linCombs,se=sqrt(g$varLinCombs))
#'
#' @export PanelEstimation
PanelEstimation = function(x,numerator,denominator=NULL,linComb=matrix(0,0,n),linComb0=NULL,
                      estType="robustModel",leveragePower=1/2,group=NULL,returnCov=FALSE,usewGross=TRUE){
  if(class(x$w)[1]=="NULL"){
    z = vector("list",length(x))
    names(z) = names(x)
    n = dim(ListCbind(x[[1]]$y,numerator))[2]
    for(i in 1:length(x))
      z[[i]] = PanelEstimation(x[[i]],numerator,denominator,linComb,linComb0,estType,leveragePower,group,returnCov,usewGross)
    return(z)
  }
  if(is.null(denominator)){ # Enklere versjon av koden under
    m = length(numerator)
    y = ListCbind(x$y,numerator)
    n = dim(y)[2]
    nlc = dim(linComb)[1]
    w = RepCbind(x$w,m)

    if(usewGross & !is.null(x$wGross)){
      samplingWeights  = RepCbind(x$wGross,m)  # **** wGross -> samplingWeights
    } else {
      if(!is.null(x$samplingWeights))
        samplingWeights  = RepCbind(x$samplingWeights,m)
      else
        samplingWeights=NULL
    }
    if(!is.null(x$leverages))
      leverages  = RepCbind(x$leverages,m)
    else
      leverages = 0
    if(!is.null(x$leverages2))
      leverages2  =  RepCbind(x$leverages2,m)
    else
      leverages2 = 0
    resids  = ListCbind(x$resids,numerator)/(1-leverages)^leveragePower
    if(!is.null(x$resids2))
      resids2  = ListCbind(x$resids2,numerator)/(1-leverages2)^leveragePower
    else
      resids2 = NULL

  } else{
    n = dim(x$y[[numerator]])[2]
    nlc = dim(linComb)[1]
    y = cbind(x$y[[numerator]],x$y[[denominator]])
    w = cbind(x$w,x$w)
    if(usewGross & !is.null(x$wGross)){
      samplingWeights  = cbind(x$wGross,x$wGross) # **** wGross -> samplingWeights
    } else {
      if(!is.null(x$samplingWeights))
        samplingWeights  = cbind(x$samplingWeights,x$samplingWeights)
      else
        samplingWeights=NULL
    }
    if(!is.null(x$leverages))
      leverages  = cbind(x$leverages,x$leverages)
    else
      leverages = 0
    if(!is.null(x$leverages2))
      leverages2  = cbind(x$leverages2,x$leverages2)
    else
      leverages2 = 0
    resids  = cbind(x$resids[[numerator]],x$resids[[denominator]])/(1-leverages)^leveragePower
    if(!is.null(x$resids2))
      resids2  = cbind(x$resids2[[numerator]],x$resids2[[denominator]])/(1-leverages2)^leveragePower
    else
      resids2 = NULL
  }
  if(!is.null(group)){
    gr = group
    group = rowNoNA(data.matrix(x$extra[[gr]])) ##### First element.
    group2 = rowNoNA(data.matrix(x$extra[[gr]]),max) ##### Last element.
    eq = sum(as.numeric(!(group==group2),na.rm=TRUE))
    if(eq>0)
      warning(sprintf("Non-unique group detected. Last not equal first in %d cases. First used.",eq))
  }
  covTotals = TotalsWithCov(y,resids,w,estType,resids2,
                            samplingWeights=samplingWeights,group=group)
  a=NULL
  a$wTot = colSums(x$w,na.rm = TRUE)
  if(!is.null(samplingWeights))
    a$samplingWeightsTot = colSums(samplingWeights,na.rm = TRUE)

  if(is.null(denominator)){
    if(is.null(linComb0)) A = linComb
    else A = linComb %*% linComb0
    pEst = PanelEst(covTotals$totals,covTotals$covTotals,
                    A = A,returnCov=returnCov)
    a$estimates    =  pEst$totals[,1,drop=TRUE]
    if(nlc) a$linCombs     =  pEst$Atotals[,1,drop=TRUE]
    a$varEstimates =  pEst$varTotals
    if(nlc) a$varLinCombs  =  pEst$varAtotals
    return(a)
  }
  nn=n
  diag2n =  diag(1,2*n)
  rownames(diag2n) = colnames(y)
  if(is.null(linComb0)) {
    A = rbind(diag2n,cbind(linComb,matrix(0,dim(linComb)[1],n)),cbind(matrix(0,dim(linComb)[1],n),linComb))
    numerator=1:n
    names(numerator) = colnames(y)[1:n]
  } else {
    A2        = rbind(cbind(linComb0,matrix(0,dim(linComb0)[1],n)),cbind(matrix(0,dim(linComb0)[1],n),linComb0))
    linComb2  = linComb %*% linComb0
    AlinComb2 = rbind(cbind(linComb2,matrix(0,dim(linComb2)[1],n)),cbind(matrix(0,dim(linComb2)[1],n),linComb2))
    A = rbind(A2,AlinComb2)
    n = dim(linComb0)[1]
    nlc = dim(linComb2)[1]
    numerator=1:n
    names(numerator) = rownames(linComb0)
  }
  pEst = PanelEst(covTotals$totals,covTotals$covTotals,
                  A = A,
                  numerator=numerator,denominator=(n+1):(2*n), B=linComb,
                  returnCov=returnCov)
  a$estimates       =  pEst$ratios[,1,drop=TRUE]
  a$estimatesNum    =  pEst$totals[1:nn,1,drop=TRUE]
  a$estimatesDen    =  pEst$totals[(nn+1):(2*nn),1,drop=TRUE]
  if(nlc) a$linCombs      =  pEst$Bratios[,1,drop=TRUE]
  if(nlc) a$linCombsNum   =  pEst$Atotals[(2*n+1):(2*n+nlc),1,drop=TRUE]
  if(nlc) a$linCombsDen   =  pEst$Atotals[(2*n+nlc+1):(2*n+2*nlc),1,drop=TRUE]
  a$varEstimates    =  pEst$varRatios
  a$varEstimatesNum =  TakeIndexBoth(pEst$varTotals,1:nn)
  a$varEstimatesDen =  TakeIndexBoth(pEst$varTotals,(nn+1):(2*nn))
  if(nlc) a$varLinCombs     =  pEst$varBratios
  if(nlc) a$varLinCombsNum  =  TakeIndexBoth(pEst$varAtotals,(2*n+1):(2*n+nlc))
  if(nlc) a$varLinCombsDen  =  TakeIndexBoth(pEst$varAtotals,(2*n+nlc+1):(2*n+2*nlc))
  a
}



PanelEst = function(totals,covTotals,A=matrix(0,0,length(totals)),numerator=integer(0),denominator=integer(0),
                    B=diag(1,length(numerator)),
                    returnCov=FALSE,
                    rationames=names(numerator))
{
  #### Level 1: Input variables
  #### Level 2: Lin.comb of input
  Atotals    = A %*% totals
  covAtotals = A %*% covTotals %*% t(A)


  #### Level 3: Ratios of lin.comb
  # Variansen til X/Y beregnes som variansen til X/y - Yx/yy
  rNum = Atotals[numerator,,drop=FALSE]    # teller-estimater (x)
  rDen = Atotals[denominator,,drop=FALSE]  # nevner-estimater (y)
  D = matrix(0,nrow=length(rNum),ncol=dim(A)[1]) # D genererer "X/y - Yx/yy"
  if(dim(D)[1]) for(i in 1:dim(D)[1]){
    D[i,numerator[i]]   = 1/rDen[i]  # X blir multiplisert med "1/y"
    D[i,denominator[i]] = -rNum[i]/(rDen[i])^2 # Y blir multiplisert med "x/yy"
  }
  ratios  = rNum/rDen
  rownames(ratios) = rationames
  rownames(D) = rationames
  covRatios = D %*% covAtotals %*% t(D)

  #### Level 4: Lin.comb of ratios
  Bratios = B %*% ratios
  covBratios = B %*% covRatios %*% t(B)

  if(returnCov) return(list(totals=totals,Atotals=Atotals,ratios=ratios,Bratios=Bratios,
                            varTotals=covTotals,varATotals=covAtotals,varRatios=covRatios,varBratios=covBratios))
  list(totals=totals,Atotals=Atotals,ratios=ratios,Bratios=Bratios,varTotals=diag(covTotals),varAtotals=diag(covAtotals),
       varRatios=diag(covRatios),varBratios=diag(covBratios))
}



TotalsWithCov = function(y,resids,w,estType="robustModel",   #dummy=!is.na(w)
                         resids2=NULL,returnNr=FALSE,returnNr1=FALSE,
                         samplingWeights=NULL,dummyGross=!is.na(w),dummyNet=!is.na(resids), ...){
  force(dummyGross) # dummy is created (lazy evaluation)
  force(dummyNet) # dummy is created (lazy evaluation)
  a=NULL
  y[is.na(y)]=0
  w[is.na(w)]=0
  resids[is.na(resids)]=0
  a$totals = matrix(colSums(w*y),nrow=dim(y)[2]) # T is column vector
  rownames(a$totals) = colnames(y)

  a$covTotals = MakeCovTotals(resids,w,dummyNet,estType,...)


  if(!is.null(resids2)){
    resids2[is.na(resids2)]=0
    if(is.null(samplingWeights)){
      samplingWeights = t(matrix(colSums(w)/colSums(dummyGross),dim(w)[2],dim(w)[1]))
    }
    else samplingWeights[is.na(samplingWeights)] = 0
    v=w/samplingWeights
    v[is.na(v)]=0
    if(estType=="ssbAKU") estType = "robustModel"   # Obs here
    covTotalsNr  = MakeCovTotals(resids2*samplingWeights,v,dummyNet,estType,...)
    covTotalsNr1 = MakeCovTotals(resids*samplingWeights,v,dummyNet,estType,...)
    a$covTotals = a$covTotals - covTotalsNr1 + covTotalsNr
    if(returnNr)   a$covTotalsNr  = covTotalsNr
    if(returnNr1)  a$covTotalsNr1 = covTotalsNr1
  }
  a
}


MakeCovTotals  = function(e,w,dummy,estType,group=NULL){ # e instead of resids
  if(estType=="ssbAKU") {
    n = t(dummy) %*% dummy
    We  = w*e
    mWe = matrix(colSums(We)/diag(n),nrow=1)
    covTotals = n/(n-1) * (t(We)%*%We - n*t(mWe)%*%mWe)
  }

  if(estType=="robustModel"){
    we = (w-1)*e
    covTotals = t(we)%*%we
    we = sqrt(pmax(w-1,0))*e    ### Negativ (w-1) settes til 0
    covTotals = covTotals + t(we)%*%we
  }

  if(estType=="robustModelww"){
    we = w*e
    covTotals = t(we)%*%we
  }
  if(estType=="robustModelGroup"|estType=="robustModelGroupww"){
    we = data.matrix(aggregate(w*e,list(group),sum)[,-1,drop=FALSE])
    if(estType=="robustModelGroupww"){
      covTotals = t(we)%*%we
    } else{
      we1 = data.matrix(aggregate((w-1)*e,list(group),sum)[,-1,drop=FALSE])
      covTotals = t(we)%*%we1
    }
  }
  covTotals[!is.finite(covTotals)]=0 # Avoid problems when "n-1=0" and n=0
  covTotals
}


rowNoNA = function(x,maxmin=min){
  colx = col(x)
  colx[is.na(x)] = NA
  element = apply(colx,1,function(x) maxmin(x,na.rm=T))
  x[cbind(1:dim(x)[1],element)]
}

TakeIndexBoth = function(x,index){
  if(is.matrix(x)) return(x[index,index,drop=FALSE])
  x[index]
}


seq_ = function(a,b) seq(a,b,length = max(0,b-a+1))

MyDiag = function(n,k=0){
  x = diag(n)
  z = matrix(0,n,n)
  a  = max(1+k,1)
  b  = min(n+k,n)
  a2 = max(1-k,1)
  b2 = min(n-k,n)
  z[,seq_(a,b)] = x[,seq_(a2,b2)]
  z
}





#' Creation of linear combination matrices
#'
#' Create matrices for changes (LagDiff), means (Period) and mean changes
#' (PeriodDiff).
#'
#'
#' @aliases LinCombMatrix PeriodDiff Period LagDiff
#' @param n Number of variables
#' @param period Number of variables involved in each period
#' @param lag Lag used for difference calculation
#' @param k Shift the start of each period
#' @param takeMean Calculate mean over each period (sum when FALSE)
#' @param removerows Revove incomplete rows
#' @param overlap Overlap between periods (moving averages)
#' @return Linear combination matrix
#' @note It can be useful to add row names to the resulting matrix before
#' further use.
#' @examples
#'
#' # We assume two years of four quarters (n=8)
#'
#' # Quarter to quarter differences
#' LagDiff(8)
#'
#' # Changes from same quarter last year
#' LagDiff(8,4)
#'
#' # Yearly averages
#' Period(8,4)
#'
#' # Moving yearly averages
#' Period(8,4,overlap=TRUE)
#'
#' # Difference between yearly averages
#' PeriodDiff(8,4) # Also try n=16 with overlap=TRUE/FALSE
#'
#' # Combine two variants and add row names
#' lc = rbind(LagDiff(8,4),PeriodDiff(8,4))
#' rownames(lc) = c("diffQ1","diffQ2","diffQ3","diffQ4","diffYearMean")
#' lc
#'
#' @export LinCombMatrix
LinCombMatrix = function(n,period=NULL,lag=NULL,k=0,takeMean=TRUE,removerows=TRUE,overlap=FALSE){
  if(is.null(period)){
    if(is.null(lag)) x = diag(n)
    else x = LagDiff(n,lag=lag,removerows=removerows)
  } else{
    if(is.null(lag)) x = Period(n=n,period=period,k=k,takeMean=takeMean,removerows=removerows,overlap=overlap)
    else x = PeriodDiff(n=n,period=period,lag=lag,k=k,takeMean=takeMean,removerows=removerows,overlap=overlap)
  }
  x
}



#' @rdname LinCombMatrix
#' @encoding UTF8
#' @export
#'
LagDiff= function(n,lag=1,removerows=TRUE){
  m=MyDiag(n,lag) - diag(n)
  if(removerows) m = m[rowSums(m)==0 & rowSums(abs(m))==2 , ,drop=FALSE]
  m
}

#' @rdname LinCombMatrix
#' @encoding UTF8
#' @export
#'
Period = function(n,period=1,k=0,takeMean=TRUE,removerows=TRUE,overlap=FALSE){
  x =matrix(0,n,n)
  for(i in seq_(1,period) ) x = x+MyDiag(n,k+i-1)
  if(removerows) x = x[rowSums(x)==period, ,drop=FALSE]
  if(!overlap)   x = x[((-1+1:dim(x)[1])%%period)==0, ,drop=FALSE]
  if(takeMean)   x = x/period
  x
}

#' @rdname LinCombMatrix
#' @encoding UTF8
#' @export
#'
PeriodDiff = function(n,period=1,lag=period,k=0,takeMean=TRUE,removerows=TRUE,overlap=FALSE){
  a = Period(n=n,period=period,k=k,takeMean=FALSE,removerows=FALSE,overlap=TRUE)
  b = Period(n=n,period=period,k=k+lag,takeMean=FALSE,removerows=FALSE,overlap=TRUE)
  x = b-a
  if(removerows) x = x[rowSums(x)==0 & rowSums(abs(x))==2*period , ,drop=FALSE]
  if(!overlap)   x = x[((-1+1:dim(x)[1])%%period)==0, ,drop=FALSE]
  if(takeMean)   x = x/period
  x
}






RepCbind = function(x,n){
  z = NULL
  for(i in seq_len(n)) z=cbind(z,x)
  z
}

ListCbind = function(x,elements,sep="-"){
  z = NULL
  n = length(elements)
  for(i in seq_len(n)){
    z1 = x[[elements[i]]]
    colnames(z1) = paste(elements[i],colnames(z1),sep=sep)
    z  = cbind(z,z1)
  }
  z
}

