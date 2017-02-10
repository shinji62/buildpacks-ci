#!/usr/bin/env ruby
# encoding: utf-8

require 'digest'

binary_name = ENV['BINARY_NAME']
bucket_name= ENV['BUCKET_NAME']
file_path   = Dir.glob("binary-builder-artifacts/#{binary_name}*.{tar.gz,tgz,phar}").first
unless file_path
  puts 'No binaries detected for upload.'
  exit
end

`apt-get update && apt-get -y install awscli`
file_name = File.basename(file_path)

#Creating md5 file
md5sum = Digest::MD5.file(file_path).hexdigest
File.open(file_path+".md5", "w") do |file|
  file.write(md5sum)
end



if binary_name == "composer" then
  version = file_name.gsub("composer-","").gsub(".phar","")
  aws_url =  "s3://#{bucket_name}/php/binaries/trusty/composer/#{version}"
  file_name = "composer.phar"
else
  aws_url =  "s3://#{bucket_name}/concourse-binaries/#{binary_name}-yahoo"
end


if `aws s3 ls #{aws_url}/`.include? file_name
  puts "Binary #{file_name} has already been detected on s3. Skipping upload for this file."
else
  system("aws s3 cp #{file_path} #{aws_url}/#{file_name}")
  system("aws s3 cp #{file_path}.md5 #{aws_url}/#{file_name}.md5")
end
