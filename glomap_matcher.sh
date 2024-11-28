#!/bin/bash
echo ""
echo "Executing colmapMatcher.sh ..."

sequence_path="$1"
exp_folder="$2" 
exp_id="$3" 
matcher_type="$4" # Options: exhaustive, sequential
use_gpu="$5"
settings_yaml="$6"
calibration_yaml="$7"
rgb_txt="$8"

exp_folder_colmap="${exp_folder}/colmap_${exp_id}"
rgb_path="${sequence_path}/$(awk '{print $2}' "${rgb_txt}" | awk -F'/' 'NR==1 {print $1}')"

calibration_model=$(grep -oP '(?<=Camera\.model:\s)[\w]+' "$calibration_yaml")

fx=$(grep -oP '(?<=Camera\.fx:\s)-?\d+\.\d+' "$calibration_yaml")
fy=$(grep -oP '(?<=Camera\.fy:\s)-?\d+\.\d+' "$calibration_yaml")
cx=$(grep -oP '(?<=Camera\.cx:\s)-?\d+\.\d+' "$calibration_yaml")
cy=$(grep -oP '(?<=Camera\.cy:\s)-?\d+\.\d+' "$calibration_yaml")

k1=$(grep -oP '(?<=Camera\.k1:\s)-?\d+\.\d+' "$calibration_yaml")
k2=$(grep -oP '(?<=Camera\.k2:\s)-?\d+\.\d+' "$calibration_yaml")
p1=$(grep -oP '(?<=Camera\.p1:\s)-?\d+\.\d+' "$calibration_yaml")
p2=$(grep -oP '(?<=Camera\.p2:\s)-?\d+\.\d+' "$calibration_yaml")
k3=$(grep -oP '(?<=Camera\.k3:\s)-?\d+\.\d+' "$calibration_yaml")
k4=0.0
k5=0.0
k6=0.0

# Reading settings from yaml file
feature_extractor_SiftExtraction_num_octaves=$(yq '.feature_extractor.SiftExtraction_num_octaves // 4.0' $settings_yaml)
feature_extractor_SiftExtraction_octave_resolution=$(yq '.feature_extractor.SiftExtraction_octave_resolution // 3.0' $settings_yaml)
feature_extractor_SiftExtraction_peak_threshold=$(yq '.feature_extractor.SiftExtraction_peak_threshold // 0.0066666666666666671' $settings_yaml)
feature_extractor_SiftExtraction_edge_threshold=$(yq '.feature_extractor.SiftExtraction_edge_threshold // 10.0' $settings_yaml)
feature_extractor_SiftExtraction_dsp_min_scale=$(yq '.feature_extractor.SiftExtraction_dsp_min_scale // 0.1666666666666666' $settings_yaml)
feature_extractor_SiftExtraction_dsp_max_scale=$(yq '.feature_extractor.SiftExtraction_dsp_max_scale // 3.0' $settings_yaml)
feature_extractor_SiftExtraction_dsp_num_scales=$(yq '.feature_extractor.SiftExtraction_dsp_num_scales // 10.0' $settings_yaml)

matcher_SiftMatching_max_ratio=$(yq '.matcher.SiftMatching_max_ratio // 0.80000000000000004' $settings_yaml)
matcher_SiftMatching_max_distance=$(yq '.matcher.SiftMatching_max_distance // 0.69999999999999996' $settings_yaml)
matcher_TwoViewGeometry_min_num_inliers=$(yq '.matcher.TwoViewGeometry_min_num_inliers // 15.0' $settings_yaml)
matcher_TwoViewGeometry_max_error=$(yq '.matcher.TwoViewGeometry_max_error // 4.0' $settings_yaml)
matcher_TwoViewGeometry_confidence=$(yq '.matcher.TwoViewGeometry_confidence // 0.999' $settings_yaml)
matcher_TwoViewGeometry_min_inlier_ratio=$(yq '.matcher.TwoViewGeometry_min_inlier_ratio // 0.25' $settings_yaml)
matcher_SequentialMatching_overlap=$(yq '.matcher.SequentialMatching_overlap // 10.0' $settings_yaml)
matcher_SequentialMatching_quadratic_overlap=$(yq '.matcher.SequentialMatching_quadratic_overlap // 1.0' $settings_yaml)
matcher_ExhaustiveMatching_block_size=$(yq '.matcher.ExhaustiveMatching_block_size // 50.0' $settings_yaml)

