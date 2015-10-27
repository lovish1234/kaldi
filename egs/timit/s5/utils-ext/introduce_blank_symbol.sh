#/bin/bash

# Takes the TIMIT database directory and
# introcudes blank symbol after every phone
# in the corpus. 


if [ $# -ne 1 ]; then
   echo "Argument should be the Timit directory, see ../run.sh for example."
   exit 1;
fi

. ./path.sh

if [ ! -d $*/TRAIN ] && [ ! -d $*/train -o ]; then
	echo " introduce_blank_symbol.sh: Spot check of command line argument
	failed." 
	echo " Command line argument must be absolute pathname to TIMIT directory "
	exit 1;
fi	



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
mkdir -p $*$train_blank $*$test_blank




# Get the list of speakers. The list of speakers in the 24-speaker core test 
# set and the 50-speaker development set must be supplied to the script. All
# speakers in the 'train' directory are used for training.
if $uppercased; then
#  tr '[:lower:]' '[:upper:]' < $conf/dev_spk.list > $tmpdir/dev_spk
#  tr '[:lower:]' '[:upper:]' < $conf/test_spk.list > $tmpdir/test_spk
  ls -d "$*"/TRAIN/DR*/* | sed -e "s:^.*/::" > $tmpdir/train_spk
else
#  tr '[:upper:]' '[:lower:]' < $conf/dev_spk.list > $tmpdir/dev_spk
#  tr '[:upper:]' '[:lower:]' < $conf/test_spk.list > $tmpdir/test_spk
  ls -d "$*"/train/dr*/* | sed -e "s:^.*/::" > $tmpdir/train_spk
fi


for x in train; do


  # Now, Convert the transcripts into our format (no normalization yet)
  # Get the transcripts: each line of the output contains an utterance 
  # ID followed by the transcript.
    
	find $*/$train_dir  -iname '*.PHN' | grep -f $tmpdir/${x}_spk > $tmpdir/${x}_phn_blank.flist

    sed -e 's:.*/\(.*\)/\(.*\).PHN$:\1_\2:i' $tmpdir/${x}_phn_blank.flist > $tmpdir/${x}_phn.uttids
 
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


	done < $tmpdir/${x}_phn_blank.flist > $*$train_blank/${x}_phn_blank.trans
    
	# attach with the Utterance ID
    paste $tmpdir/${x}_phn.uttids $*$train_blank/${x}_phn_blank.trans \
    | sort -k1,1 > ${x}.trans


done





