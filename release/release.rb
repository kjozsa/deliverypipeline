#! /usr/bin/env ruby
require 'optparse'
require 'json'
require 'timeout'

application_name = "deliverypipeline"
environment1 = "deliverypipeline-dev"
environment2 = "deliverypipeline-dev2"
s3bucket = "deliverypipeline"
region = "eu-west-1"
app_version = ENV['APP_VERSION']

backup_url = "deliverypipeline-dev2.elasticbeanstalk.com"

puts "Starting zero downtime deployment for application: #{application_name}"

results = JSON.parse(%x[aws elasticbeanstalk describe-environments --application-name #{application_name} --region #{region}])

target_environment_name = results['Environments'].select { |item| item['CNAME']==backup_url }.collect {|item| item['EnvironmentName'] }[0]

puts "Deploying version to environment #{target_environment_name}"

%x[aws s3api put-object --bucket #{s3bucket} --key #{app_version}.json  --body Dockerrun.aws.json --region #{region}]
%x[aws elasticbeanstalk create-application-version --application-name deliverypipeline --version-label #{app_version} --source-bundle S3Bucket=#{s3bucket},S3Key=#{app_version}.json --region #{region}]
%x[aws elasticbeanstalk update-environment --environment-name #{target_environment_name} --version-label #{app_version} --region #{region}]

results = JSON.parse(%x[aws elasticbeanstalk describe-environments --application-name #{application_name} --environment-names #{target_environment_name} --region #{region}])['Environments'][0]

env_health = results['Health']
env_status = results['Status']
puts "Current Health: #{env_health}   Current Status: #{env_status}"
if (("Green" != env_health) || ("Ready" != env_status))
  abort "Environment must be Ready and Green. Current Health: #{env_health}  Current Status: #{env_status}"
end

puts "Deployment was successful to #{application_name} -> #{target_environment_name}!"

puts "Swap URLs for #{environment1} -> #{environment2}!"

%x[aws elasticbeanstalk swap-environment-cnames --source-environment-name #{environment1} --destination-environment-name #{environment2} --region #{region}]

puts "Deployment finished!"

