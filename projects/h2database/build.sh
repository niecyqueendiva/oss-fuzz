#!/bin/bash -eu
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

pushd h2
MAVEN_ARGS="-Djavac.src.version=15 -Djavac.target.version=15 -DskipTests"
$MVN package $MAVEN_ARGS
CURRENT_VERSION=$($MVN org.apache.maven.plugins:maven-help-plugin:3.2.0:evaluate \
 -Dexpression=project.version -q -DforceStdout)
cp "target/h2-$CURRENT_VERSION.jar" "$OUT/h2.jar"
popd

ALL_JARS="h2.jar"

# The classpath at build-time includes the project jars in $OUT as well as the
# Jazzer API.
BUILD_CLASSPATH=$(echo $ALL_JARS | xargs printf -- "$OUT/%s:"):$JAZZER_API_PATH

# All .jar and .class files lie in the same directory as the fuzzer at runtime.
RUNTIME_CLASSPATH=$(echo $ALL_JARS | xargs printf -- "\$this_dir/%s:"):\$this_dir

# compile all java files and copy them to $OUT
javac -cp $SRC:$BUILD_CLASSPATH $SRC/*.java
cp $SRC/*.class $OUT/

# generate jazzer start script
for fuzzer in $(find $SRC -maxdepth 1 -name '*Fuzzer.java'); do
  fuzzer_basename=$(basename -s .java $fuzzer)
  #javac -cp $SRC:$BUILD_CLASSPATH $fuzzer
  #cp $SRC/$fuzzer_basename.class $OUT/
  #for member_class in $(find $SRC -maxdepth 1 -name "$fuzzer_basename\$*.class"); do
  #  cp $member_class $OUT/
  #done

  # Create an execution wrapper that executes Jazzer with the correct arguments.
  echo "#!/bin/sh
# LLVMFuzzerTestOneInput for fuzzer detection.
this_dir=\$(dirname \"\$0\")
LD_LIBRARY_PATH=\"$JVM_LD_LIBRARY_PATH\":\$this_dir \
\$this_dir/jazzer_driver --agent_path=\$this_dir/jazzer_agent_deploy.jar \
--cp=$RUNTIME_CLASSPATH \
--target_class=$fuzzer_basename \
--jvm_args=\"-Xmx2048m\" \
--disabled_hooks=\"com.code_intelligence.jazzer.sanitizers.SqlInjection\" \
\$@" > $OUT/$fuzzer_basename
  chmod u+x $OUT/$fuzzer_basename
done