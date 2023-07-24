# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# macOS Homebrew package definition for Shaka Lab Node.

# Homebrew docs: https://docs.brew.sh/Cask-Cookbook
#                https://rubydoc.brew.sh/Cask/Cask.html

cask "shaka-lab-node" do
  name "Shaka Lab Node"
  homepage "https://github.com/shaka-project/shaka-lab"
  desc "Selenium grid nodes for the Shaka Lab"

  # Casks require a URL, but we don't actually have sources to download in
  # this way.  Instead, our tap repo includes the sources.  To satisfy
  # Homebrew, give a URL that never changes and returns no data.
  url "http://www.gstatic.com/generate_204"
  version "20230724.175606"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  # Casks can't have optional dependencies, so note to the user that Tizen can
  # enhance this package, if available.
  caveats "[Optional] To run a Tizen node, you also need Docker."

  # We need a working JDK, at least v14.
  # NOTE: We can't express a specific version in a Cask's dependencies.
  depends_on cask: "oracle-jdk"

  # We need node.js, at least v12.
  # NOTE: We can't express a specific version in a Cask's dependencies.
  depends_on formula: "node"

  # The path from the Cask definition to the full shaka-lab source.
  # We install files from there.
  source_root = "#{__dir__}/../shaka-lab-source"

  # The destination folder of most shaka-lab-node files.
  destination = "/opt/shaka-lab-node"

  # The main shaka-lab-node sources.  Declared as artifacts, no logic required.
  artifact "#{source_root}/LICENSE.TXT", target: destination
  artifact "#{source_root}/selenium-jar/selenium-server-standalone-3.141.59.jar", target: destination
  artifact "#{source_root}/shaka-lab-node/node-templates.yaml", target: destination
  artifact "#{source_root}/shaka-lab-node/package.json", target: destination
  artifact "#{source_root}/shaka-lab-node/start-nodes.js", target: destination
  artifact "#{source_root}/shaka-lab-node/macos/log-wrapper.js", target: destination
  artifact "#{source_root}/shaka-lab-node/macos/update-drivers.sh", target: destination
  artifact "#{source_root}/shaka-lab-node/macos/shaka-lab-node-service.plist", target: destination
  artifact "#{source_root}/shaka-lab-node/macos/shaka-lab-node-update.plist", target: destination
  artifact "#{source_root}/shaka-lab-node/macos/stop-services.sh", target: destination
  artifact "#{source_root}/shaka-lab-node/macos/restart-services.sh", target: destination

  # The log rotation config file.
  artifact "#{source_root}/shaka-lab-node/macos/shaka-lab-node-logrotate.conf", target: "/etc/newsyslog.d/"

  # Use preflight so that if the commands fail, the package is not considered
  # installed.
  preflight do
    # Config file goes in /opt/homebrew/etc.  Don't overwrite it!
    unless File.exist? "/etc/shaka-lab-node-config.yaml"
      FileUtils.install "#{source_root}/shaka-lab-node/shaka-lab-node-config.yaml", etc, :mode => 0644
    end

    # This service definitions needs a hard-coded path to node.js, which is
    # installed under a variable Homebrew prefix.  So replace
    # "$HOMEBREW_PREFIX" with the current prefix (in the HOMEBREW_PREFIX
    # variable).
    inreplace "#{destination}/shaka-lab-node-service.plist", "$HOMEBREW_PREFIX", HOMEBREW_PREFIX

    # Service logs go here, so make sure the folder exists:
    FileUtils.mkdir_p "/opt/shaka-lab-node/logs"

    # Now start/restart the services.
    puts "Restarting services..."
    system_command "#{opt_prefix}/restart-services.sh"
    puts "Done!"
  end
end
