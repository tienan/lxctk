#Copyright 2009 Qunyuan Zhang

#This file is part of CMDS.

#CMDS is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#CMDS is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.

##############################################################
# CN SIMULATION FOR CMDS ...
##############################################################

Simulate_Regions=function(n,regions,cor=FALSE,viberate=NULL,vary=T)
{
# background intensity
row_n=n
col_n=regions["background","end"]
mu=regions["background","mean"]
sigma=regions["background","sd"]
simu_data=matrix(0,row_n,col_n)
simu_data[,]=rnorm(row_n*col_n,mean=mu,sd=sigma)

# non-recorrent regions
regions["nonrec","start"]->lamda
if (lamda>0)
{
nonrec_n=as.integer(regions["nonrec","freq"]*row_n)
nonrec_len=rpois(nonrec_n,lamda)+1
start=as.integer(runif(nonrec_n)*(col_n-nonrec_len))
start[start==0]=1
sampid=sample(1:row_n,nonrec_n)
sigma=regions["nonrec","sd"]
mu0=regions["nonrec","mean"]
for(i in c(1:length(sampid)))
{
if (is.null(viberate)) mu=mu0 else mu=cn.viberate(viberate) 
simu_data[sampid[i],start[i]:(start[i]+nonrec_len[i]-1)]=rnorm(nonrec_len[i],mean=mu,sd=sigma)
}

}

# recorrent regions
for (region_i in rownames(regions)[-(1:2)])
{
start=regions[region_i,"start"]
end=regions[region_i,"end"]
common_n=as.integer(regions[region_i,"freq"]*row_n)
mu0=regions[region_i,"mean"]
sigma=regions[region_i,"sd"]
for(i in c(1:common_n))
{
if (is.null(viberate)) mu=mu0 else mu=cn.viberate(viberate)
if (vary==F) {endi=end;starti=start}
if (vary==T)
{mid=(end-start)/2+start;vi=rpois(1,end-start)
endi=mid+vi/2;starti=mid-vi/2}
 
simu_region=rnorm((endi-starti+1),mean=mu,sd=sigma)
if (cor==TRUE) {simu_data[i,starti:endi]=simu_region}
if (cor==FALSE) {simu_data[sample(1:row_n,1),starti:endi]=simu_region}
}
}
simu_data
}


cn.viberate=function(f)
{
f=f/sum(f)
m=log2((c(1:length(f))-1)/2);m[1]=-3
f2=f;for(i in c(1:length(f))) f2[i]=sum(f[1:i])
f1=c(0,f2[-length(f2)]) 
x=runif(1); mx=m[x>f1 & x<f2]
mx 
}

##############################################################
# CMDS ...
##############################################################

cmds=function(x,wsize=10,wstep=1,ztrans=T,alpha=0.05,m.cut=0)
{
Diagonalize_Regions(x,wsize,wstep,ztrans)[,"z"]->temp
temp=cbind(c(1:length(temp)),temp)
Smooth_Regions(temp,norm=T,draw=F)-> smo
smo$adj_region=smo$region
Test_Regions(smo,alpha,m.cut)->smo
Adjust_Sig_Rigions(smo,tail=wsize,ignore=wsize)->smo
invisible(smo)
}

#########################################################

