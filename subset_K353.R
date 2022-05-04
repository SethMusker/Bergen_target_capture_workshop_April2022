setwd("C:/Users/Seth/Google Drive/Bayreuth stuff/Bergen_workshop")


library(Biostrings)
library(dplyr)
library(tidyr)

fa_para<-readDNAStringSet("customized_reference_div_7.0_15.93.fasta")
para_df<-data.frame(name=names(fa_para),length=width(fa_para)) %>% 
  separate(name,c(NA,"ID",NA,"Contig","Sp"),remove = F,sep="_") %>% 
  mutate(Sp=gsub("-","_",Sp)) %>% 
  mutate(ID_separated=paste0(ID,"_",Contig)) %>% 
  mutate(New_name=paste(Sp,ID_separated,sep="-")) %>% 
  group_by(ID) %>% 
  mutate(Exon=as.numeric(Contig)) %>% 
  arrange(Exon,.by_group = T)
View(para_df)
# para_df
# dim(para_df)
# unique(para_df$ID) %>% length()
# unique(para_df$ID_separated) %>% length()
# unique(para_df$New_name) %>% length()
# dim(para_df)
names(fa_para)<-para_df$New_name
writeXStringSet(fa_para,"customized_reference_div_7.0_15.93.for_HybPiper_separated_exons.fasta")

apply(table(para_df[,c("Sp","ID")]),2,function(x)sum(x != 0))
i=4992
fa_temp<-fa_para[para_df[para_df$ID==i,]$New_name]
data.frame(name=names(fa_temp)) %>% separate(name,c("samp"),sep="-")
s="Pourthiaea_villosa"
fa_temp[grep(s,names(fa_temp))]

check_increasing<-as.numeric(sapply(strsplit(names(fa_temp),"_"),function(x)return(x[3])))
diff(rev(check_increasing))
any(diff(check_increasing)<1)
Reduce(c,fa_temp[grep(s,names(fa_temp))])
## concatenate exons within samples
fa_out<-list()
for(i in unique(para_df$ID)){
  fa_temp<-fa_para[para_df[para_df$ID==i,]$New_name]
  samples<-data.frame(name=names(fa_temp)) %>% separate(name,c("samp"),sep="-") %>% unique()
  samples<-samples$samp
  for(s in samples){
    fa_temp_samp<-fa_temp[grep(s,names(fa_temp))]
    check_increasing<-!any(diff(as.numeric(sapply(strsplit(names(fa_temp_samp),"_"),function(x)return(x[3])))<1))
    if(check_increasing){
      fa_out[[paste0(s,"-",i)]]<-as(Reduce(c,fa_temp_samp),"DNAStringSet")
      names(fa_out[[paste0(s,"-",i)]])<-paste0(s,"-",i)
    }else{
      stop("Contigs not in increasing order")
    }
  }
}
# fa_out

fa_para_concat<-Reduce(append,fa_out)
writeXStringSet(fa_para_concat,"customized_reference_div_7.0_15.93.for_HybPiper_concatenated_exons.fasta")

para_df_concat <- data.frame(name=names(fa_para_concat),
                             length=width(fa_para_concat)) %>% 
  separate(name,(c("Sp","ID")),remove = F,sep="-")
dim(para_df_concat)

para_df_oneSource<-para_df_concat %>% group_by(ID) %>% 
  slice_max(length)
para_df_oneSource

unique(para_df_oneSource$ID) %>% length()
dim(para_df_oneSource)

fa_para_oneSource<-fa_para_concat[para_df_oneSource$name]
fa_para_oneSource
names(fa_para_oneSource)<-para_df_oneSource$ID
writeXStringSet(fa_para_oneSource,"customized_reference_div_7.0_15.93.for_TargetVet_concatenated_exons.fasta")

write.table(para_df_oneSource[,"ID"],"genelist_PW_targets.txt",col.names = F,row.names = F,quote = F)

## make target fasta with names lacking sources. For VetHybPiper and VetTargets_genome.
fa2<-readDNAStringSet("kew_probes_Malus_exons_concat.fasta")

fa2_df<-data.frame(V1=names(fa2)) %>% 
  separate(V1,c("source","ID"),remove = F)

fa3<-fa2
names(fa3)<-fa2_df$ID
writeXStringSet(fa3,"kew_probes_Malus_exons_concat_for_TargetVet.fasta")



fa<-readDNAStringSet("Malinae-optimized_Angiosperms353.fasta")
subs<-read.table("martha_subset_genes.txt") %>% 
  separate(V1,c("source","ID"),remove = F)
  
subs$V1 %in% names(fa)
names(fa)%in%  subs$V1 

sapply(subs$ID,function(x) grep(x,names(fa)))

grep(subs$ID[1],names(fa))


fa2<-readDNAStringSet("kew_probes_Malus_exons_concat.fasta")

fa2_df<-data.frame(V1=names(fa2)) %>% 
  separate(V1,c("source","ID"),remove = F)

fa3<-fa2
names(fa3)<-fa2_df$ID
writeXStringSet(fa3,"kew_probes_Malus_exons_concat_for_TargetVet.fasta")

cbind(sort(names(fa)[1:20]),sort(names(fa2)))


fa_sub<-fa[sort(names(fa)[1:20])]
fa2_sub<-fa2[sort(names(fa2))]

fa_sub
fa2_sub

identical(width(fa_sub),width(fa2_sub))
identical(fa_sub,fa2_sub)

