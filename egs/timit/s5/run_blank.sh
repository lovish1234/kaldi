

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




# Now make MFCC features.
mfccdir=mfcc-blank
train_cmd="run.pl"
feats_nj=10

decode_cmd="run.pl"
decode_nj=5
train_nj=30


for x in train dev test; do 
  steps/make_mfcc.sh --cmd "$train_cmd" --nj $feats_nj data-blank/$x exp-blank/make_mfcc/$x $mfccdir
  steps/compute_cmvn_stats.sh data-blank/$x exp-blank/make_mfcc/$x $mfccdir
done

echo ============================================================================
echo "                     MonoPhone Training & Decoding                        "
echo ============================================================================


steps/train_mono.sh  --nj "$train_nj" --cmd "$train_cmd" data-blank/train data-blank/lang exp-blank/mono

utils/mkgraph.sh --mono data-blank/lang_test_bg exp-blank/mono exp-blank/mono/graph

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp-blank/mono/graph data-blank/dev exp-blank/mono/decode_dev

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp-blank/mono/graph data-blank/test exp-blank/mono/decode_test
 
 
echo ============================================================================
echo "           tri1 : Deltas + Delta-Deltas Training & Decoding               "
echo ============================================================================
 

steps/align_si.sh --boost-silence 1.25 --nj "$train_nj" --cmd "$train_cmd" \
 data-blank/train data-blank/lang exp-blank/mono exp-blank/mono_ali

numLeavesTri1=2500
numGaussTri1=15000


# Train tri1, which is deltas + delta-deltas, on train data.
steps/train_deltas.sh --cmd "$train_cmd" \
 $numLeavesTri1 $numGaussTri1 data-blank/train data-blank/lang exp-blank/mono_ali exp-blank/tri1

utils/mkgraph.sh data-blank/lang_test_bg exp-blank/tri1 exp-blank/tri1/graph

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp-blank/tri1/graph data/dev exp-blank/tri1/decode_dev

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp-blank/tri1/graph data-blank/test exp-blank/tri1/decode_test
 
echo ============================================================================
echo "                 tri2 : LDA + MLLT Training & Decoding                    "
echo ============================================================================


 
 steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
  data-blank/train data-blank/lang exp-blank/tri1 exp-blank/tri1_ali

numLeavesMLLT=2500
numGaussMLLT=15000

steps/train_lda_mllt.sh --cmd "$train_cmd" \
 --splice-opts "--left-context=3 --right-context=3" \
 $numLeavesMLLT $numGaussMLLT data-blank/train data-blank/lang exp-blank/tri1_ali exp-blank/tri2

utils/mkgraph.sh data-blank/lang_test_bg exp-blank/tri2 exp-blank/tri2/graph

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp-blank/tri2/graph data-blank/dev exp-blank/tri2/decode_dev

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp-blank/tri2/graph data-blank/test exp-blank/tri2/decode_test
 
 

echo ============================================================================
echo "              tri3 : LDA + MLLT + Speaker Adaptive Transform Training & Decoding                 "
echo ============================================================================
 
 
 # Align tri2 system with train data.
steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
 --use-graphs true data-blank/train data-blank/lang exp-blank/tri2 exp-blank/tri2_ali

numLeavesSAT=2500
numGaussSAT=15000

# From tri2 system, train tri3 which is LDA + MLLT + SAT.
steps/train_sat.sh --cmd "$train_cmd" \
 $numLeavesSAT $numGaussSAT data-blank/train data-blank/lang exp-blank/tri2_ali exp-blank/tri3

utils/mkgraph.sh data-blank/lang_test_bg exp-blank/tri3 exp-blank/tri3/graph

steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp-blank/tri3/graph data-blank/dev exp-blank/tri3/decode_dev

steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp-blank/tri3/graph data-blank/test exp-blank/tri3/decode_test
 
echo ============================================================================
echo "                        SGMM2 Training & Decoding                         "
echo ============================================================================

 
 steps/align_fmllr.sh --nj "$train_nj" --cmd "$train_cmd" \
 data-blank/train data-blank/lang exp-blank/tri3 exp-blank/tri3_ali

#exit 0 # From this point you can run Karel's DNN : local/nnet/run_dnn.sh 

numGaussUBM=400
numLeavesSGMM=7000
numGaussSGMM=9000

steps/train_ubm.sh --cmd "$train_cmd" \
 $numGaussUBM data-blank/train data-blank/lang exp-blank/tri3_ali exp-blank/ubm4

steps/train_sgmm2.sh --cmd "$train_cmd" $numLeavesSGMM $numGaussSGMM \
 data-blank/train data-blank/lang exp-blank/tri3_ali exp-blank/ubm4/final.ubm exp-blank/sgmm2_4

utils/mkgraph.sh data-blank/lang_test_bg exp-blank/sgmm2_4 exp-blank/sgmm2_4/graph

steps/decode_sgmm2.sh --nj "$decode_nj" --cmd "$decode_cmd"\
 --transform-dir exp-blank/tri3/decode_dev exp-blank/sgmm2_4/graph data-blank/dev \
 exp-blank/sgmm2_4/decode_dev

