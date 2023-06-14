#!/bin/bash -ex

# Create the deploy/docker-compose files for each version of each of the Quarkus services
# Then add on the ui-super-heroes

INPUT_DIR=src/main/docker-compose
OUTPUT_DIR=deploy/docker-compose

create_output_file() {
  local output_file=$1

  echo "Creating output file: $output_file"

  touch $output_file
  echo 'version: "3"' >> $output_file
  echo 'services:' >> $output_file
}

create_project_output() {
  local project=$1
  local filename=$2
  local versionFilename=$3
  local infra_input_file_name="infra.yml"
  local infra_input_file="$project/$INPUT_DIR/$infra_input_file_name"
  local input_file_name="${filename}.yml"
  local version_file_name="${versionFilename}.yml"
  local all_apps_output_file="$OUTPUT_DIR/$version_file_name"
  local project_input_file="$project/$INPUT_DIR/$input_file_name"
  local project_output_file="$project/$OUTPUT_DIR/$input_file_name"

  echo ""
  echo "-----------------------------------------"
  echo "Creating output for project = $project filename = $filename version_file_name = $version_file_name"

  if [[ ! -f "$all_apps_output_file" ]]; then
    create_output_file $all_apps_output_file
  fi

  if [[ -f "$project_output_file" ]]; then
    rm -rf $project_output_file
  fi

  create_output_file $project_output_file

  if [[ -f "$infra_input_file" ]]; then
    cat $infra_input_file >> $project_output_file
  fi

  if [[ -f "$project_input_file" ]]; then
    cat $project_input_file >> $project_output_file

    if [[ "$project" == "event-statistics" || "$project" == "ui-super-heroes" ]]; then
      cat $project_input_file >> $all_apps_output_file
    fi
  fi

  if [[ "$project" == "rest-fights" ]]; then
    # Need to process/create the downstream version
    # With the rest-villains/rest-heroes apps & their dependencies
    local downstream_project_output_file="$project/$OUTPUT_DIR/${filename}-all-downstream.yml"

    rm -rf $downstream_project_output_file
    create_output_file $downstream_project_output_file

    if [[ -d "$project/deploy/db-init" ]]; then
      cp -r $project/deploy/db-init deploy
    fi

    if [[ -f "$infra_input_file" ]]; then
      cat $infra_input_file >> $downstream_project_output_file
      cat $infra_input_file | sed 's/..\/..\/..\//..\/..\//g' >> $all_apps_output_file
    fi

    if [[ -f "$project_input_file" ]]; then
      cat $project_input_file >> $downstream_project_output_file
      cat $project_input_file >> $all_apps_output_file
    fi

    if [[ -f "rest-villains/$INPUT_DIR/$infra_input_file_name" ]]; then
      cat rest-villains/$INPUT_DIR/$infra_input_file_name >> $downstream_project_output_file
      cat rest-villains/$INPUT_DIR/$infra_input_file_name | sed 's/..\/..\/..\//..\/..\//g' >> $all_apps_output_file
    fi

    if [[ -f "rest-heroes/$INPUT_DIR/$infra_input_file_name" ]]; then
      cat rest-heroes/$INPUT_DIR/$infra_input_file_name >> $downstream_project_output_file
      cat rest-heroes/$INPUT_DIR/$infra_input_file_name | sed 's/..\/..\/..\//..\/..\//g' >> $all_apps_output_file
    fi

    if [[ -f "rest-villains/$INPUT_DIR/$input_file_name" ]]; then
      cat rest-villains/$INPUT_DIR/$input_file_name >> $downstream_project_output_file
      cat rest-villains/$INPUT_DIR/$input_file_name >> $all_apps_output_file
    fi

    if [[ -f "rest-heroes/$INPUT_DIR/$input_file_name" ]]; then
      cat rest-heroes/$INPUT_DIR/$input_file_name >> $downstream_project_output_file
      cat rest-heroes/$INPUT_DIR/$input_file_name >> $all_apps_output_file
    fi
  fi
}

create_monitoring() {
  local monitoring_name="monitoring"

  echo ""
  echo "-----------------------------------------"
  echo "Creating monitoring"

  mkdir -p $OUTPUT_DIR/$monitoring_name
  cp $monitoring_name/config/*.yml $OUTPUT_DIR/$monitoring_name
  cp $monitoring_name/docker-compose/*.yml $OUTPUT_DIR
}

rm -rf $OUTPUT_DIR/*.yml
rm -rf $OUTPUT_DIR/monitoring
rm -rf deploy/db-init

for project in "rest-villains" "rest-heroes" "rest-fights" "event-statistics" "ui-super-heroes"
do
  rm -rf $project/$OUTPUT_DIR/*.yml

  for kind in "" "native-"
  do
    # Keeping this if/else here for the future when we might want to build multiple java versions
    if [[ "$kind" == "native-" ]]; then
      javaVersions=(17)
    else
      javaVersions=(17)
  #    javaVersions=(11 17)
    fi

    for javaVersion in ${javaVersions[@]}
    do
      if [[ "$kind" == "native-" ]]; then
        versionFilename="native"
      else
        versionFilename="${kind}java${javaVersion}"
      fi

      filename=$versionFilename

      create_project_output $project $filename $versionFilename
    done
  done
done

# Now handle the monitoring
create_monitoring
