#!/usr/bin/env ruby
# encoding: utf-8
# This Script only support PHP and PHP7
# This script use the buildpack manifest to generate
# Binary to be build by the system




require 'digest'
require 'fileutils'
require 'yaml'
require 'net/http'
require 'json'
require_relative '../../lib/git-client'


manifest_file = File.join(Dir.pwd, 'buildpack-repo', "manifest.yml")
output_file   = File.join(Dir.pwd, 'builds-yaml',"binary-builds", "php-builds.yml")
output_file_php7   = File.join(Dir.pwd, 'builds-yaml',"binary-builds", "php7-builds.yml")
output_file_result = File.join(Dir.pwd, 'results', "results.txt")
buildpack_manifest = YAML.load_file(manifest_file)
buildpack_version =  %x[cat buildpack-repo/VERSION]

dependencies = buildpack_manifest['dependencies']
needed_buildout_php  = {"php"=>[]}
needed_buildout_php7 = {"php7"=>[]}


#Generating Git message
git_msg = ""


dependencies.select do |dep|
if dep["name"].include?('php') and !(dep["uri"] =~ /yahoo/)
  uri = URI("http://php.net/releases/index.php?json&version=#{dep["version"]}&max=10")
  res = Net::HTTP.get_response(uri)
  my_hash = JSON.parse(res.body)
  if my_hash[dep["version"]]
     my_hash[dep["version"]]["source"].select do |file|
      if file["filename"] =~ /tar.gz/
        if dep["version"]  =~ /^7.*/
          needed_buildout_php7["php7"].push({"version"=>dep["version"],"md5"=>file["md5"]})
          git_msg += "\n\n PHP7: #{file["filename"]}"
        else
          needed_buildout_php["php"].push({"version"=>dep["version"],"md5"=>file["md5"]})
          git_msg += "\n\n PHP: #{file["filename"]}"
        end
      end
    end
  else
    p "#{dep["version"]} missing from PHP.net please update this version by yourself"
    exit 1
  end
end

end.count > 0

####################################################
# Creating files to build missing php-version      #
#                                                  #
####################################################

File.open(output_file, "w") {|f|
  f.write(needed_buildout_php.to_yaml)
}

File.open(output_file_php7, "w") {|f|
  f.write(needed_buildout_php7.to_yaml)
}


def commit_and_rsync(in_dir, out_dir, git_msg)
  Dir.chdir(in_dir) do
    GitClient.set_global_config('user.email', 'getourneau@pivotal.io')
    GitClient.set_global_config('user.name', 'Gwenn custom buildpack')
    GitClient.add_everything
    GitClient.safe_commit(git_msg)
    system("rsync -a #{in_dir}/ #{out_dir}")
  end

end

final_message =
 if !git_msg.empty?
   then "Buildpack #{buildpack_version} \n\n Detected binary to build \n\n #{git_msg}"
  else
   "Buildpack #{buildpack_version} \n\n Nothing to build [ci skip]"
  end

File.open(output_file_result,"w+") {|f|
f.write(final_message)
}

commit_and_rsync(File.join(Dir.pwd, 'builds-yaml'),File.join(Dir.pwd, 'builds-yaml-output'),final_message)