# Create colmap image list
colmap_image_list="${exp_folder_colmap}/colmap_image_list.txt"
awk '{split($2, arr, "/"); print arr[2]}' "$rgb_txt" > "$colmap_image_list"

# Create Colmap Database
database="${exp_folder_colmap}/colmap_database.db"
rm -rf ${database}
pixi run -e colmap colmap database_creator --database_path ${database}

################################################################################
echo "    colmap feature_extractor ..."

if [ "${calibration_model}" == "UNKNOWN" ]
then
 echo "        camera model : $calibration_model"
   pixi run -e colmap colmap feature_extractor \
   --database_path ${database} \
   --image_path ${rgb_path} \
   --image_list_path ${colmap_image_list} \
   --ImageReader.camera_model SIMPLE_PINHOLE \
   --ImageReader.single_camera 1 \
   --ImageReader.single_camera_per_folder 1 \
   --SiftExtraction.use_gpu ${use_gpu} \
   --SiftExtraction.num_octaves ${feature_extractor_SiftExtraction_num_octaves} \
   --SiftExtraction.octave_resolution ${feature_extractor_SiftExtraction_octave_resolution} \
   --SiftExtraction.peak_threshold ${feature_extractor_SiftExtraction_peak_threshold} \
   --SiftExtraction.edge_threshold ${feature_extractor_SiftExtraction_edge_threshold} \
   --SiftExtraction.dsp_min_scale ${feature_extractor_SiftExtraction_dsp_min_scale} \
   --SiftExtraction.dsp_max_scale ${feature_extractor_SiftExtraction_dsp_max_scale} \
   --SiftExtraction.dsp_num_scales ${feature_extractor_SiftExtraction_dsp_num_scales}
fi

feature_extractor_SiftExtraction_dsp_num_scales=$(yq '.feature_extractor.SiftExtraction_dsp_num_scales // 10.0' $settings_yaml)


if [ "${calibration_model}" == "PINHOLE" ]
then
  echo "        camera model : $calibration_model"
	pixi run -e colmap colmap feature_extractor \
	--database_path ${database} \
	--image_path ${rgb_path} \
	--image_list_path ${colmap_image_list} \
	--ImageReader.camera_model ${calibration_model} \
	--ImageReader.single_camera 1 \
	--ImageReader.single_camera_per_folder 1 \
	--SiftExtraction.use_gpu ${use_gpu} \
	--ImageReader.camera_params "${fx}, ${fy}, ${cx}, ${cy}" \
  --SiftExtraction.num_octaves ${feature_extractor_SiftExtraction_num_octaves} \
  --SiftExtraction.octave_resolution ${feature_extractor_SiftExtraction_octave_resolution} \
  --SiftExtraction.peak_threshold ${feature_extractor_SiftExtraction_peak_threshold} \
  --SiftExtraction.edge_threshold ${feature_extractor_SiftExtraction_edge_threshold} \
  --SiftExtraction.dsp_min_scale ${feature_extractor_SiftExtraction_dsp_min_scale} \
  --SiftExtraction.dsp_max_scale ${feature_extractor_SiftExtraction_dsp_max_scale} \
  --SiftExtraction.dsp_num_scales ${feature_extractor_SiftExtraction_dsp_num_scales}
fi

if [ "${calibration_model}" == "OPENCV" ]
then
  echo "        camera model : $calibration_model"
	pixi run -e colmap colmap feature_extractor \
	--database_path ${database} \
	--image_path ${rgb_path} \
	--image_list_path ${colmap_image_list} \
	--ImageReader.camera_model ${calibration_model} \
	--ImageReader.single_camera 1 \
	--ImageReader.single_camera_per_folder 1 \
	--SiftExtraction.use_gpu ${use_gpu} \
	--ImageReader.camera_params "${fx}, ${fy}, ${cx}, ${cy}, ${k1}, ${k2}, ${p1}, ${p2}" \
  --SiftExtraction.num_octaves ${feature_extractor_SiftExtraction_num_octaves} \
  --SiftExtraction.octave_resolution ${feature_extractor_SiftExtraction_octave_resolution} \
  --SiftExtraction.peak_threshold ${feature_extractor_SiftExtraction_peak_threshold} \
  --SiftExtraction.edge_threshold ${feature_extractor_SiftExtraction_edge_threshold} \
  --SiftExtraction.dsp_min_scale ${feature_extractor_SiftExtraction_dsp_min_scale} \
  --SiftExtraction.dsp_max_scale ${feature_extractor_SiftExtraction_dsp_max_scale} \
  --SiftExtraction.dsp_num_scales ${feature_extractor_SiftExtraction_dsp_num_scales}
