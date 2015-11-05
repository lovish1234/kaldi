#/bin/bash

# Takes the TIMIT database directory and
# introcudes blank symbol after every phone
# in the corpus. 


if [ $# -ne 1 ]; then
   echo "Argument should be the Timit directory, see ../run.sh for example."
   exit 1;
fi

. ./path.sh
export PATH=$PATH:$KALDI_ROOT/tools/irstlm/bin
sph2pipe=$KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe
if [ ! -x $sph2pipe ]; then
   echo "Could not find (or execute) the sph2pipe program at $sph2pipe";
   exit 1;
fi


if [ ! -d $*/TRAIN ] && [ ! -d $*/train -o ]; then
	echo " introduce_blank_symbol.sh: Spot check of command line argument
	failed." 
	echo " Command line argument must be absolute pathname to TIMIT directory "
	exit 1;
fi	

dir=`pwd`/data-blank/local/data
lmdir=`pwd`/data-blank/local/nist_lm
mkdir -p $dir $lmdir
local=`pwd`/local
conf=`pwd`/conf
utils=`pwd`/utils


# Now check what case the directory structure is
uppercased=false
train_dir=train
test_dir=test

train_blank=train_blank
test_blank=test_blank

if [ -d $*/TRAIN ]; then

  uppercased=true
  train_dir=TRAIN
  test_dir=TEST

  train_blank=TRAIN_BLANK
  test_blank=TEST_BLANK

fi

tmpdir=$(mktemp -d /tmp/kaldi.XXXX);
#mkdir -p $*$train_blank $*$test_blank
#trap 'rm -rf "$tmpdir"' EXIT




# Get the list of speakers. The list of speakers in the 24-speaker core test 
# set and the 50-speaker development set must be supplied to the script. All
# speakers in the 'train' directory are used for training.
if $uppercased; then
  tr '[:lower:]' '[:upper:]' < $conf/dev_spk.list > $tmpdir/dev_spk
  tr '[:lower:]' '[:upper:]' < $conf/test_spk.list > $tmpdir/test_spk
  ls -d "$*"/TRAIN/DR*/* | sed -e "s:^.*/::" > $tmpdir/train_spk
else
  tr '[:upper:]' '[:lower:]' < $conf/dev_spk.list > $tmpdir/dev_spk
  tr '[:upper:]' '[:lower:]' < $conf/test_spk.list > $tmpdir/test_spk
  ls -d "$*"/train/dr*/* | sed -e "s:^.*/::" > $tmpdir/train_spk
fi

#trap 'rm -rf "$tmpdir"' EXIT

cd $dir


for x in train dev test; do


  # First, find the list of audio files (use only si & sx utterances).
  # Note: train & test sets are under different directories, but doing find on 
  # both and grepping for the speakers will work correctly.
  find $*/{$train_dir,$test_dir} -iname '*.WAV' \
    | grep -f $tmpdir/${x}_spk > ${x}_sph.flist

  sed -e 's:.*/\(.*\)/\(.*\).WAV$:\1_\2:i' ${x}_sph.flist \
    > $tmpdir/${x}_sph.uttids
  paste $tmpdir/${x}_sph.uttids ${x}_sph.flist \
    | sort -k1,1 > ${x}_sph.scp

  cat ${x}_sph.scp | awk '{print $1}' > ${x}.uttids


  # Now, Convert the transcripts into our format (no normalization yet)
  # Get the transcripts: each line of the output contains an utterance 
  # ID followed by the transcript.
    
	find $*/{$train_dir,$test_dir}  -iname '*.PHN' | grep -f $tmpdir/${x}_spk > $tmpdir/${x}_phn.flist

    sed -e 's:.*/\(.*\)/\(.*\).PHN$:\1_\2:i' $tmpdir/${x}_phn.flist > $tmpdir/${x}_phn.uttids
 
	# Find the list of phone files. This will have (Start Time, End Time and
	# phone occurance. Introduce the blank phone at a random time between start
	# and end of previous phone and end the blank phone at a random time
	# between start and end of next phone.
	#find $*$train_dir -iname '*.PHN' > $tmpdir/${x}_phn.flist
    while read line; do
		[ -f $line ] || error_exit "Cannot find transcription file	'$line'";
        
		# Naming conversion to change a database with blank symbol 


		#	cut -f3 -d' ' "$line" | tr '\n' ' ' | sed -e 's: *$:\n:'
    	#done < $tmpdir/${x}_phn.flist > $tmpdir/${x}_phn.trans

    	# Blank symbol begins at a random time stamp between start and end of phone. 
	    cat "$line" | awk '{ print $1, int($1 + ($2-$1)*rand()), $2, $3 }' | awk '{ print $1, $2, $2, 
		$3, $4 }' | awk '{ print $1,$2,$5}{ print $3,$4,"BL"}'|  cut -f3 -d' '| tr '\n' ' ' | sed -e 's: *$:\n:'


	done < $tmpdir/${x}_phn.flist > ${x}_phn.trans
    
	# attach with the Utterance ID
    paste $tmpdir/${x}_phn.uttids ${x}_phn.trans \
    | sort -k1,1 > ${x}.trans

  # rest same as local/timit_data_prep.sh
  # Do normalization steps. Map the 60 phonemes to a smaller set of 48 phonemes
  cat ${x}.trans | $local/timit_norm_trans.pl -i - -m $conf/phones.60-48-39.map -to 48 | sort > $x.text || exit 1;

  # Create wav.scp
  awk '{printf("%s '$sph2pipe' -f wav %s |\n", $1, $2);}' < ${x}_sph.scp > ${x}_wav.scp

  # Make the utt2spk and spk2utt files.
  cut -f1 -d'_'  $x.uttids | paste -d' ' $x.uttids - > $x.utt2spk
  echo $x.spk2utt 
  cat $x.utt2spk | $utils/utt2spk_to_spk2utt.pl > $x.spk2utt || exit 1;

  # Prepare gender mapping
  cat $x.spk2utt | awk '{print $1}' | perl -ane 'chop; m:^.:; $g = lc($&); print "$_ $g\n";' > $x.spk2gender

  # Prepare STM file for sclite:
  wav-to-duration scp:${x}_wav.scp ark,t:${x}_dur.ark || exit 1
  awk -v dur=${x}_dur.ark \
  'BEGIN{ 
     while(getline < dur) { durH[$1]=$2; } 
     print ";; LABEL \"O\" \"Overall\" \"Overall\"";
     print ";; LABEL \"F\" \"Female\" \"Female speakers\"";
     print ";; LABEL \"M\" \"Male\" \"Male speakers\""; 
   } 
   { wav=$1; spk=gensub(/_.*/,"",1,wav); $1=""; ref=$0;
     gender=(substr(spk,0,1) == "f" ? "F" : "M");
     printf("%s 1 %s 0.0 %f <O,%s> %s\n", wav, spk, durH[wav], gender, ref);
   }
  ' ${x}.text >${x}.stm || exit 1

  # Create dummy GLM file for sclite:
  echo ';; empty.glm
  [FAKE]     =>  %HESITATION     / [ ] __ [ ] ;; hesitation token
  ' > ${x}.glm

done