Smooth_Regions=function(c,norm=T,draw=F)
{
x0=c[,2]
if (norm==TRUE){c[,2]=(c[,2]-mean(c[,2]))/sd(c[,2])}
c=as.data.frame(c)
cgh=cbind(c(1:dim(c)[1]),c,1)
colnames(cgh)=c("PosOrder","PosBase","LogRatio","Chromosome")
cgh<- as.profileCGH(cgh)

 res <- glad(cgh, mediancenter = FALSE, smoothfunc = "lawsglad",
 bandwidth = 10, round = 1.5, model = "Gaussian", lkern = "Exponential",
 qlambda = 0.99, base = FALSE, lambdabreak = 8, lambdacluster = 8,
 lambdaclusterGen = 40, type = "tricubic", param = c(d = 6),
 alpha = 0.001, msize = 5, method = "centroid", nmax = 8,
 verbose = FALSE)

res=res$pro[,c("PosOrder","PosBase","LogRatio","Smoothing","Region")]
colnames(res)=c("order","pos","x","smth","region")
res=cbind(res,x0)

#plotProfile(res, unit = 3, Bkp = TRUE, labels = FALSE, Smoothing = "Smoothing", plotband = FALSE)
if (draw==TRUE)
{
plot(res[,"x"],type="l")
lines(res[,"smth"],col="Blue",lwd=2)
abline(0,0,col="Red",lty=3)
abline(2,0,col="Red",lty=3)
abline(-2,0,col="Red",lty=3)
}
res
}
 
##############################################################

Test_Regions=function(x,alpha=0.05,m.cut=0)
{
tapply(x$x,x$adj_region,mean)->m
tapply(x$x,x$adj_region,sd)->sd
table(x$adj_region)->n
t=m/sd
p=pt(-abs(t),df=n-1)*2
(!is.na(p) & m>m.cut[1] & p<alpha) -> sig; sig=as.numeric(sig) 
p=cbind(m,p,sig)
x=merge(x,p,by.x="adj_region",by.y="row.names")
x
}

##################

window.test=function(x=smo,alpha=0.05,m.cut=0)
{
p=pnorm(-abs(x$x)*2)
(!is.na(p) & x$x>m.cut & p<=alpha) -> sig; sig=as.numeric(sig) 
x=cbind(x,p,sig)
x
}

##############################################################

Adjust_Sig_Rigions=function(x,head=5,tail=5,ignore=5)
{
r=x$adj_region;o=x$order;s=x$sig
rs=table(r[s==1]);rs=rs[rs>ignore]
for (rsi in names(rs))
{
id=o[r==rsi];firstid=id[1];lastid=id[length(id)]
newlastid=lastid+tail; if (newlastid>length(o)){newlastid=length(o)}
s[lastid:newlastid]=1
}
x$adj_sig=s
x
}

##############################################################

Error_Of_Regions=function(sig,para)
{
#sig: significant regions, para: parameter matrix in simulation
sig0=numeric(length(sig))
sig0[para[3,"start"]:para[3,"end"]]=1
nh0=sum(sig0==0);nha=sum(sig0==1)
type1=sum(sig0==0 & sig==1)/nh0
power=sum(sig0==1 & sig==1)/nha
fdr=sum(sig0==0 & sig==1)/sum(sig==1)
sigid=c(1:length(sig))[sig==1]
t=para[3,"start"];t=sigid-t;b=t[order(abs(t))[1]]
t=para[3,"end"];t=sigid-t;a=t[order(abs(t))[1]]
err=cbind(type1,power,fdr,b,a)
err
}


##############################################################
# CN PLOTS ...
##############################################################

