

timit=/home/love/kaldi/data/timit/TIMIT

# this script organizes the metadata of the below data.
utils-ext/introduce_blank_symbol.sh $timit || exit 1

#gets the phone to word mapping from training corpus.
utils-ext/timit_prepare_dict.sh

# Caution below: we remove optional silence by setting "--sil-prob 0.0",
# in TIMIT the silence appears also as a word in the dictionary and is scored.
utils-ext/prepare_lang.sh --sil-prob 0.0 --position-dependent-phones false --num-sil-states 3 \
 data-blank/local/dict "sil" data-blank/local/lang_tmp data-blank/lang

utils-ext/timit_format_data.sh


