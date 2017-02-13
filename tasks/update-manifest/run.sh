#!/usr/bin/env ruby
# encoding: utf-8
#This Script only support PHP and PHP7

require 'digest'
require 'fileutils'
require 'yaml'

task_root_dir = File.expand_path(File.join(File.dirname(__FILE__), '..','..'))
require "#{task_root_dir}/buildpacks-ci/lib/git-client"




manifest_file = File.join(Dir.pwd, 'buildpack', "manifest.yml")
manifest_file_out = File.join(Dir.pwd, 'buildpack', "manifest-yahoo.yml")

buildpack_manifest = YAML.load_file(manifest_file)
buildpack_dl_repos = "https://s3-ap-northeast-1.amazonaws.com/buildpacks-binaries-bucket/concourse-binaries/"


dependencies = buildpack_manifest['dependencies']
grades = Hash.new(0)

# Get all binaries from s3 bucket
# List all binaries
listed_binaries= %x[aws s3 ls ${BP_BINARIES}/concourse-binaries/ --recursive].split(/$/).map(&:strip).map(&:split)
listed_binaries.select do |rest|
  if !rest.empty?
  /php7?-yahoo\/((php7?)-(.*)-linux-x64.(\d.*).tgz)/.match(rest[3]) {
     md5_url = "#{buildpack_dl_repos}#{$2}-yahoo/#{$1}.md5"
     md5 = %x[curl -s #{buildpack_dl_repos}#{$2}-yahoo/#{$1}.md5]
  	 grades["php-#{$3}"] = {"binary"=>$2,"version"=>$3,"timestamp"=>$4,"file"=>$1, "md5"=>md5}
  }
  end
end.count > 0

# Check all manifest php / php7 and replace by the one in S3
missing_dep = ""
dependencies.select do |dep|
  if grades.include?("#{dep["name"]}-#{dep["version"]}") and dep["name"] == "php" and !dep.empty?
     p "Replacing " + dep["uri"] + " ===> " + buildpack_dl_repos + grades["#{dep["name"]}-#{dep["version"]}"]["binary"]+ "/" +grades["#{dep["name"]}-#{dep["version"]}"]["file"]
      dep["uri"] = buildpack_dl_repos + grades["#{dep["name"]}-#{dep["version"]}"]["binary"]+ "-yahoo/" +grades["#{dep["name"]}-#{dep["version"]}"]["file"]
      dep["md5"] = grades["#{dep["name"]}-#{dep["version"]}"]["md5"]
  else
    if dep["name"] == "php" then
  	 missing_dep += "No replacement for #{dep["name"]}-#{dep["version"]}"
   else
     p "No replacement for #{dep["name"]}-#{dep["version"]}"
   end
  end
end.count > 0


if !missing_dep.empty? then
   p missing_dep.split("\n")
   exit 1
end

buildpack_manifest["dependencies"] =  dependencies
File.open(manifest_file_out, "w") do |file|
  file.write(buildpack_manifest.to_yaml)
end


def commit_and_rsync(in_dir, out_dir, git_msg, filename)
  Dir.chdir(in_dir) do
    GitClient.set_global_config('user.email', 'getourneau@pivotal.io')
    GitClient.set_global_config('user.name', 'Gwenn custom buildpack')
    GitClient.add_file(filename)
    GitClient.safe_commit(git_msg)
    system("rsync -a #{in_dir}/ #{out_dir}")
  end

end
final_message = "Adding Yahoo manifest file"
commit_and_rsync(File.join(Dir.pwd, 'buildpack'),File.join(Dir.pwd, 'buildpack-repo-out'),final_message,"manifest-yahoo.yml")
