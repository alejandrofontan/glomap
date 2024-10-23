#!/bin/bash

DIVISOR="10"

# Function to split key-value pairs and assign them to variables
max_rgb="50" # Default value. Can be overwritten "max_rgb:500"
matcher_type="exhaustive" # Default value. Options: exhaustive, sequential
use_gpu="1" # Default value.
verbose="0"
settings_yaml="Baselines/glomap/glomap_settings.yaml"

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
echo "max_rgb: $max_rgb"
echo "matcher_type: $matcher_type"
echo "use_gpu: $use_gpu"
echo "settings_yaml: $settings_yaml"
echo "calibration_yaml: $calibration_yaml"
echo "rgb_txt: $rgb_txt"

# Calculate the minimum frames per second (fps) for downsampling
fps=$(grep -oP '(?<=Camera\.fps:\s)-?\d+\.\d+' "$calibration_yaml")
min_fps=$(echo "scale=2; $fps / ${DIVISOR}" | bc)

exp_folder_colmap="${exp_folder}/colmap_${exp_id}"
rm -rf "$exp_folder_colmap"
mkdir "$exp_folder_colmap"

# Run COLMAP scripts for matching and mapping
pixi run -e colmap ./Baselines/glomap/glomap_matcher.sh $sequence_path $exp_folder $exp_id $matcher_type $use_gpu ${settings_yaml} ${calibration_yaml} ${rgb_txt}
pixi run -e colmap ./Baselines/glomap/glomap_mapper.sh $sequence_path $exp_folder $exp_id ${verbose} ${settings_yaml} ${calibration_yaml} ${rgb_txt}

# Convert COLMAP outputs to a format suitable for VSLAM-Lab
python Baselines/glomap/colmap_to_vslamlab.py $sequence_path $exp_folder $exp_id $verbose $rgb_txt

rm -rf ${exp_folder_colmap}