heatCN=function(x,co=gray(0:255/255),cut=NULL,xt=NULL,random=F)
{
ta=x
#raw data heatmap image
heatmap(ta,Colv=NA,scale="none")->ht
#if (random==FALSE) {ta=ta[ht$rowInd[1:357],]}
if (random==FALSE) {ta=ta[ht$rowInd,]}
if (random==TRUE) {ta=ta[sample(c(1:nrow(ta)),nrow(ta)),]}
ta[1,1]=0;ta[1,2]=6
if (length(cut)==2)
{
co=c("green","black","red")
bo=as.integer(min(ta)-5)
ta[ta<cut[1]]=bo-1;ta[ta>=cut[1] & ta<=cut[2]]=bo;ta[ta>cut[2]]=bo+1
ta=ta-bo
}
if (is.null(xt)){xt=paste(ncol(ta)," SNPs (Mbp)")}
xa=as.numeric(colnames(ta))/1000000
xa=seq(min(xa),max(xa),by=(max(xa)-min(xa))/length(xa))
image(x=xa,
y=c(1:nrow(ta)),z=t(ta),col=co,
main="Tumor/Normal Intensity Ratios",font=2,font.lab=2,
ylab=paste(nrow(ta)," Samples",sep=""),xlab=xt)
}
############################################################################
cn.plot=function(tt,type="raw",co=c(rgb(0,20:0/20,0),rgb(0:40/40,0,0)),
wsize=30,wn=800,grp=NULL,random=F)
{
temp=as.integer(ncol(tt)/wn+0.5)
if (temp<=0) {temp=1}
c=seq(1,ncol(tt),by=temp)
y=as.numeric(colnames(tt))/1000000
ta=tt[,c]
ta=2^ta*2
ta[ta>6]=6
xtext=paste(ncol(tt)," SNPs (Mbp)")

#-----CN heat map-----------------------
#png(paste(fi,"_raw.png",sep=""),height=600,width=800)
if (type=="raw")
{
if (is.null(grp)) heatCN(ta,co,xt=xtext,random=random)

if (!is.null(grp))
{
tb=ta[grp$id,]
#heatmap(tb,Colv=NA,scale="none")->ht
#b=tb[ht$rowInd,]
labr=c(1:nrow(tb))*NA;labr[1]=1;labr[length(labr)]=length(labr)
temp=seq(1,length(labr),by=as.integer(length(labr)/5));labr[temp]=temp
labc=c(1:ncol(tb))*NA;labc[1]=min(y[c]);labc[length(labc)]=max(y[c])
temp=seq(1,length(labc),by=as.integer(length(labc)/5))
labc[temp]=min(y[c])+(temp-1)*(max(y[c])-min(y[c]))/length(labc)
labc=substring(as.character(labc),1,5)
temp=unique(grp[,c("group","color")])
mtxt=character(0)
for (i in c(1:nrow(temp)))
{
mtxt=paste(mtxt,temp[i,"color"],":",temp[i,"group"],"   ",sep="")
}
heatmap(tb,Rowv=NA,Colv=NA,scale="none",col=co,
RowSideColors=as.character(grp$color),
labRow=labr,labCol=labc,cexRow=1,cexCol=1,
ylab="samples",xlab=xtext,main=mtxt)
}
}

#dev.off()
#png(paste(fi,"_2fd.png",sep=""),height=600,width=800)
#heatCN(ta,co,cut=c(0.5,2),xt=xtext)
#dev.off()

if (type=="CMDS")
{
if (is.null(grp))
{
#-----CMDS analysis -------------------- 

cmds(tt,wsize,10)->smo

#-----CMDS drawing
par(mfrow=c(2,2))
#---correlation matrix
image(x=y[c],y=y[c],z=cor(ta),
main="Correlation Matrix",font=2,font.lab=2,
ylab=xtext, xlab=xtext)
#---transformed r
plot(smo$pos,smo$x,type="l",font=2,font.lab=2,
main="Diagonal Tranformation",ylab="Transformed  r-value", xlab=xtext) #,ylim=c(-1,5))
#---segmentation
plot(smo$pos,smo$smth,type="l",font=2,font.lab=2,
main="Segmentation",ylab="Segmented  r-value", xlab=xtext) #,ylim=c(-1,5))
#---significant region(s)
plot(smo$pos,smo$sig,type="l",font=2,font.lab=2,yaxt="n",
main="Significant Region(s)",ylab="", xlab=xtext)
}


if (!is.null(grp))
{
par(mfrow=c(2,2))
for (gi in as.character(unique(grp[,"group"])))
{
idi=grp[,"id"][as.character(grp[,"group"])==gi]

Diagonalize_Regions(ta[idi,],w=wsize,ztrans=T)->temp
temp=cbind(c(1:length(temp)),temp)
Smooth_Regions(temp,nom=1,draw=F)-> smo
smo$adj_region=smo$region
Test_Regions(smo)->smo

#---correlation matrix
#image(x=y[c],y=y[c],z=cor(ta),
#main="Correlation Matrix",font=2,font.lab=2,
#ylab=xtext, xlab=xtext)
#---transformed r
#plot(y[c][1:nrow(smo)],smo$x,type="l",font=2,font.lab=2,
#main="Diagonal Tranformation",ylab="Transformed  r-value", xlab=xtext) #,ylim=c(-1,5))
#---segmentation
plot(y[c][1:nrow(smo)],smo$smth,type="l",font=2,font.lab=2,
main=gi,ylab="Segmented  r-value", xlab=xtext) #,ylim=c(-1,5))
#---significant region(s)
#plot(y[c][1:nrow(smo)],smo$sig,type="l",font=2,font.lab=2,yaxt="n",
#main="Significant Region(s)",ylab="", xlab=xtext)
}
}

}
}