fi

if [ "${calibration_model}" == "OPENCV_FISHEYE" ] 
then
  echo "        camera model : $calibration_model"
	pixi run -e colmap colmap feature_extractor \
	--database_path ${database} \
	--image_path ${rgb_path} \
	--image_list_path ${colmap_image_list} \
	--ImageReader.camera_model ${calibration_model} \
	--ImageReader.single_camera 1 \
	--ImageReader.single_camera_per_folder 1 \
	--SiftExtraction.use_gpu ${use_gpu} \
	--ImageReader.camera_params "${fx}, ${fy}, ${cx}, ${cy}, ${k1}, ${k2}, ${k3}, ${k4}" \
  --SiftExtraction.num_octaves ${feature_extractor_SiftExtraction_num_octaves} \
  --SiftExtraction.octave_resolution ${feature_extractor_SiftExtraction_octave_resolution} \
  --SiftExtraction.peak_threshold ${feature_extractor_SiftExtraction_peak_threshold} \
  --SiftExtraction.edge_threshold ${feature_extractor_SiftExtraction_edge_threshold} \
  --SiftExtraction.dsp_min_scale ${feature_extractor_SiftExtraction_dsp_min_scale} \
  --SiftExtraction.dsp_max_scale ${feature_extractor_SiftExtraction_dsp_max_scale} \
  --SiftExtraction.dsp_num_scales ${feature_extractor_SiftExtraction_dsp_num_scales}
fi

################################################################################
if [ "${matcher_type}" == "exhaustive" ]
then
	echo "    colmap exhaustive_matcher ..."
  pixi run -e colmap colmap exhaustive_matcher \
     --database_path ${database} \
     --SiftMatching.use_gpu ${use_gpu} \
     --SiftMatching.max_ratio "${matcher_SiftMatching_max_ratio}" \
     --SiftMatching.max_distance "${matcher_SiftMatching_max_distance}" \
     --TwoViewGeometry.min_num_inliers "${matcher_TwoViewGeometry_min_num_inliers}" \
     --TwoViewGeometry.max_error "${matcher_TwoViewGeometry_max_error}" \
     --TwoViewGeometry.confidence "${matcher_TwoViewGeometry_confidence}" \
     --TwoViewGeometry.min_inlier_ratio "${matcher_TwoViewGeometry_min_inlier_ratio}" \
     --ExhaustiveMatching.block_size "${matcher_ExhaustiveMatching_block_size}"

fi

if [ "${matcher_type}" == "sequential" ]
then
  num_rgb=$(wc -l < ${rgb_txt})

  # Pick vocabulary tree based on the number of images
  vocabulary_tree="Baselines/colmap/vocab_tree_flickr100K_words32K.bin"
  if [ "$num_rgb" -gt 1000 ]; then
    vocabulary_tree="Baselines/colmap/vocab_tree_flickr100K_words256K.bin"
  fi
  if [ "$num_rgb" -gt 10000 ]; then
    vocabulary_tree="Baselines/colmap/vocab_tree_flickr100K_words1M.bin"
  fi

  echo "    colmap sequential_matcher ..."
  echo "        Vocabulary Tree: $vocabulary_tree"
      pixi run -e colmap colmap sequential_matcher \
         --database_path "${database}" \
         --SequentialMatching.loop_detection 1 \
         --SequentialMatching.vocab_tree_path ${vocabulary_tree} \
         --SiftMatching.use_gpu "${use_gpu}" \
         --SiftMatching.max_ratio "${matcher_SiftMatching_max_ratio}" \
         --SiftMatching.max_distance "${matcher_SiftMatching_max_distance}" \
         --TwoViewGeometry.min_num_inliers "${matcher_TwoViewGeometry_min_num_inliers}" \
         --TwoViewGeometry.max_error "${matcher_TwoViewGeometry_max_error}" \
         --TwoViewGeometry.confidence "${matcher_TwoViewGeometry_confidence}" \
         --TwoViewGeometry.min_inlier_ratio "${matcher_TwoViewGeometry_min_inlier_ratio}" \
         --SequentialMatching.overlap "${matcher_SequentialMatching_overlap}" \
         --SequentialMatching.quadratic_overlap "${matcher_SequentialMatching_quadratic_overlap}"
fi