steps/decode_sgmm2.sh --nj "$decode_nj" --cmd "$decode_cmd"\
 --transform-dir exp-blank/tri3/decode_test exp-blank/sgmm2_4/graph data-blank/test \
 exp-blank/sgmm2_4/decode_test
 
 


echo ============================================================================
echo "                    MMI + SGMM2 Training & Decoding                       "
echo ============================================================================

steps/align_sgmm2.sh --nj "$train_nj" --cmd "$train_cmd" \
 --transform-dir exp/tri3_ali --use-graphs true --use-gselect true \
 data-blank/train data-blank/lang exp-blank/sgmm2_4 exp-blank/sgmm2_4_ali

steps/make_denlats_sgmm2.sh --nj "$train_nj" --sub-split "$train_nj" \
 --acwt 0.2 --lattice-beam 10.0 --beam 18.0 \
 --cmd "$decode_cmd" --transform-dir exp-blank/tri3_ali \
 data-blank/train data-blank/lang exp-blank/sgmm2_4_ali exp-blank/sgmm2_4_denlats

steps/train_mmi_sgmm2.sh --acwt 0.2 --cmd "$decode_cmd" \
 --transform-dir exp/tri3_ali --boost 0.1 --drop-frames true \
 data-blank/train data-blank/lang exp-blank/sgmm2_4_ali exp-blank/sgmm2_4_denlats exp-blank/sgmm2_4_mmi_b0.1

for iter in 1 2 3 4; do
  steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
   --transform-dir exp-blank/tri3/decode_dev data-blank/lang_test_bg data-blank/dev f\
   exp-blank/sgmm2_4/decode_dev exp-blank/sgmm2_4_mmi_b0.1/decode_dev_it$iter

  steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
   --transform-dir exp-blank/tri3/decode_test data-blank/lang_test_bg data-blank/test \
   exp-blank/sgmm2_4/decode_test exp-blank/sgmm2_4_mmi_b0.1/decode_test_it$iter
done

echo ============================================================================
echo "                    DNN Hybrid Training & Decoding                        "
echo ============================================================================

# DNN hybrid system training parameters
dnn_mem_reqs="--mem 1G"
dnn_extra_opts="--num_epochs 20 --num-epochs-extra 10 --add-layers-period 1 --shrink-interval 3"

steps/nnet2/train_tanh.sh --mix-up 5000 --initial-learning-rate 0.015 \
  --final-learning-rate 0.002 --num-hidden-layers 2  \
  --num-jobs-nnet "$train_nj" --cmd "$train_cmd" "${dnn_train_extra_opts[@]}" \
  data-blank/train data-blank/lang exp-blank/tri3_ali exp-blank/tri4_nnet

[ ! -d exp-blank/tri4_nnet/decode_dev ] && mkdir -p exp-blank/tri4_nnet/decode_dev
decode_extra_opts=(--num-threads 6)
steps/nnet2/decode.sh --cmd "$decode_cmd" --nj "$decode_nj" "${decode_extra_opts[@]}" \
  --transform-dir exp-blank/tri3/decode_dev exp-blank/tri3/graph data-blank/dev \
  exp-blank/tri4_nnet/decode_dev | tee exp-blank/tri4_nnet/decode_dev/decode.log

[ ! -d exp-blank/tri4_nnet/decode_test ] && mkdir -p exp-blank/tri4_nnet/decode_test
steps/nnet2/decode.sh --cmd "$decode_cmd" --nj "$decode_nj" "${decode_extra_opts[@]}" \
  --transform-dir exp-blank/tri3/decode_test exp-blank/tri3/graph data-blank/test \
  exp-blank/tri4_nnet/decode_test | tee exp-blank/tri4_nnet/decode_test/decode.log

echo ============================================================================
echo "                    System Combination (DNN+SGMM)                         "
echo ============================================================================

for iter in 1 2 3 4; do
  local/score_combine.sh --cmd "$decode_cmd" \
   data-blank/dev data-blank/lang_test_bg exp-blank/tri4_nnet/decode_dev \
   exp-blank/sgmm2_4_mmi_b0.1/decode_dev_it$iter exp-blank/combine_2/decode_dev_it$iter

  local/score_combine.sh --cmd "$decode_cmd" \
   data-blank/test data-blank/lang_test_bg exp-blank/tri4_nnet/decode_test \
   exp-blank/sgmm2_4_mmi_b0.1/decode_test_it$iter exp-blank/combine_2/decode_test_it$iter
done

echo ============================================================================
echo "               DNN Hybrid Training & Decoding (Karel's recipe)            "
echo ============================================================================

local/nnet/run_dnn.sh
#local/nnet/run_autoencoder.sh : an example, not used to build any system,

echo ============================================================================
echo "                    Getting Results [see RESULTS file]                    "
echo ============================================================================

bash RESULTS dev
bash RESULTS test

echo ============================================================================
echo "Finished successfully on" `date`
echo ============================================================================

exit 0