# ----------------------- STAC simulation

to.stac=function(x,cut,DIR,ID,call.method="glad")
{
if (call.method=="glad")
{
tt=numeric(0)
for (i in c(1:nrow(x)))
{
temp=x[i,]
temp=cbind(c(1:length(temp)),temp)
Smooth_Regions(temp,norm=F)[,"smth"]->temp
tt=rbind(tt,temp)
}
}
if (call.method=="thresh") tt=x
if (call.method=="msa") tt=x
tt>=cut->tt
tt=tt*1
colnames(tt)=paste(c(1:ncol(tt)),"Mb",sep="")
rownames(tt)=paste("Exp",c(1:nrow(tt)),sep="")
invisible(tt)
if (!file.exists(DIR)) dir.create(DIR)
outf=paste(DIR,"/smiu",ID,".txt",sep="")
write.table(tt,quote=F,sep="\t",file=outf)
readLines(outf)->tt
tt[1]=paste("\t",tt[1],sep="")
write.table(tt,quote=F,file=outf,row.names=F,col.names=F)
}

#----------------------- STAC results

from.stac=function(DIR,PAR)
{
#DIR=outf;#PAR=param
dir(DIR)->fs
fs=paste(DIR,fs[grep("report",fs)],sep="/")
tt=numeric(0)
for (fi in fs)
{
read.table(fi,skip=1)$V4->sig0
for (alpha in c(10^-(1:10),5*10^-(1:10),(1:10)/10))
{
sig= (sig0<=alpha)*1
Error_Of_Regions(sig,PAR)->err; B=abs(err[1,"b"]);A=abs(err[1,"a"])
tt=rbind(tt,cbind(err,B,A,alpha))
}
}
by(tt,tt[,"alpha"],colMeans,na.rm=TRUE)->ttm
tt=numeric(0); for (ai in names(ttm)) tt=rbind(tt,ttm[[ai]]) 
tt
}



###############################################
as.numeric.frame=function(x,col=NULL,fix=5)
{
x=as.data.frame(x)
if (is.null(col)) col=colnames(x)
for (coli in col) x[,coli]=as.numeric(format(as.numeric(as.character(x[,coli])),digits=fix))
x
}
##############################################

gvalues.test.old=function(x,sd.range=5,tail="two")
{
x=as.numeric(as.character(x))
sdx=abs(x-mean(x))/sd(x)
sd=(x-mean(x[sdx<sd.range]))/sd(x[sdx<sd.range])
if (tail=="two") p=2*pnorm(-abs(sd))
if (tail=="right") p=pnorm(-sd)
if (tail=="left") p=pnorm(sd)
tt=cbind(sd,p)
invisible(tt)
}


gvalues.test=function(x,sd.range=5,tail="two")
{
x=as.numeric(as.character(x))
sdx=abs(x-mean(x,na.rm=TRUE))/sd(x,na.rm=TRUE)
sd=(x-mean(x[sdx<sd.range],na.rm=TRUE))/sd(x[sdx<sd.range],na.rm=TRUE)
if (tail=="two") p=2*pnorm(-abs(sd))
if (tail=="right") p=pnorm(-sd)
if (tail=="left") p=pnorm(sd)
tt=cbind(sd,p)
invisible(tt)
}


