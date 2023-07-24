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
  version "20230724.184149"
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

  # Tell homebrew that we won't "install" anything.  We do, just not using the
  # primitives for Casks, which are oriented around app bundles.
  stage_only true

  # The path from the Cask definition to the full shaka-lab source.
  # We install files from there.
  source_root = "#{__dir__}/../shaka-lab-source"

  # The destination folder of most shaka-lab-node files.  This must be
  # user-writeable, since brew does not run as root.  We will create symlinks
  # later for convenience.
  destination = "#{HOMEBREW_PREFIX}/opt/shaka-lab-node"

  # Use preflight so that if the commands fail, the package is not considered
  # installed.
  preflight do
    # Create the destination directory.
    FileUtils.mkdir_p destination

    # Main shaka-lab-node files.
    FileUtils.install "#{source_root}/LICENSE.txt", destination, :mode => 0644
    FileUtils.install "#{source_root}/selenium-jar/selenium-server-standalone-3.141.59.jar", destination, :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/node-templates.yaml", destination, :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/package.json", destination, :mode => 0644
    FileUtils.install "#{source_root}/shaka-lab-node/start-nodes.js", destination, :mode => 0644
    FileUtils.install Dir.glob("#{source_root}/shaka-lab-node/macos/*"), destination, :mode => 0644
    FileUtils.install Dir.glob("#{source_root}/shaka-lab-node/macos/*.sh"), destination, :mode => 0755

    # Config file goes in /opt/homebrew/etc.  Don't overwrite it!
    # Don't overwrite the config file if it already exists!
    unless File.exist? "#{destination}/shaka-lab-node-config.yaml"
      FileUtils.install "#{source_root}/shaka-lab-node/shaka-lab-node-config.yaml", destination, :mode => 0644
    end

    # This service definitions needs a hard-coded path to node.js, which is
    # installed under a variable Homebrew prefix.  So replace the string
    # "$HOMEBREW_PREFIX" with the current prefix (in the HOMEBREW_PREFIX
    # variable).
    system_command "/usr/bin/sed", args: [
      "-e", "s/\\$HOMEBREW_PREFIX/#{HOMEBREW_PREFIX}/",
      "-i", "#{destination}/shaka-lab-node-service.plist",
    ]

    # Service logs go here, so make sure the folder exists:
    FileUtils.mkdir_p "#{destination}/logs"

    # Symlink the log rotation config file into its required location.
    system_command "/bin/ln", args: [
      "-sf", "#{destination}/shaka-lab-node-logrotate.conf",
      "/etc/newsyslog.d/",
    ], sudo: true

    # Symlink the main config file into /etc.
    system_command "/bin/ln", args: [
      "-sf", "#{destination}/shaka-lab-node-config.yaml",
      "/etc/",
    ], sudo: true

    # Symlink the installation folder into /opt.
    system_command "/bin/ln", args: [
      "-sf", "#{destination}",
      "/opt/",
    ], sudo: true

    # Now start/restart the services.
    puts "Restarting services..."
    system_command "#{opt_prefix}/restart-services.sh"
    puts "Done!"
  end
end
