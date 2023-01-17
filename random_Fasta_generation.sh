#!/bin/bash


while getopts "n:m:v" option
do
	case $option in
		n) number=$OPTARG;
		echo "Storing input for number of files in n";;
		m) numseq=$OPTARG;
		echo "Storing input for number of FASTA sequences in each file in m";;
	        v) verb= true;

esac    done		
for i in $(seq 1 $number)
do



  if [[ $verb == "true" ]];
	  then 
		  echo "Deleting seq$i.fasta file and generating new seq$i.fasta file "
  fi 		  


  rm -f seq$i.fasta




  touch seq$i.fasta



  
  for j in $(seq 1 $numseq)

    do
	    if [[ $verb -eq "true" ]];
		    then echo "Generating FASTA sequence with fasta identifier >seq${i}_$j containing a randomly generated DNA sequence of length 500"
	    fi
       echo ">seq${i}_$j" >>seq$i.fasta





       cat /dev/urandom | tr -dc 'ACGT' | fold -w 50 | head >>seq$i.fasta
 

 done

     

done

















     

 


      
    
       

  















 