#######################################

cmds.v1=function(x,wsize=10,wstep=1,ztrans=T,sd.range=5)
{
Diagonalize_Regions(x,wsize,wstep,ztrans)->z
gvalues.test(x=z[,"z"],sd.range=sd.range,tail="right")->zt; colnames(zt)=paste("z",colnames(zt),sep=".")
gvalues.test(x=z[,"m"],sd.range=sd.range,tail="two")->mt; colnames(mt)=paste("m",colnames(mt),sep=".")
z=cbind(z,mt,zt)
invisible(z)
}

####################################################### Diagonalize_Regions()

Diagonalize_Regions=function(x,w=30,wby=1,ztrans=TRUE)
{
n=ncol(x)
z=seq(1,(n-w),by=wby); m=z
window=c(1:length(z));start=z;mid=z+as.integer(w/2); end=z+w
for (i in window)
{
xi=x[,z[i]:(z[i]+w)]
m[i]= mean(xi,na.rm=TRUE)
ci=cor(xi,use="pairwise.complete.obs")
for (ii in c(1:dim(ci)[1])){ci[ii,ii]=NA}
if (ztrans==TRUE)
{
ci=0.5*log((1+ci)/(1-ci))
ci[abs(ci)==Inf]=NA
ci=ci*sqrt(nrow(x)-3)
}
z[i]= mean(ci,na.rm=TRUE)
}
z=cbind(window,start,mid,end,m,z)
}

################################################ cmds.focal.test(), simplified by lixiangchun
cmds.focal.test <- function(data, out.file, wsize=30, wstep=1, chromosomes=paste("chr",1:22, sep=""))
{
	for (i in 1:length(chromosomes)) {
		x <- data[data[,1] == chromosomes[i],]
		chromosome <- unique(as.character(x[,1]))
		pos <- x[,2]
		x=t(x[,-(1:2)])
		cmds.v1(x,wsize=wsize,wstep=wstep)->smo
		smo=as.numeric.frame(smo,5:10,5)
		smo[,"start"]=pos[smo[,"start"]]
		smo[,"mid"]=pos[smo[,"mid"]]
		smo[,"end"]=pos[smo[,"end"]]
		smo=cbind(chromosome,smo)
		if (i == 1) {
			r <- smo
		} else {
			r <- rbind(r, smo)
		}
	}
	r$m.p.fdr <- p.adjust(r$m.p, method="fdr")
	r$z.p.fdr <- p.adjust(r$z.p, method="fdr")
	write.table(r,file=out.file,row.names=F,quote=F,sep="\t")
	invisible(r)
}


################################################ original cmds.focal.test

cmds.focal.test2=function(
data.dir="your_data_dir",
wsize=30,
wstep=1,
analysis.ID=NA,
chr.colname="chromosome",
pos.colname="position", 
plot.dir="focal_plot",
result.dir="focal") 

{

dir.create(plot.dir,recursive=T)
dir.create(result.dir,recursive=T)
fs=dir(data.dir); if (!is.na(analysis.ID)) fs=fs[as.numeric(analysis.ID)]

for (fi in fs)
{
in.file=paste(data.dir,fi,sep="/")
out.file=paste(result.dir,"/",fi,".test",sep="")
out.image=paste(plot.dir,"/",fi,".png",sep="")

read.table(in.file,header=T)->x
chromosome=unique(as.character(x[,chr.colname]))
pos=x[,pos.colname]
x=t(x[,-(1:2)])
cmds.v1(x,wsize=wsize,wstep=wstep)->smo
smo=as.numeric.frame(smo,5:10,5)
smo[,"start"]=pos[smo[,"start"]]
smo[,"mid"]=pos[smo[,"mid"]]
smo[,"end"]=pos[smo[,"end"]]
smo=cbind(chromosome,smo)
write.table(smo,file=out.file,row.names=F,quote=F,sep="\t")
png(out.image,1024,768)
#bitmap(out.image,width=1024,height=768,units="px")
cmds.test.plot(smo);dev.off()
}

}

