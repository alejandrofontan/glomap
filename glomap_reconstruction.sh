#!/bin/bash

# Function to split key-value pairs and assign them to variables
matcher_type="exhaustive"
use_gpu="1"
verbose="0"
settings_yaml=""

split_and_assign() {
  local input=$1
  local key=$(echo $input | cut -d':' -f1)
  local value=$(echo $input | cut -d':' -f2-)
  eval $key=$value
}

# Split the input string into individual components
for ((i=1; i<=$#; i++)); do
    split_and_assign "${!i}"
done

exp_id=$(printf "%05d" ${exp_id})

echo "Sequence Path: $sequence_path"
echo "Experiment Folder: $exp_folder"
echo "Experiment ID: $exp_id"
echo "Verbose: $verbose"
echo "matcher_type: $matcher_type"
echo "use_gpu: $use_gpu"
echo "settings_yaml: $settings_yaml"
echo "calibration_yaml: $calibration_yaml"
echo "rgb_txt: $rgb_txt"

exp_folder_colmap="${exp_folder}/colmap_${exp_id}"
rm -rf "$exp_folder_colmap"
mkdir "$exp_folder_colmap"

# Run COLMAP scripts for matching and mapping
pixi run -e glomap ./Baselines/glomap/glomap_matcher.sh $sequence_path $exp_folder $exp_id $matcher_type $use_gpu ${settings_yaml} ${calibration_yaml} ${rgb_txt}
pixi run -e glomap ./Baselines/glomap/glomap_mapper.sh $sequence_path $exp_folder $exp_id ${verbose} ${settings_yaml} ${calibration_yaml} ${rgb_txt}

# Convert COLMAP outputs to a format suitable for VSLAM-Lab
python Baselines/glomap/colmap_to_vslamlab.py $sequence_path $exp_folder $exp_id $verbose $rgb_txt

# Get colmap stats
colmap_stats_csv="${exp_folder}/${exp_id}_colmap_stats.csv"
if [[ ! -f "$colmap_stats_csv" ]]; then
  echo "File,Cameras,Images,Registered Images,Points,Observations,Mean Track Length,Mean Observations per Image,Mean Reprojection Error" > "$colmap_stats_csv"
fi
colmap_stats=$(pixi run -e colmap colmap model_analyzer --path "$exp_folder_colmap" 2>&1)
cameras=$(echo "$colmap_stats" | grep -oP "(?<=Cameras: )\d+")
images=$(echo "$colmap_stats" | grep -oP "(?<=Images: )\d+")
registered_images=$(echo "$colmap_stats" | grep -oP "(?<=Registered images: )\d+")
points=$(echo "$colmap_stats" | grep -oP "(?<=Points: )\d+")
observations=$(echo "$colmap_stats" | grep -oP "(?<=Observations: )\d+")
mean_track_length=$(echo "$colmap_stats" | grep -oP "(?<=Mean track length: )\d+\.\d+")
mean_observations_per_image=$(echo "$colmap_stats" | grep -oP "(?<=Mean observations per image: )\d+\.\d+")
mean_reprojection_error=$(echo "$colmap_stats" | grep -oP "(?<=Mean reprojection error: )\d+\.\d+")
echo "$exp_folder_colmap,${cameras:-0},${images:-0},${registered_images:-0},${points:-0},${observations:-0},${mean_track_length:-0},${mean_observations_per_image:-0},${mean_reprojection_error:-0}" >> "$colmap_stats_csv"

# Remove colmap data
rm -rf ${exp_folder_colmap}