################################## cmds.test.plot()

cmds.test.plot=function(smo)
{
par(mfcol=c(2,2))
plot(smo[,"mid"],smo[,"m.sd"],type="l",lwd=2,main="Mean CN of All Samples",
xlab="Position",ylab="m.sd")
abline(0,0,col="red")

plot(smo[,"mid"],-log10(smo[,"m.p"]),type="l",lwd=2,main="Test of Mean (H0:m.sd=0)",
xlab="Position",ylab="-log(P)")

plot(smo[,"mid"],smo[,"z.sd"],type="l",lwd=2,main="RCNA Score",
xlab="Position", ylab="z.sd")
abline(0,0,col="red")

plot(smo[,"mid"],-log10(smo[,"z.p"]),type="l",lwd=2,main="CMDS Test (H0:z.sd=0)",
xlab="Position",ylab="-log(P)")
#abline(2,0,lty=2,col="red",lwd=2)
}

################################### plotgenome()

plotgenome = function (tt, y="p",cutoff=NULL,cutline=2,img=NULL,yscale=NULL,draw=TRUE,ltype="p",
chrom=NULL,mbp=NULL,chr.col="chromosome",pos.col="position",tombp=T)
{
colnames(tt)[grep(chr.col,colnames(tt))]="chr"
colnames(tt)[grep(pos.col,colnames(tt))]="mbp"
if (tombp) tt$mbp=tt$mbp/1000000
if (is.null(chrom)) {chrom=levels(as.factor(tt[,"chr"]));chrom=intersect(c(1:24,"X","Y","x","y"),chrom)}
if (length(mbp)==2) {tt=tt[(tt[,"mbp"]>=mbp[1] & tt[,"mbp"]<=mbp[2]),]}
if (!is.null(cutoff)) {tt[,y][tt[,y]<cutoff]=NA}
if (draw==TRUE)
{
if (length(img)>0) {png(paste(img,"png",sep="."),1200,800)}
length(chrom)->chrn
if (chrn==1){mr=1;mc=1}
if (chrn==2){mr=2;mc=1}
if (chrn==3){mr=2;mc=2}
if (chrn==4){mr=2;mc=2}
if (chrn==5){mr=2;mc=3}
if (chrn==6){mr=2;mc=3}
if (chrn==7){mr=3;mc=3}
if (chrn==8){mr=3;mc=3}
if (chrn==9){mr=3;mc=3}
if (chrn==10){mr=3;mc=4}
if (chrn==11){mr=3;mc=4}
if (chrn==12){mr=3;mc=4}
if (chrn==13){mr=3;mc=5}
if (chrn==14){mr=3;mc=5}
if (chrn==15){mr=3;mc=5}
if (chrn==16){mr=4;mc=4}
if (chrn==17){mr=4;mc=5}
if (chrn==18){mr=4;mc=5}
if (chrn==19){mr=4;mc=5}
if (chrn==20){mr=4;mc=5}
if (chrn==21){mr=4;mc=6}
if (chrn==22){mr=4;mc=6}
if (chrn==23){mr=4;mc=6}
if (chrn==24){mr=4;mc=6}
if (chrn>24){mr=5;mc=6}

par(mfrow=c(mr,mc))
for (chr in chrom )
{
tt[,"chr"]==chr->ch
tl=paste("Chrom.",chr,sep=" ")
matplot(tt[ch,"mbp"],tt[ch,y],pch=".",main=tl,xlab="Position (Mbp)",ylab=y,ylim=yscale,type=ltype)
for (ct in cutline) {abline(ct,0,col="red")}
}#chr
if (length(img)>0) {dev.off()}
}#draw

tt=tt[!is.na(tt[,y]),]
invisible(tt)
}
###############################################################################

